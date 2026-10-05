#!/usr/bin/env python3
# ============================================================================
#  fm_ctl.py — das Rückgrat von Noctis Files.
#
#  Die Oberfläche rechnet NICHTS aus. Sie fragt hier nach und bekommt
#  fertige Angaben: was in einem Ordner liegt, wie groß es ist, welcher Art
#  es ist, was ein Rechtsklick darauf anbieten darf. Der Grund ist derselbe
#  wie bei der Wetter-App: sobald zwei Stellen dieselbe Frage selbst
#  beantworten, beantworten sie sie irgendwann verschieden.
#
#  Alles, was schiefgehen kann, geht hier schief und nicht in QML — eine
#  QML-Ausnahme reißt ein Fenster mit, ein Python-Fehler wird zu
#  {"ok": false, "err": "..."} und die Oberfläche zeigt eine Zeile an.
#
#  AUSGABE. Kurze Antworten sind ein JSON-Dokument auf stdout. Lange
#  Arbeiten (kopieren, verschieben) schreiben JSON-ZEILEN, damit der
#  Fortschritt ankommt, während er passiert:
#
#      {"t":"p","done":3,"total":12,"name":"urlaub.jpg"}
#      {"t":"done","ok":true}
#
#  Die Oberfläche liest das mit einem SplitParser mit.
# ============================================================================

import hashlib
import json
import os
import pwd
import grp
import re
import shutil
import stat as statmod
import subprocess
import sys
import time
import urllib.parse

HOME = os.path.expanduser("~")
CFG_DIR = os.path.join(HOME, ".config", "noctis")
CFG = os.path.join(CFG_DIR, "files.json")
CACHE = os.path.join(HOME, ".cache", "noctis-files")
THUMBS = os.path.join(CACHE, "thumbs")
TRASH = os.path.join(HOME, ".local", "share", "Trash")

# ----------------------------------------------------------------------------
#  Arten
#
#  Die Endung entscheidet, nicht der Inhalt. `file` auf jede Datei eines
#  Ordners aufzurufen kostet bei tausend Einträgen eine Sekunde — und für
#  ein Symbol in einer Liste ist die Endung ohnehin die ehrlichere Auskunft:
#  sie sagt, was der Benutzer gemeint hat.
# ----------------------------------------------------------------------------
KINDS = {
    "image":   "png jpg jpeg jpe jfif gif bmp webp tif tiff svg svgz ico "
               "avif heic heif jxl psd xcf raw cr2 nef arw dng orf raf pnm ppm pgm tga",
    "video":   "mp4 m4v mkv webm mov avi wmv flv mpg mpeg mts m2ts ts ogv 3gp vob",
    "audio":   "mp3 flac wav ogg oga opus m4a aac wma aiff alac ape mid midi mod xm it s3m",
    "pdf":     "pdf",
    "doc":     "doc docx odt rtf abw pages tex",
    "sheet":   "xls xlsx ods csv tsv numbers",
    "slides":  "ppt pptx odp key",
    "book":    "epub mobi azw azw3 djvu fb2 cbz cbr",
    "archive": "zip tar gz tgz bz2 tbz xz txz zst zstd 7z rar lz lzma lz4 cpio a cab arj",
    "package": "pkg deb rpm apk appimage flatpak snap whl gem jar",
    "disk":    "iso img dmg qcow2 vdi vmdk vhd squashfs",
    "font":    "ttf otf woff woff2 ttc pfb bdf pcf",
    "code":    "py js ts jsx tsx qml c h cpp hpp cc cxx rs go java kt kts swift rb php "
               "pl lua sh bash zsh fish ps1 sql r jl scala hs ml vim el nim zig dart "
               "gradle cmake make mk asm s vue svelte astro",
    "markup":  "html htm xhtml xml css scss sass less json yaml yml toml ini cfg conf "
               "md markdown rst adoc org properties env service desktop",
    "text":    "txt log nfo me readme diff patch srt sub vtt ass lrc",
    "key":     "gpg asc pem key crt cer pub p12 pfx kdbx",
    "torrent": "torrent",
}
EXT2KIND = {}
for _k, _v in KINDS.items():
    for _e in _v.split():
        EXT2KIND[_e] = _k

# Was die Oberfläche SELBST anzeigen kann (Qt lädt es direkt aus der Datei).
QT_NATIVE = set("png jpg jpeg jpe jfif gif bmp webp svg svgz ico pnm ppm pgm".split())
# Was erst ein Bild werden muss, bevor man es sehen kann.
NEEDS_THUMB = set("mp4 m4v mkv webm mov avi wmv flv mpg mpeg mts m2ts ts ogv 3gp "
                  "pdf tif tiff psd xcf heic heif avif jxl cr2 nef arw dng orf raf tga".split())


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False))
    sys.stdout.write("\n")
    sys.stdout.flush()


def line(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def err(msg):
    out({"ok": False, "err": str(msg)})
    sys.exit(0)          # Absicht: die Oberfläche liest JSON, keinen Rückgabewert.


def die_with_parent():
    """Mit dem Elternteil sterben (Linux: PR_SET_PDEATHSIG).

    Der Anlass war ein Fund: nach einem Dutzend Programmstarts liefen noch
    vier `inotifywait` im Hintergrund und sahen Ordnern zu, die niemand mehr
    offen hatte. Ein Beobachter schreibt nur, wenn sich etwas ändert —
    passiert nichts, merkt er auch nicht, dass niemand mehr zuhört, und
    wartet bis zum Abmelden.

    Der Kernel kann das lösen: er schickt dem Kind ein Signal, sobald das
    Elternteil endet. Das gilt auch dann noch, wenn das Elternteil hart
    abgeschossen wurde — und es überlebt ein exec(), weshalb der Ruf VOR dem
    Start von inotifywait steht.
    """
    try:
        import ctypes
        import signal as sig
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, sig.SIGTERM, 0, 0, 0)
        # Zwischen Abzweigen und hier kann das Elternteil schon weg sein;
        # dann ist init unser Elternteil und das Signal käme nie.
        if os.getppid() == 1:
            sys.exit(0)
    except Exception:
        pass


