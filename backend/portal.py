#!/usr/bin/env python3
# ============================================================================
#  portal.py — Noctis Files als Dateiauswahl des ganzen Systems.
#
#  WAS HIER GELÖST WIRD. „Datei hochladen" in Chrome und „Ordner öffnen" in
#  VS Code sind KEIN Dateimanager, sondern ein Dialog. Welcher Dialog das ist,
#  entscheidet nicht die Anwendung, sondern das XDG-Portal: ein Vermittler auf
#  dem Sitzungsbus, der die Frage „such mir eine Datei" an einen Hintergrund-
#  dienst weiterreicht. Bisher antwortete darauf xdg-desktop-portal-gtk und
#  zeigte den GTK-Dialog. Dieses Programm meldet sich als eigene Antwortstelle
#  an und zeigt statt dessen Noctis Files.
#
#  Der Weg einer Frage:
#
#      Chrome  →  org.freedesktop.portal.FileChooser       (der Vermittler)
#              →  org.freedesktop.impl.portal.FileChooser  (hier)
#              →  noctis-files  (eigener Lauf, Auswahl-Modus)  (das Fenster)
#              →  Antwortdatei  →  zurück über denselben Weg
#
#  WARUM EIN EIGENER PROZESS UND NICHT DAS LAUFENDE FENSTER. Ein Dialog ist
#  eine Frage mit Anfang und Ende: er geht auf, man antwortet, er verschwindet.
#  Das offene Hauptfenster dafür zu benutzen hieße, dem Benutzer sein Fenster
#  wegzunehmen und es hinterher in einem anderen Ordner zurückzugeben. Also
#  bekommt jede Frage ihr eigenes Fenster, und die Antwort läuft über eine
#  Datei — schlichter als jede Zwischenprozesskommunikation und vor allem
#  nachvollziehbar: die Datei kann man sich ansehen, wenn etwas nicht stimmt.
#
#  WARUM GDBUS UND NICHT dbus-python. Auf diesem Rechner ist `dbus` nur der
#  Platzhalter aus PyQt, `dbus.service` fehlt. GDBus steckt in PyGObject, das
#  ohnehin überall liegt — und es kann genau das, was hier gebraucht wird:
#  eine Antwort SPÄTER geben. Ein Dateidialog steht so lange offen, wie der
#  Benutzer sucht; wer den Bus-Aufruf so lange blockiert, blockiert den
#  ganzen Dienst.
#
#  ANTWORT-NUMMERN (vom Portal festgelegt):
#      0  ausgewählt      1  abgebrochen      2  etwas ging schief
# ============================================================================

import json
import os
import sys
import tempfile
import time

import gi
gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio

HERE = os.path.dirname(os.path.abspath(__file__))
# Das Fenster ist das eigenständige Programm. Gesucht wird: ausdrücklich
# gesetzt (die systemd-Einheit setzt es), neben diesem Skript installiert
# (../../bin), dann im Suchpfad.
def fenster_programm():
    p = os.environ.get("NOCTIS_FILES_BIN", "")
    if p and os.access(p, os.X_OK):
        return p
    nah = os.path.normpath(os.path.join(HERE, "..", "..", "bin", "noctis-files"))
    if os.access(nah, os.X_OK):
        return nah
    return "noctis-files"
BUS_NAME = "org.freedesktop.impl.portal.desktop.noctis"
OBJ_PATH = "/org/freedesktop/portal/desktop"
IFACE = "org.freedesktop.impl.portal.FileChooser"
REQ_IFACE = "org.freedesktop.impl.portal.Request"

LOG = os.path.join(os.path.expanduser("~"), ".cache", "noctis-files", "portal.log")

CHOOSER_XML = """
<node>
  <interface name='org.freedesktop.impl.portal.FileChooser'>
    <property name='version' type='u' access='read'/>
    <method name='OpenFile'>
      <arg type='o' name='handle' direction='in'/>
      <arg type='s' name='app_id' direction='in'/>
      <arg type='s' name='parent_window' direction='in'/>
      <arg type='s' name='title' direction='in'/>
      <arg type='a{sv}' name='options' direction='in'/>
      <arg type='u' name='response' direction='out'/>
      <arg type='a{sv}' name='results' direction='out'/>
    </method>
    <method name='SaveFile'>
      <arg type='o' name='handle' direction='in'/>
      <arg type='s' name='app_id' direction='in'/>
      <arg type='s' name='parent_window' direction='in'/>
      <arg type='s' name='title' direction='in'/>
      <arg type='a{sv}' name='options' direction='in'/>
      <arg type='u' name='response' direction='out'/>
      <arg type='a{sv}' name='results' direction='out'/>
    </method>
    <method name='SaveFiles'>
      <arg type='o' name='handle' direction='in'/>
      <arg type='s' name='app_id' direction='in'/>
      <arg type='s' name='parent_window' direction='in'/>
      <arg type='s' name='title' direction='in'/>
      <arg type='a{sv}' name='options' direction='in'/>
      <arg type='u' name='response' direction='out'/>
      <arg type='a{sv}' name='results' direction='out'/>
    </method>
  </interface>
</node>
"""