def run(cmd, timeout=20):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except Exception as e:
        return 1, "", str(e)


# ============================================================================
#  Einstellungen
# ============================================================================
DEFAULTS = {
    "view": "grid",            # grid | list
    "sort": "name",            # name | size | mtime | kind
    "desc": False,
    "hidden": False,
    "foldersFirst": True,
    "detail": True,
    "tile": 132,               # Kantenlänge einer Kachel im Raster
    "rowThumbs": True,
    "favorites": [],
    "lastPath": HOME,
    "confirmTrash": False,
}


def cfg_read():
    c = dict(DEFAULTS)
    try:
        with open(CFG, encoding="utf-8") as f:
            c.update(json.load(f))
    except Exception:
        pass
    return c


def cfg_write(c):
    os.makedirs(CFG_DIR, exist_ok=True)
    tmp = CFG + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(c, f, ensure_ascii=False, indent=2)
    os.replace(tmp, CFG)


# ============================================================================
#  Einträge
# ============================================================================
def kind_of(name, isdir, islink, mode):
    if isdir:
        return "folder"
    ext = name.rsplit(".", 1)[-1].lower() if "." in name[1:] else ""
    k = EXT2KIND.get(ext)
    if k:
        return k
    if mode is not None and (mode & 0o111):
        return "exe"
    return "other"


def perm_str(mode):
    if mode is None:
        return ""
    return statmod.filemode(mode)


def entry_for(path, name, st, lst, want_count):
    islink = statmod.S_ISLNK(lst.st_mode)
    broken = islink and st is None
    isdir = bool(st) and statmod.S_ISDIR(st.st_mode)
    mode = st.st_mode if st else lst.st_mode
    ext = name.rsplit(".", 1)[-1].lower() if "." in name[1:] else ""
    e = {
        "name": name,
        "path": path,
        "dir": isdir,
        "link": islink,
        "broken": broken,
        "hidden": name.startswith("."),
        "size": (st.st_size if st and not isdir else (st.st_size if st else 0)),
        "mtime": int(st.st_mtime) if st else int(lst.st_mtime),
        "ext": ext,
        "kind": "folder" if isdir else ("broken" if broken else kind_of(name, False, islink, mode)),
        "mode": perm_str(mode),
        "w": bool(st and os.access(path, os.W_OK)),
        "count": None,
        "thumb": 0,          # 0 nichts · 1 Qt kann es selbst · 2 muss gerechnet werden
    }
    if not isdir and not broken:
        if ext in QT_NATIVE:
            e["thumb"] = 1
        elif ext in NEEDS_THUMB:
            e["thumb"] = 2
    if isdir and want_count:
        try:
            with os.scandir(path) as it:
                n = 0
                for _ in it:
                    n += 1
                    if n > 9999:
                        break
                e["count"] = n
        except Exception:
            e["count"] = None
    return e


def sort_entries(entries, key, desc, folders_first):
    def kf(e):
        if key == "size":
            # Ordner haben keine sinnvolle Größe — sie sortieren nach Inhalt.
            return (e["count"] if e["dir"] and e["count"] is not None else e["size"])
        if key == "mtime":
            return e["mtime"]
        if key == "kind":
            return (e["kind"], e["name"].lower())
        return natural(e["name"])
    entries.sort(key=kf, reverse=desc)
    if folders_first:
        entries.sort(key=lambda e: 0 if e["dir"] else 1)
    return entries


_num = re.compile(r"(\d+)")


def natural(s):
    # „Bild2“ vor „Bild10“. Ohne das steht in jedem Bilderordner die 10 vor
    # der 2, und man sucht bei jedem Blick neu.
    return [int(t) if t.isdigit() else t.lower() for t in _num.split(s)]


def cmd_list(argv):
    path = os.path.realpath(os.path.expanduser(argv[0])) if argv else HOME
    c = cfg_read()
    hidden = "--hidden" in argv or c["hidden"]
    key = arg_val(argv, "--sort", c["sort"])
    desc = "--desc" in argv
    ff = "--no-folders-first" not in argv

    if not os.path.isdir(path):
        err("Kein Ordner: " + path)
    if not os.access(path, os.R_OK | os.X_OK):
        out({"ok": False, "err": "Keine Leserechte", "path": path, "entries": []})
        return

    names = []
    try:
        with os.scandir(path) as it:
            for de in it:
                names.append(de.name)
    except Exception as e:
        err(e)

    want_count = len(names) <= 400
    entries = []
    nh = 0
    for name in names:
        if name.startswith(".") and not hidden:
            nh += 1
            continue
        p = os.path.join(path, name)
        try:
            lst = os.lstat(p)
        except Exception:
            continue
        try:
            st = os.stat(p)
        except Exception:
            st = None
        entries.append(entry_for(p, name, st, lst, want_count))

    sort_entries(entries, key, desc, ff)

    nd = sum(1 for e in entries if e["dir"])
    total = sum(e["size"] for e in entries if not e["dir"])
    parent = os.path.dirname(path.rstrip("/")) or "/"
    out({
        "ok": True, "path": path, "parent": parent if path != "/" else "",
        "name": os.path.basename(path) or "/",
        "entries": entries,
        "stats": {"dirs": nd, "files": len(entries) - nd, "bytes": total, "hiddenSkipped": nh},
        "writable": os.access(path, os.W_OK),
    })


def arg_val(argv, flag, default=None):
    if flag in argv:
        i = argv.index(flag)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


# ============================================================================
#  Seitenleiste: Orte, Favoriten, Geräte, Papierkorb
# ============================================================================
XDG = [
    ("home",      "Persönlich", "", "home"),
    ("desktop",   "Schreibtisch", ["Desktop", "Schreibtisch"], "desktop"),
    ("download",  "Downloads", ["Downloads", "Download"], "download"),
    ("documents", "Dokumente", ["Dokumente", "Documents"], "doc"),
    ("pictures",  "Bilder", ["Bilder", "Pictures"], "image"),
    ("music",     "Musik", ["Musik", "Music"], "audio"),
    ("videos",    "Videos", ["Videos", "Filme"], "video"),
]


def user_dirs():
    # xdg-user-dirs ist hier nicht eingerichtet (keine user-dirs.dirs), und
    # das Home ist gemischt deutsch/englisch. Also wird nachgesehen, was
    # WIRKLICH da ist, statt einen Namen vorauszusetzen.
    conf = {}
    try:
        with open(os.path.join(CFG_DIR, "..", "user-dirs.dirs"), encoding="utf-8") as f:
            for ln in f:
                m = re.match(r'XDG_(\w+)_DIR="(.*)"', ln.strip())
                if m:
                    conf[m.group(1).lower()] = os.path.expandvars(
                        m.group(2).replace("$HOME", HOME))
    except Exception:
        pass

    res = []
    for key, label, cands, icon in XDG:
        if key == "home":
            res.append({"key": key, "label": label, "path": HOME, "icon": icon})
            continue
        p = conf.get(key if key != "download" else "download")
        if not p or not os.path.isdir(p):
            p = None
            for c in cands:
                q = os.path.join(HOME, c)
                if os.path.isdir(q):
                    p = q
                    break
        if p:
            res.append({"key": key, "label": label, "path": p, "icon": icon})
    return res


def human(n):
    if n is None:
        return ""
    u = ["B", "kB", "MB", "GB", "TB", "PB"]
    i = 0
    f = float(n)
    while f >= 1000 and i < len(u) - 1:
        f /= 1000.0
        i += 1
    if i == 0:
        return "%d B" % n
    return ("%.1f %s" % (f, u[i])).replace(".", ",")


def devices():
    rc, o, _ = run(["lsblk", "-J", "-b", "-o",
                    "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,TYPE,HOTPLUG,MODEL"])
    res = []
    if rc != 0:
        return res

    def walk(nodes, parent_model=""):
        for n in nodes:
            model = (n.get("model") or parent_model or "").strip()
            if n.get("type") in ("part", "disk", "rom", "lvm", "crypt"):
                mp = n.get("mountpoint")
                fs = n.get("fstype")
                if fs and fs not in ("swap", "LVM2_member", "crypto_LUKS"):
                    # Was hier hingehört, entscheidet der EINHÄNGEPUNKT, nicht
                    # die Bauart. Dieses System läuft selbst von einem Stick;
                    # nach „wechselbar?" gefragt, stünde die eigene
                    # Systemplatte samt /var/log in der Seitenleiste.
                    #
                    # Also: eingehängt unter /run/media, /media oder /mnt —
                    # das sind die Orte, an denen etwas Angestecktes landet.
                    # Dazu wechselbare Geräte, die noch gar nicht eingehängt
                    # sind: die will man ja gerade anklicken können.
                    rmv = bool(n.get("rm") or n.get("hotplug"))
                    guest = bool(mp) and mp.startswith(("/run/media", "/media", "/mnt"))
                    if guest or (rmv and not mp):
                        label = n.get("label") or model or n.get("name")
                        d = {
                            "label": label,
                            "dev": n.get("path"),
                            "path": mp or "",
                            "mounted": bool(mp),
                            "removable": rmv,
                            "size": n.get("size"),
                            "fs": fs,
                        }
                        if mp:
                            try:
                                st2 = os.statvfs(mp)
                                d["total"] = st2.f_blocks * st2.f_frsize
                                d["free"] = st2.f_bavail * st2.f_frsize
                            except Exception:
                                pass
                        res.append(d)
            if n.get("children"):
                walk(n["children"], model)

    try:
        walk(json.loads(o).get("blockdevices", []))
    except Exception:
        pass
    return res


def trash_items():
    info_dir = os.path.join(TRASH, "info")
    files_dir = os.path.join(TRASH, "files")
    res = []
    if not os.path.isdir(info_dir):
        return res
    for fn in os.listdir(info_dir):
        if not fn.endswith(".trashinfo"):
            continue
        base = fn[:-len(".trashinfo")]
        target = os.path.join(files_dir, base)
        orig, when = "", ""
        try:
            with open(os.path.join(info_dir, fn), encoding="utf-8") as f:
                for ln in f:
                    if ln.startswith("Path="):
                        orig = urllib.parse.unquote(ln[5:].strip())
                    elif ln.startswith("DeletionDate="):
                        when = ln[len("DeletionDate="):].strip()
        except Exception:
            continue
        try:
            lst = os.lstat(target)
        except Exception:
            continue
        try:
            st = os.stat(target)
        except Exception:
            st = None
        e = entry_for(target, os.path.basename(orig) or base, st, lst, False)
        e["orig"] = orig
        e["trashName"] = base
        e["deleted"] = when
        try:
            e["deletedAt"] = int(time.mktime(time.strptime(when, "%Y-%m-%dT%H:%M:%S")))
        except Exception:
            e["deletedAt"] = e["mtime"]
        res.append(e)
    return res


def cmd_places(argv):
    c = cfg_read()
    favs = []
    for p in c.get("favorites", []):
        if os.path.isdir(p):
            favs.append({"label": os.path.basename(p.rstrip("/")) or p, "path": p})
    t = trash_items()
    out({
        "ok": True,
        "home": HOME,
        "dirs": user_dirs(),
        "favorites": favs,
        "devices": devices(),
        "trash": {"count": len(t)},
        "root": {"label": "Dateisystem", "path": "/"},
    })


def cmd_trash_list(argv):
    items = trash_items()
    items.sort(key=lambda e: e.get("deletedAt", 0), reverse=True)
    out({"ok": True, "path": "trash://", "name": "Papierkorb", "parent": "",
         "entries": items,
         "stats": {"dirs": sum(1 for e in items if e["dir"]),
                   "files": sum(1 for e in items if not e["dir"]),
                   "bytes": sum(e["size"] for e in items if not e["dir"]),
                   "hiddenSkipped": 0},
         "writable": True})