REQUEST_XML = """
<node>
  <interface name='org.freedesktop.impl.portal.Request'>
    <method name='Close'/>
  </interface>
</node>
"""


def log(*a):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%H:%M:%S ") + " ".join(str(x) for x in a) + "\n")
    except Exception:
        pass


def bytepfad(v):
    """Aus einem „ay" einen Pfad machen.

    Das Portal reicht Ordner und Dateinamen als Bytefolge mit abschließender
    Null durch, nicht als Zeichenkette — Dateinamen sind unter Linux Bytes und
    müssen kein gültiges UTF-8 sein.
    """
    if v is None:
        return ""
    if isinstance(v, (bytes, bytearray)):
        return bytes(v).rstrip(b"\x00").decode("utf-8", "replace")
    if isinstance(v, (list, tuple)):
        try:
            return bytes(bytearray(int(b) for b in v)).rstrip(b"\x00").decode("utf-8", "replace")
        except Exception:
            return ""
    return str(v)


def filters_in(raw):
    """a(sa(us)) → eine Liste, mit der QML etwas anfangen kann.

    Jeder Filter hat einen Namen und mehrere Regeln; eine Regel ist entweder
    ein Muster (Typ 0, „*.png") oder ein Medientyp (Typ 1, „image/png").
    """
    out = []
    for f in raw or []:
        try:
            name, rules = f[0], f[1]
        except Exception:
            continue
        globs, mimes = [], []
        for r in rules or []:
            try:
                art, wert = int(r[0]), str(r[1])
            except Exception:
                continue
            (globs if art == 0 else mimes).append(wert)
        out.append({"name": str(name), "globs": globs, "mimes": mimes})
    return out