def cmd_trash_restore(argv):
    n = 0
    for name in argv:
        info = os.path.join(TRASH, "info", name + ".trashinfo")
        src = os.path.join(TRASH, "files", name)
        orig = ""
        try:
            with open(info, encoding="utf-8") as f:
                for ln in f:
                    if ln.startswith("Path="):
                        orig = urllib.parse.unquote(ln[5:].strip())
        except Exception:
            continue
        if not orig:
            continue
        if not os.path.isabs(orig):
            orig = os.path.join(HOME, orig)
        os.makedirs(os.path.dirname(orig), exist_ok=True)
        dst = unique(orig)
        try:
            shutil.move(src, dst)
            os.remove(info)
            n += 1
        except Exception as e:
            err(e)
    out({"ok": True, "n": n})


def cmd_trash_empty(argv):
    fd, idir = os.path.join(TRASH, "files"), os.path.join(TRASH, "info")
    n = 0
    for d, keep in ((fd, False), (idir, False)):
        if not os.path.isdir(d):
            continue
        for fn in os.listdir(d):
            p = os.path.join(d, fn)
            try:
                if os.path.isdir(p) and not os.path.islink(p):
                    shutil.rmtree(p)
                else:
                    os.remove(p)
                n += 1
            except Exception:
                pass
    out({"ok": True, "n": n})


# ============================================================================
#  Suchen
# ============================================================================
def cmd_search(argv):
    root = os.path.expanduser(argv[0]) if argv else HOME
    q = argv[1] if len(argv) > 1 else ""
    c = cfg_read()
    hidden = "--hidden" in argv or c["hidden"]
    limit = int(arg_val(argv, "--limit", "1200"))
    if len(q.strip()) < 1:
        out({"ok": True, "path": root, "entries": [], "query": q,
             "stats": {"dirs": 0, "files": 0, "bytes": 0, "hiddenSkipped": 0}})
        return
    ql = q.lower()
    t0 = time.time()
    res = []
    cut = False
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        if not hidden:
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        # Nach acht Sekunden ist eine Suche keine Suche mehr, sondern ein
        # hängendes Fenster. Lieber abbrechen und das sagen.
        if time.time() - t0 > 8.0 or len(res) >= limit:
            cut = True
            break
        for name in dirnames + filenames:
            if not hidden and name.startswith("."):
                continue
            if ql not in name.lower():
                continue
            p = os.path.join(dirpath, name)
            try:
                lst = os.lstat(p)
                try:
                    st = os.stat(p)
                except Exception:
                    st = None
                res.append(entry_for(p, name, st, lst, False))
            except Exception:
                continue
            if len(res) >= limit:
                cut = True
                break
    sort_entries(res, c["sort"], False, True)
    out({"ok": True, "path": root, "query": q, "entries": res, "cut": cut,
         "name": "Suche",
         "stats": {"dirs": sum(1 for e in res if e["dir"]),
                   "files": sum(1 for e in res if not e["dir"]),
                   "bytes": sum(e["size"] for e in res if not e["dir"]),
                   "hiddenSkipped": 0},
         "writable": False})


# ============================================================================
#  Auskunft über eine einzelne Datei
# ============================================================================
def cmd_info(argv):
    path = os.path.expanduser(argv[0])
    deep = "--deep" in argv
    try:
        lst = os.lstat(path)
    except Exception as e:
        err(e)
    try:
        st = os.stat(path)
    except Exception:
        st = None
    name = os.path.basename(path.rstrip("/")) or path
    e = entry_for(path, name, st, lst, True)
    e["ok"] = True
    e["dirName"] = os.path.dirname(path)
    try:
        e["owner"] = pwd.getpwuid((st or lst).st_uid).pw_name
    except Exception:
        e["owner"] = str((st or lst).st_uid)
    try:
        e["group"] = grp.getgrgid((st or lst).st_gid).gr_name
    except Exception:
        e["group"] = str((st or lst).st_gid)
    s = st or lst
    e["ctime"] = int(s.st_ctime)
    e["atime"] = int(s.st_atime)
    if lst and statmod.S_ISLNK(lst.st_mode):
        try:
            e["target"] = os.readlink(path)
        except Exception:
            pass

    rc, o, _ = run(["file", "-b", "--mime-type", path], timeout=6)
    e["mime"] = o.strip() if rc == 0 else ""
    rc, o, _ = run(["file", "-b", path], timeout=6)
    e["desc"] = o.strip()[:160] if rc == 0 else ""

    if e["kind"] == "image":
        rc, o, _ = run(["identify", "-format", "%wx%h|%[colorspace]|%m", path + "[0]"], timeout=8)
        if rc == 0 and "|" in o:
            a = o.split("|")
            e["dim"] = a[0]
            e["colorspace"] = a[1] if len(a) > 1 else ""
            e["format"] = a[2] if len(a) > 2 else ""
    elif e["kind"] in ("video", "audio"):
        rc, o, _ = run(["ffprobe", "-v", "quiet", "-print_format", "json",
                        "-show_format", "-show_streams", path], timeout=10)
        if rc == 0:
            try:
                d = json.loads(o)
                fmt = d.get("format", {})
                e["duration"] = float(fmt.get("duration", 0) or 0)
                e["bitrate"] = int(fmt.get("bit_rate", 0) or 0)
                tags = fmt.get("tags", {}) or {}
                for k in ("title", "artist", "album", "date"):
                    for kk in (k, k.capitalize(), k.upper()):
                        if kk in tags:
                            e[k] = tags[kk]
                            break
                for s2 in d.get("streams", []):
                    if s2.get("codec_type") == "video" and "dim" not in e:
                        e["dim"] = "%sx%s" % (s2.get("width"), s2.get("height"))
                        e["vcodec"] = s2.get("codec_name", "")
                    if s2.get("codec_type") == "audio" and "acodec" not in e:
                        e["acodec"] = s2.get("codec_name", "")
                        e["channels"] = s2.get("channels")
            except Exception:
                pass
    elif e["kind"] in ("text", "code", "markup") and st and st.st_size < 400000:
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                txt = f.read(4000)
            e["head"] = txt
            e["lines"] = sum(1 for _ in open(path, encoding="utf-8", errors="replace"))
        except Exception:
            pass
    elif e["kind"] == "archive":
        e["members"] = archive_peek(path)

    if e["dir"] and deep:
        rc, o, _ = run(["du", "-sb", path], timeout=25)
        if rc == 0:
            try:
                e["deepSize"] = int(o.split()[0])
            except Exception:
                pass
    out(e)


def archive_peek(path):
    try:
        import zipfile, tarfile
        if zipfile.is_zipfile(path):
            with zipfile.ZipFile(path) as z:
                nm = z.namelist()
                return {"n": len(nm), "names": nm[:40]}
        if tarfile.is_tarfile(path):
            with tarfile.open(path) as t:
                nm = t.getnames()
                return {"n": len(nm), "names": nm[:40]}
    except Exception:
        pass
    return None


def cmd_disk(argv):
    path = os.path.expanduser(argv[0]) if argv else HOME
    while path and not os.path.exists(path):
        path = os.path.dirname(path)
    try:
        s = os.statvfs(path or "/")
        total = s.f_blocks * s.f_frsize
        free = s.f_bavail * s.f_frsize
        out({"ok": True, "total": total, "free": free, "used": total - free,
             "humanTotal": human(total), "humanFree": human(free)})
    except Exception as e:
        err(e)


# ============================================================================
#  Öffnen
# ============================================================================
def desktop_entry(dfile):
    name, icon, gname = "", "", ""
    try:
        with open(dfile, encoding="utf-8", errors="replace") as f:
            insec = False
            for ln in f:
                ln = ln.strip()
                if ln.startswith("["):
                    insec = ln == "[Desktop Entry]"
                    continue
                if not insec:
                    continue
                if ln.startswith("Name=") and not name:
                    name = ln[5:]
                elif ln.startswith("Name[de]="):
                    name = ln[len("Name[de]="):]
                elif ln.startswith("Icon=") and not icon:
                    icon = ln[5:]
                elif ln.startswith("GenericName=") and not gname:
                    gname = ln[len("GenericName="):]
    except Exception:
        pass
    return name, icon, gname


def find_desktop(did):
    dirs = [os.path.join(HOME, ".local/share/applications"),
            "/usr/local/share/applications", "/usr/share/applications",
            "/var/lib/flatpak/exports/share/applications",
            os.path.join(HOME, ".local/share/flatpak/exports/share/applications")]
    for d in dirs:
        p = os.path.join(d, did)
        if os.path.isfile(p):
            return p
    return ""


def cmd_apps(argv):
    path = os.path.expanduser(argv[0])
    rc, o, _ = run(["file", "-b", "--mime-type", path], timeout=6)
    mime = o.strip() if rc == 0 else "application/octet-stream"
    rc, o, _ = run(["gio", "mime", mime], timeout=8)
    default, rest = "", []
    for ln in o.splitlines():
        ln = ln.strip()
        if ln.endswith(".desktop"):
            did = ln.split()[-1]
            if "Default application" in "".join(o.splitlines()[:1]) and not default:
                pass
            rest.append(did)
    # gio gibt „Default application for type X: a.desktop“ und danach eine
    # Liste. Die erste Nennung ist die Vorgabe.
    if rest:
        default = rest[0]
    # Doppelte aussortieren — und zwar nach dem NAMEN, nicht nach der Kennung.
    # Chrome liegt auf diesem System zweimal (`google-chrome.desktop` und
    # `com.google.Chrome.desktop`), und zweimal „Google Chrome" in einer Liste
    # ist keine Auswahl, sondern eine Frage, die man nicht beantworten kann.
    seen, seenName, apps = set(), set(), []
    for did in rest:
        if did in seen:
            continue
        seen.add(did)
        f = find_desktop(did)
        if not f:
            continue
        name, icon, gname = desktop_entry(f)
        label = name or did
        key = label.strip().lower()
        if key in seenName:
            continue
        seenName.add(key)
        apps.append({"id": did, "name": label, "icon": icon,
                     "generic": gname, "default": did == default})
    out({"ok": True, "mime": mime, "apps": apps})