class Portal:

    def __init__(self):
        self.con = None
        self.offen = {}          # handle → Frage
        self.req_reg = {}        # handle → Registrierungs-Kennung

    # ------------------------------------------------------------------
    #  Anmelden
    # ------------------------------------------------------------------
    def start(self):
        Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME,
                         Gio.BusNameOwnerFlags.NONE,
                         self.on_bus, self.on_name, self.on_lost)

    def on_bus(self, con, name):
        self.con = con
        info = Gio.DBusNodeInfo.new_for_xml(CHOOSER_XML).interfaces[0]
        con.register_object(OBJ_PATH, info, self.on_call, self.on_get, None)
        log("Objekt angemeldet unter", OBJ_PATH)

    def on_name(self, con, name):
        log("bereit als", name)

    def on_lost(self, con, name):
        log("Name verloren:", name, "— es läuft wohl schon einer")
        sys.exit(0)

    def on_get(self, con, sender, path, iface, prop):
        if prop == "version":
            return GLib.Variant("u", 3)
        return None

    # ------------------------------------------------------------------
    #  Eine Frage entgegennehmen
    # ------------------------------------------------------------------
    def on_call(self, con, sender, path, iface, method, params, invocation):
        if method not in ("OpenFile", "SaveFile", "SaveFiles"):
            invocation.return_error_literal(Gio.dbus_error_quark(),
                                            Gio.DBusError.UNKNOWN_METHOD, method)
            return
        handle, app_id, parent, title, options = params.unpack()
        mode = {"OpenFile": "open", "SaveFile": "save", "SaveFiles": "savefiles"}[method]
        self.frage(mode, handle, app_id, parent, title, options, invocation)

    def frage(self, mode, handle, app_id, parent, title, options, invocation):
        o = options or {}
        req = {
            "mode": mode,
            "title": title or "",
            "appId": app_id or "",
            "parent": parent or "",
            "acceptLabel": o.get("accept_label", "") or "",
            "multiple": bool(o.get("multiple", False)),
            "directory": bool(o.get("directory", False)),
            "currentName": o.get("current_name", "") or "",
            "currentFolder": bytepfad(o.get("current_folder")),
            "currentFile": bytepfad(o.get("current_file")),
            "filters": filters_in(o.get("filters")),
            "modal": bool(o.get("modal", True)),
        }
        # Speichern-unter kennt den Ordner oft nur über die Datei.
        if not req["currentFolder"] and req["currentFile"]:
            req["currentFolder"] = os.path.dirname(req["currentFile"])
        # Einen Ordner, den es nicht gibt, gar nicht erst weitergeben: das
        # Fenster stünde sonst in einem leeren Nichts und man müsste sich
        # erst heraussuchen, wo man ist.
        if req["currentFolder"] and not os.path.isdir(req["currentFolder"]):
            req["currentFolder"] = ""
        if not req["currentName"] and req["currentFile"]:
            req["currentName"] = os.path.basename(req["currentFile"])

        fd, reqfile = tempfile.mkstemp(prefix="noctis-pick-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(req, f, ensure_ascii=False)
        resfile = reqfile[:-5] + ".antwort.json"

        env = dict(os.environ)
        env["NOCTIS_PICK_REQUEST"] = reqfile
        env["NOCTIS_PICK_RESULT"] = resfile
        envp = ["%s=%s" % (k, v) for k, v in env.items()]

        log("Frage:", mode, "von", req["appId"] or "?", "|", req["title"],
            "| Ordner:", req["currentFolder"] or "-")

        try:
            pid, _, _, _ = GLib.spawn_async(
                argv=[fenster_programm()],
                envp=envp,
                flags=GLib.SpawnFlags.DO_NOT_REAP_CHILD | GLib.SpawnFlags.SEARCH_PATH)
        except Exception as e:
            log("Fenster ließ sich nicht starten:", e)
            invocation.return_value(GLib.Variant("(ua{sv})", (2, {})))
            return

        self.offen[handle] = {"pid": pid, "req": reqfile, "res": resfile,
                              "inv": invocation, "fertig": False}
        self.registriere_request(handle)
        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, pid,
                             lambda p, st, *_: self.fertig(handle, p))

    # Der Vermittler legt für jede Frage einen Pfad an und ruft dort `Close()`,
    # wenn sie hinfällig wird — etwa weil das fragende Programm zugemacht hat.
    # Ohne diese Stelle bliebe ein Fenster stehen, dessen Antwort niemand mehr
    # hören will.
    def registriere_request(self, handle):
        try:
            info = Gio.DBusNodeInfo.new_for_xml(REQUEST_XML).interfaces[0]
            rid = self.con.register_object(
                handle, info,
                lambda con, sender, path, iface, method, params, inv:
                    self.on_close(handle, inv),
                None, None)
            self.req_reg[handle] = rid
        except Exception as e:
            log("Abbruchstelle ließ sich nicht anlegen:", e)

    def on_close(self, handle, invocation):
        f = self.offen.get(handle)
        log("Abbruch von außen:", handle)
        if f and not f["fertig"]:
            try:
                os.kill(f["pid"], 15)
            except Exception:
                pass
        invocation.return_value(None)

    # ------------------------------------------------------------------
    #  Antworten
    # ------------------------------------------------------------------
    def fertig(self, handle, pid):
        GLib.spawn_close_pid(pid)
        f = self.offen.get(handle)
        if not f or f["fertig"]:
            return
        f["fertig"] = True
        self.offen.pop(handle, None)
        rid = self.req_reg.pop(handle, None)
        if rid is not None:
            try:
                self.con.unregister_object(rid)
            except Exception:
                pass

        antwort, ergebnis, d = 1, {}, {}
        try:
            with open(f["res"], encoding="utf-8") as fh:
                d = json.load(fh)
            if d.get("ok") and d.get("uris"):
                antwort = 0
                ergebnis["uris"] = GLib.Variant("as", list(d["uris"]))
                if d.get("filterName"):
                    # Zurückgemeldet wird der Filter in derselben Form, in der
                    # er hereinkam — sonst hält die Anwendung die Antwort für
                    # kaputt und fragt noch einmal.
                    regeln = [(0, g) for g in d.get("filterGlobs", [])]
                    ergebnis["current_filter"] = GLib.Variant(
                        "(sa(us))", (d["filterName"], regeln))
        except FileNotFoundError:
            pass
        except Exception as e:
            log("keine brauchbare Antwort:", e)

        for p in (f["req"], f["res"]):
            try:
                os.remove(p)
            except Exception:
                pass

        log("Antwort:", antwort, d.get("uris", []) if antwort == 0 else "")
        try:
            f["inv"].return_value(GLib.Variant("(ua{sv})", (antwort, ergebnis)))
        except Exception as e:
            log("Antwort kam nicht durch:", e)


def main():
    p = Portal()
    p.start()
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