def cmd_open(argv):
    path = os.path.expanduser(argv[0])
    did = argv[1] if len(argv) > 1 else ""
    if did:
        f = find_desktop(did)
        if f:
            subprocess.Popen(["gio", "launch", f, path],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            out({"ok": True})
            return
    subprocess.Popen(["xdg-open", path], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    out({"ok": True})


def cmd_term(argv):
    d = os.path.expanduser(argv[0]) if argv else HOME
    for t in (["kitty", "--directory", d], ["alacritty", "--working-directory", d],
              ["foot", "-D", d], ["wezterm", "start", "--cwd", d],
              ["ghostty", "--working-directory=" + d], ["xterm"]):
        if shutil.which(t[0]):
            subprocess.Popen(t, cwd=d, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            out({"ok": True, "term": t[0]})
            return
    err("Kein Terminal gefunden")


# ============================================================================
#  Vorschaubilder
#
#  Langlebiger Prozess: die Oberfläche schickt Pfade auf stdin und bekommt
#  Zeilen zurück. Ein eigener Prozess je Kachel wäre bei einem Ordner voller
#  Filme ein Prozessgewitter — und das Fenster stünde, während es passiert.
# ============================================================================
def thumb_path(src, size):
    try:
        st = os.stat(src)
    except Exception:
        return None
    key = "%s|%d|%d|%d" % (os.path.realpath(src), st.st_mtime_ns, st.st_size, size)
    h = hashlib.sha1(key.encode("utf-8")).hexdigest()
    return os.path.join(THUMBS, h[:2], h + ".png")


def make_thumb(src, size=320):
    dst = thumb_path(src, size)
    if not dst:
        return None
    if os.path.exists(dst):
        return dst
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    ext = src.rsplit(".", 1)[-1].lower() if "." in src else ""
    tmp = dst + ".part.png"
    ok = False
    if ext in ("mp4", "m4v", "mkv", "webm", "mov", "avi", "wmv", "flv", "mpg",
               "mpeg", "mts", "m2ts", "ts", "ogv", "3gp"):
        # 12 % hinein: Bild 0 ist bei vielen Filmen schwarz.
        dur = 0.0
        rc, o, _ = run(["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                        "-of", "csv=p=0", src], timeout=10)
        try:
            dur = float(o.strip())
        except Exception:
            dur = 0.0
        ss = max(0.0, min(dur * 0.12, 120.0)) if dur > 2 else 0.0
        rc, _, _ = run(["ffmpeg", "-v", "quiet", "-y", "-ss", "%.2f" % ss, "-i", src,
                        "-frames:v", "1", "-vf",
                        "scale=%d:%d:force_original_aspect_ratio=decrease" % (size, size),
                        tmp], timeout=25)
        ok = rc == 0 and os.path.exists(tmp)
    elif ext == "pdf" and shutil.which("pdftoppm"):
        # Poppler statt ImageMagick: ImageMagick reicht PDF an Ghostscript
        # weiter, und ohne Ghostscript gibt es dann gar keine Vorschau. Ist
        # eines von beiden da, sieht man die erste Seite; ist keines da,
        # bleibt es beim Zeichen für „PDF“ — eine fehlende Vorschau ist kein
        # Fehler, nur eine fehlende Vorschau.
        base = tmp[:-4]
        rc, _, _ = run(["pdftoppm", "-png", "-f", "1", "-l", "1",
                        "-scale-to", str(size), "-singlefile", src, base], timeout=25)
        ok = rc == 0 and os.path.exists(tmp)
    else:
        rc, _, _ = run(["convert", "-density", "120", src + "[0]",
                        "-auto-orient", "-thumbnail", "%dx%d" % (size, size),
                        "-background", "none", "-alpha", "remove", "-alpha", "off",
                        tmp], timeout=25)
        ok = rc == 0 and os.path.exists(tmp)
    if ok:
        try:
            os.replace(tmp, dst)
            return dst
        except Exception:
            pass
    try:
        os.remove(tmp)
    except Exception:
        pass
    return None


def cmd_watch(argv):
    # Beobachtet EINEN Ordner und schreibt je Änderung eine Zeile. Das
    # eigentliche Zusehen macht inotifywait; dieser Prozess ist nur dazu da,
    # ihn an das Fenster zu binden (siehe die_with_parent).
    path = os.path.expanduser(argv[0]) if argv else HOME
    die_with_parent()
    try:
        os.execvp("inotifywait",
                  ["inotifywait", "-q", "-m", "-e",
                   "create,delete,move,modify,attrib", "--format", "%e", path])
    except Exception as e:
        err(e)


def cmd_thumbd(argv):
    die_with_parent()
    os.makedirs(THUMBS, exist_ok=True)
    for raw in sys.stdin:
        raw = raw.rstrip("\n")
        if not raw:
            continue
        parts = raw.split("\t")
        src = parts[0]
        size = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 320
        try:
            r = make_thumb(src, size)
        except Exception:
            r = None
        sys.stdout.write("%s\t%s\n" % (src, r or "!"))
        sys.stdout.flush()


def cmd_thumb(argv):
    os.makedirs(THUMBS, exist_ok=True)
    r = make_thumb(os.path.expanduser(argv[0]),
                   int(argv[1]) if len(argv) > 1 else 320)
    out({"ok": bool(r), "thumb": r or ""})


def cmd_thumbclean(argv):
    # Älter als 30 Tage und nie wieder angefasst: weg.
    cut = time.time() - 30 * 86400
    n = 0
    for d, _, fs in os.walk(THUMBS):
        for f in fs:
            p = os.path.join(d, f)
            try:
                if os.path.getatime(p) < cut:
                    os.remove(p)
                    n += 1
            except Exception:
                pass
    out({"ok": True, "n": n})


# ============================================================================
#  Arbeiten an Dateien
# ============================================================================
def unique(dst):
    # „Bericht.pdf“ → „Bericht (2).pdf“. Nicht „Bericht.pdf.1“: die Endung
    # muss die Endung bleiben, sonst weiß das System nicht mehr, was es ist.
    if not os.path.lexists(dst):
        return dst
    d, b = os.path.split(dst)
    stem, dot, ext = b.partition(".")
    if b.startswith(".") and dot:
        stem2, dot2, ext2 = b[1:].partition(".")
        stem, ext, dot = "." + stem2, ext2, dot2
    i = 2
    while True:
        cand = os.path.join(d, "%s (%d)%s%s" % (stem, i, "." if ext else "", ext))
        if not os.path.lexists(cand):
            return cand
        i += 1


def count_tree(paths):
    n, b = 0, 0
    for p in paths:
        if os.path.isdir(p) and not os.path.islink(p):
            for dirpath, dirnames, filenames in os.walk(p):
                n += len(filenames) + len(dirnames)
                for f in filenames:
                    try:
                        b += os.lstat(os.path.join(dirpath, f)).st_size
                    except Exception:
                        pass
        else:
            n += 1
            try:
                b += os.lstat(p).st_size
            except Exception:
                pass
    return max(1, n), b


def cmd_op(argv):
    if not argv:
        err("op: Verb fehlt")
    verb = argv[0]
    conflict = arg_val(argv, "--conflict", "ask")
    # Schalter UND ihren Wert aussortieren. Wird nur auf „beginnt mit --"
    # geprüft, rutscht das Wort hinter dem Schalter als Quelldatei durch —
    # und dann kopiert dieses Skript eine Datei namens „keep“.
    VALUE_FLAGS = ("--conflict",)
    rest, skip = [], False
    for a in argv[1:]:
        if skip:
            skip = False
            continue
        if a in VALUE_FLAGS:
            skip = True
            continue
        if a.startswith("--"):
            continue
        rest.append(a)

    if verb == "mkdir":
        d, name = rest[0], rest[1]
        p = os.path.join(d, name)
        if os.path.lexists(p):
            line({"t": "done", "ok": False, "err": "Gibt es schon"})
            return
        try:
            os.makedirs(p)
            line({"t": "done", "ok": True, "path": p})
        except Exception as e:
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "touch":
        d, name = rest[0], rest[1]
        p = os.path.join(d, name)
        if os.path.lexists(p):
            line({"t": "done", "ok": False, "err": "Gibt es schon"})
            return
        try:
            open(p, "a").close()
            line({"t": "done", "ok": True, "path": p})
        except Exception as e:
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "rename":
        src, new = rest[0], rest[1]
        if "/" in new:
            line({"t": "done", "ok": False, "err": "Ein Name enthält keinen Schrägstrich"})
            return
        dst = os.path.join(os.path.dirname(src), new)
        if os.path.lexists(dst) and os.path.realpath(dst) != os.path.realpath(src):
            line({"t": "done", "ok": False, "err": "„%s“ gibt es hier schon" % new})
            return
        try:
            os.rename(src, dst)
            line({"t": "done", "ok": True, "path": dst})
        except Exception as e:
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "trash":
        bad = []
        for p in rest:
            rc, _, e2 = run(["gio", "trash", p], timeout=30)
            if rc != 0:
                bad.append(os.path.basename(p) + ": " + e2.strip())
        line({"t": "done", "ok": not bad, "err": "; ".join(bad)[:300], "n": len(rest) - len(bad)})
        return

    if verb == "delete":
        bad = []
        total, _ = count_tree(rest)
        done = 0
        for p in rest:
            try:
                if os.path.isdir(p) and not os.path.islink(p):
                    shutil.rmtree(p)
                else:
                    os.remove(p)
            except Exception as e:
                bad.append(os.path.basename(p) + ": " + str(e))
            done += 1
            line({"t": "p", "done": done, "total": len(rest), "name": os.path.basename(p)})
        line({"t": "done", "ok": not bad, "err": "; ".join(bad)[:300]})
        return

    if verb in ("copy", "move", "link"):
        dstdir = rest[0]
        srcs = rest[1:]
        if not os.path.isdir(dstdir):
            line({"t": "done", "ok": False, "err": "Ziel ist kein Ordner"})
            return
        # Erst prüfen, dann arbeiten: ein halb erledigtes Kopieren mit einer
        # Rückfrage mittendrin ist das Unangenehmste, was ein Dateimanager
        # tun kann.
        clash = []
        for s in srcs:
            if os.path.lexists(os.path.join(dstdir, os.path.basename(s.rstrip("/")))):
                clash.append(os.path.basename(s.rstrip("/")))
        if clash and conflict == "ask":
            line({"t": "conflict", "names": clash, "dst": dstdir})
            return
        # In sich selbst verschieben geht nicht — und ein Dateimanager, der
        # es versucht, frisst den Ordner.
        for s in srcs:
            rs = os.path.realpath(s)
            rd = os.path.realpath(dstdir)
            if os.path.isdir(rs) and (rd == rs or rd.startswith(rs + os.sep)):
                line({"t": "done", "ok": False,
                      "err": "„%s“ lässt sich nicht in sich selbst legen"
                             % os.path.basename(rs)})
                return

        total, _ = count_tree(srcs) if verb != "link" else (len(srcs), 0)
        done = [0]
        bad = []

        def tick(name):
            done[0] += 1
            if done[0] % 8 == 0 or done[0] == total:
                line({"t": "p", "done": min(done[0], total), "total": total, "name": name})

        def copy2(a, b, follow_symlinks=True):
            shutil.copy2(a, b, follow_symlinks=follow_symlinks)
            tick(os.path.basename(a))

        for s in srcs:
            base = os.path.basename(s.rstrip("/"))
            dst = os.path.join(dstdir, base)
            if os.path.lexists(dst):
                if conflict == "skip":
                    continue
                if conflict == "keep":
                    dst = unique(dst)
                elif conflict == "replace":
                    try:
                        if os.path.isdir(dst) and not os.path.islink(dst):
                            shutil.rmtree(dst)
                        else:
                            os.remove(dst)
                    except Exception as e:
                        bad.append(base + ": " + str(e))
                        continue
            try:
                if verb == "link":
                    os.symlink(os.path.realpath(s), dst)
                    tick(base)
                elif verb == "copy":
                    if os.path.isdir(s) and not os.path.islink(s):
                        shutil.copytree(s, dst, symlinks=True, copy_function=copy2)
                    else:
                        copy2(s, dst, follow_symlinks=False)
                else:
                    shutil.move(s, dst)
                    tick(base)
            except Exception as e:
                bad.append(base + ": " + str(e))
        line({"t": "done", "ok": not bad, "err": "; ".join(bad)[:300], "dst": dstdir})
        return

    if verb == "compress":
        # Ziel ist immer ein .zip neben den Quellen: ein Format, das jedes
        # andere System auch aufbekommt.
        dstdir = rest[0]
        srcs = rest[1:]
        import zipfile
        base = os.path.basename(srcs[0].rstrip("/")) if len(srcs) == 1 else os.path.basename(dstdir.rstrip("/"))
        dst = unique(os.path.join(dstdir, (base.rsplit(".", 1)[0] if "." in base else base) + ".zip"))
        total, _ = count_tree(srcs)
        done = 0
        try:
            with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
                for s in srcs:
                    if os.path.isdir(s) and not os.path.islink(s):
                        root = os.path.dirname(s.rstrip("/"))
                        for dp, dn, fn in os.walk(s):
                            for f in fn:
                                p = os.path.join(dp, f)
                                z.write(p, os.path.relpath(p, root))
                                done += 1
                                if done % 8 == 0:
                                    line({"t": "p", "done": done, "total": total, "name": f})
                    else:
                        z.write(s, os.path.basename(s))
                        done += 1
            line({"t": "done", "ok": True, "path": dst})
        except Exception as e:
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "extract":
        src = rest[0]
        dstdir = rest[1] if len(rest) > 1 else os.path.dirname(src)
        base = os.path.basename(src)
        for suf in (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst"):
            if base.endswith(suf):
                base = base[:-len(suf)]
                break
        else:
            base = base.rsplit(".", 1)[0]
        target = unique(os.path.join(dstdir, base))
        try:
            os.makedirs(target, exist_ok=True)
            if shutil.which("bsdtar"):
                rc, _, e2 = run(["bsdtar", "-x", "-f", src, "-C", target], timeout=900)
                if rc != 0:
                    raise RuntimeError(e2.strip() or "Entpacken fehlgeschlagen")
            else:
                shutil.unpack_archive(src, target)
            line({"t": "done", "ok": True, "path": target})
        except Exception as e:
            # Den angelegten Ordner wieder wegräumen. Sonst bleibt nach einem
            # kaputten Archiv ein leerer Ordner mit dessen Namen liegen, und
            # beim nächsten Versuch heißt er dann „archiv (2)“.
            try:
                if os.path.isdir(target) and not os.listdir(target):
                    os.rmdir(target)
            except Exception:
                pass
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "chmod-x":
        p = rest[0]
        try:
            st = os.stat(p)
            if st.st_mode & 0o111:
                os.chmod(p, st.st_mode & ~0o111)
            else:
                os.chmod(p, st.st_mode | 0o111)
            line({"t": "done", "ok": True})
        except Exception as e:
            line({"t": "done", "ok": False, "err": str(e)})
        return

    if verb == "mount" or verb == "unmount":
        dev = rest[0]
        sub = "mount" if verb == "mount" else "unmount"
        rc, o, e2 = run(["udisksctl", sub, "-b", dev, "--no-user-interaction"], timeout=40)
        mp = ""
        m = re.search(r"at ([^\s.]+)", o)
        if m:
            mp = m.group(1)
        line({"t": "done", "ok": rc == 0, "err": (e2 or o).strip()[:200], "path": mp})
        return

    line({"t": "done", "ok": False, "err": "Unbekannt: " + verb})


# ============================================================================
#  Zwischenablage — Pfade als text/uri-list, wie es der Rest des Systems tut
# ============================================================================
def cmd_clip(argv):
    mode = argv[0]                     # copy | cut
    paths = argv[1:]
    uris = "\n".join("file://" + urllib.parse.quote(os.path.abspath(p)) for p in paths)
    # Die Nautilus-Form: erste Zeile das Verb, danach die Adressen. Fast
    # jeder Dateimanager unter GTK liest das, also kann man von hier aus
    # auch dorthin einfügen.
    payload = ("copy\n" if mode == "copy" else "cut\n") + uris
    try:
        subprocess.run(["wl-copy", "-t", "x-special/gnome-copied-files"],
                       input=payload, text=True, timeout=6)
        subprocess.run(["wl-copy", "-t", "text/uri-list"], input=uris + "\n",
                       text=True, timeout=6)
    except Exception as e:
        err(e)
    out({"ok": True, "n": len(paths)})


def cmd_clip_text(argv):
    try:
        subprocess.run(["wl-copy"], input="\n".join(argv), text=True, timeout=6)
    except Exception as e:
        err(e)
    out({"ok": True})


def cmd_clip_paste(argv):
    rc, o, _ = run(["wl-paste", "-t", "x-special/gnome-copied-files"], timeout=6)
    if rc != 0 or not o.strip():
        out({"ok": True, "mode": "", "paths": []})
        return
    lines = o.strip().splitlines()
    mode = lines[0].strip() if lines else ""
    paths = []
    for u in lines[1:]:
        u = u.strip()
        if u.startswith("file://"):
            paths.append(urllib.parse.unquote(u[7:]))
    out({"ok": True, "mode": mode, "paths": paths})


# ============================================================================
#  Einstellungen von außen
# ============================================================================
def cmd_state(argv):
    c = cfg_read()
    c["ok"] = True
    out(c)


def cmd_set(argv):
    c = cfg_read()
    i = 0
    while i + 1 < len(argv):
        k, v = argv[i], argv[i + 1]
        if v in ("true", "false"):
            c[k] = v == "true"
        elif re.fullmatch(r"-?\d+", v):
            c[k] = int(v)
        elif v.startswith("[") or v.startswith("{"):
            try:
                c[k] = json.loads(v)
            except Exception:
                c[k] = v
        else:
            c[k] = v
        i += 2
    cfg_write(c)
    out({"ok": True})


def cmd_fav(argv):
    c = cfg_read()
    verb, p = argv[0], os.path.abspath(os.path.expanduser(argv[1]))
    favs = [f for f in c.get("favorites", [])]
    if verb == "add":
        if p not in favs:
            favs.append(p)
    elif verb == "remove":
        favs = [f for f in favs if f != p]
    elif verb == "move":
        i = int(argv[2])
        if p in favs:
            favs.remove(p)
            favs.insert(max(0, min(len(favs), i)), p)
    c["favorites"] = favs
    cfg_write(c)
    out({"ok": True, "favorites": favs})


CMDS = {
    "list": cmd_list, "places": cmd_places, "search": cmd_search, "info": cmd_info,
    "disk": cmd_disk, "apps": cmd_apps, "open": cmd_open, "term": cmd_term,
    "thumb": cmd_thumb, "thumbd": cmd_thumbd, "thumbclean": cmd_thumbclean,
    "op": cmd_op, "state": cmd_state, "set": cmd_set, "fav": cmd_fav,
    "watch": cmd_watch,
    "trash-list": cmd_trash_list, "trash-restore": cmd_trash_restore,
    "trash-empty": cmd_trash_empty,
    "clip": cmd_clip, "clip-text": cmd_clip_text, "clip-paste": cmd_clip_paste,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in CMDS:
        err("Unbekannter Befehl. Bekannt: " + ", ".join(sorted(CMDS)))
    try:
        CMDS[sys.argv[1]](sys.argv[2:])
    except BrokenPipeError:
        pass
    except Exception as e:
        err(e)
