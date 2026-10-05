// ============================================================================
//  Noctis Files — der Dateimanager.
//
//  Ein eigenes Programm im Sinn von §91: eigener Prozess, eigenes Fenster,
//  eigener Eintrag im Starter. Es benutzt dieselbe Designsprache wie alles
//  andere hier (noctis/) und dieselbe Bauart wie Noctis Weather — Wurzeldatei
//  oben, Bausteine im Unterordner, ein Python-Skript als Rückgrat.
//
//  EIGENSTÄNDIGE FASSUNG. Diese Datei ist NoctisFiles.qml aus dem
//  Quickshell-Ordner, umgezogen in ein eigenes Programm (src/main.cpp).
//  Der Wirt stellt dieselben Bausteine bereit, die vorher Quickshell
//  geliefert hat — Process, FileView, StdioCollector, SplitParser —, unter
//  demselben Namen und mit derselben Bedienung. Geändert hat sich nur, was
//  an Quickshell selbst hing: das Fenster, die Umgebung, der Ruf von außen
//  und die Zwischenablage. Jede dieser Stellen ist unten markiert.
//
//  ---------------------------------------------------------------------
//  WER WAS WEISS
//  ---------------------------------------------------------------------
//  Diese Datei hält den ganzen Zustand: wo man ist, was ausgewählt ist, was
//  in der Zwischenablage liegt, welcher Reiter offen ist. Die Bausteine
//  (filesapp/Fm*.qml) halten NICHTS — sie zeigen an und rufen hier Funktionen
//  auf. Das ist der Grund, warum ein Wechsel von Raster auf Liste die Auswahl
//  nicht verliert und warum die Seitenleiste weiß, in welchem Ordner man
//  steht, ohne dass ihr das jemand sagt.
//
//  Gerechnet wird im Skript (filesapp/fm_ctl.py). Was eine Datei ist, wie
//  groß, wem sie gehört, ob sie sich kopieren lässt — das beantwortet dort
//  jemand, der Ausnahmen abfangen kann. Ein Fehler im Skript wird zu einer
//  Zeile in der Fußleiste; derselbe Fehler in QML nähme das Fenster mit.
// ============================================================================

import QtQuick
import QtQuick.Window
import NoctisHost
import "noctis"
import "filesapp"
import "filesapp/FmKind.js" as K

Window {
    id: app

    // [eigenständig] FloatingWindow → Window. Quickshell kannte implicitWidth
    // und minimumSize; ein Qt-Fenster heißt das width und minimumWidth.
    width: 1320
    height: 860
    minimumWidth: 880
    minimumHeight: 560
    // Sichtbar macht es erst der Wirt, NACH dem Laden. Mit `visible: true`
    // ging das Fenster noch während des Aufbaus auf, und die Effekte
    // (MultiEffect in Ansicht und Schnellansicht) griffen auf Elemente zu,
    // die es noch nicht ganz gab — Absturz in QQuickShaderEffectSource.
    // Im Auswahl-Modus trägt das Fenster den Titel, den das fragende Programm
    // mitgibt („Datei zum Hochladen wählen"), und dahinter den eigenen Namen.
    // Zwei Gründe: der Starter des Hauptfensters sucht nach GENAU „Noctis
    // Files" und darf einen Dialog nicht dafür halten, und eine Fensterregel
    // in Hyprland braucht etwas Wiedererkennbares, um ihn schweben zu lassen.
    title: pickMode ? (pickTitle + " — Noctis Files") : "Noctis Files"

    // §96: Durchsichtig. Das Fenster malt seinen Grund selbst — mit der
    // Deckkraft aus den Einstellungen (Noctis.glassAlpha), und Hyprland
    // zeichnet weich, was dahinter liegt.
    color: "transparent"

    // [eigenständig] Das Rückgrat liegt jetzt dort, wo das Paket es hinlegt
    // (/usr/lib/noctis-files) — der Wirt weiß, wo, und sagt es hier.
    readonly property string home: Host.home
    readonly property string ctl: Host.ctl

    Component.onCompleted: {
        Noctis.screenWidth = 1920      // feste Skalierung: das Fenster ist frei größenverstellbar
        stateProc.running = true
        thumbProc.running = true
        if (pickMode) pickFocus.start()
    }

    // Beim Speichern steht der Name schon da und ist meistens der falsche —
    // also gehört die Tastatur dorthin, ohne dass man erst hinklickt.
    Timer {
        id: pickFocus
        interval: 260
        onTriggered: if (app.pickSaving) pickBar.focusName()
    }

    // §92: Fenster zu heißt Programm aus. Ohne das bleibt ein Programm ohne
    // Fenster am Leben, der Starter findet seine PID und versucht, ein
    // Fenster zu holen, das es nicht mehr gibt.
    onVisibleChanged: if (!visible) Qt.quit()

    // ==================================================================
    //  Zustand
    // ==================================================================
    property var  cfg: null
    property string path: ""
    // Was das Skript geliefert hat — und was davon zu sehen ist. Getrennt,
    // weil der Auswahl-Modus filtert (nur Ordner, nur *.png) und alles
    // andere im Programm mit dem SICHTBAREN Stand rechnet: der Zeiger der
    // Tastatur, das Tippen zum Springen, das Blättern in der Vorschau.
    property var  rawEntries: []
    readonly property var entries: {
        if (!pickMode || !pickReq) return rawEntries
        var out = []
        for (var i = 0; i < rawEntries.length; i++)
            if (pickPass(rawEntries[i])) out.push(rawEntries[i])
        return out
    }

    // Leer ist nicht gleich leer: im Dialog kann ein Ordner voll sein und
    // trotzdem nichts zeigen, weil der Filter alles wegnimmt. Das muss anders
    // dastehen als ein wirklich leerer Ordner — sonst sucht man den Fehler
    // beim Ordner statt beim Filter.
    readonly property bool pickFiltered: pickMode && rawEntries.length > 0
                                         && entries.length === 0

    // Die Fußzeile zählt, was ZU SEHEN ist. Im Dialog filtert die Liste
    // („nur Bilder"), und dann stimmte die Zeile darunter nicht mehr mit dem
    // überein, was man vor sich hat: drei Kacheln, „23 Dateien" darunter.
    readonly property var viewStats: {
        if (!pickMode || !pickReq) return stats
        var d = 0, f = 0, b = 0
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].dir) d++
            else { f++; b += entries[i].size }
        }
        return { dirs: d, files: f, bytes: b, hiddenSkipped: stats.hiddenSkipped }
    }

    // Ein Muster wie „*.png" auf einen Namen anwenden.
    function globPass(g, name) {
        if (g === "*" || g === "*.*") return true
        var rx = "^" + g.replace(/[.+^${}()|[\]\\]/g, "\\$&")
                        .replace(/\*/g, ".*").replace(/\?/g, ".") + "$"
        return new RegExp(rx, "i").test(name)
    }

    function pickPass(e) {
        if (e.dir) return true                 // Ordner bleiben: man muss ja hin
        if (pickDirs) return false
        if (pickFilter < 0 || !pickReq.filters || pickReq.filters.length === 0)
            return true
        var f = pickReq.filters[pickFilter]
        for (var i = 0; i < (f.globs || []).length; i++)
            if (globPass(f.globs[i], e.name)) return true
        // Medientypen kennt die Liste nicht — dafür die Art, und die reicht
        // für die Fälle, die vorkommen („image/*" beim Hochladen eines Bildes).
        for (var j = 0; j < (f.mimes || []).length; j++) {
            var m = f.mimes[j]
            if (m === "*/*") return true
            if (m.indexOf("image/") === 0 && e.kind === "image") return true
            if (m.indexOf("video/") === 0 && e.kind === "video") return true
            if (m.indexOf("audio/") === 0 && e.kind === "audio") return true
            if (m.indexOf("text/") === 0
                && (e.kind === "text" || e.kind === "code" || e.kind === "markup"))
                return true
            if (m === "application/pdf" && e.kind === "pdf") return true
        }
        return false
    }
    property var  stats: ({ dirs: 0, files: 0, bytes: 0, hiddenSkipped: 0 })
    property bool loading: true
    property bool writable: true
    property string message: ""
    property bool messageBad: false

    property var  places: null
    property var  disk: null

    // ==================================================================
    //  Auswahl-Modus (das Portal, siehe filesapp/portal.py)
    //
    //  Dasselbe Fenster, eine andere Aufgabe: nicht „Dateien verwalten",
    //  sondern „eine Datei benennen und zurückgeben". Deshalb ist es kein
    //  eigenes Programm — alles, was das Suchen leicht macht (Seitenleiste,
    //  Vorschaubilder, Suche, Sortierung), soll im Dialog genauso da sein.
    //  Was sich ändert, ist der Rand: unten kommt eine Leiste dazu, ein
    //  Doppelklick wählt aus statt zu öffnen, und das Fenster beantwortet
    //  eine Frage, statt stehen zu bleiben.
    // ==================================================================
    readonly property string pickRequestPath: Host.env("NOCTIS_PICK_REQUEST") || ""
    readonly property string pickResultPath: Host.env("NOCTIS_PICK_RESULT") || ""
    readonly property bool pickMode: pickRequestPath !== ""
    property var pickReq: null
    property string pickName: ""          // der Name im Speichern-Feld
    property int pickFilter: -1           // welcher Filter gerade gilt
    property bool pickAnswered: false

    readonly property string pickTitle: pickReq && pickReq.title !== ""
                                        ? pickReq.title
                                        : (pickSaving ? "Speichern unter" : "Datei wählen")
    readonly property bool pickSaving: pickReq ? pickReq.mode === "save" : false
    readonly property bool pickDirs: pickReq ? (pickReq.directory === true
                                                || pickReq.mode === "savefiles") : false
    readonly property bool pickMulti: pickReq ? pickReq.multiple === true : false
    readonly property string pickAccept: {
        if (!pickReq) return "Öffnen"
        if (pickReq.acceptLabel && pickReq.acceptLabel !== "")
            return pickReq.acceptLabel.replace(/_/g, "")
        return pickSaving ? "Speichern" : (pickDirs ? "Auswählen" : "Öffnen")
    }

    FileView {
        id: pickRequest
        path: app.pickRequestPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                app.pickReq = JSON.parse(pickRequest.text())
                app.pickName = app.pickReq.currentName || ""
                if (app.pickReq.filters && app.pickReq.filters.length > 0)
                    app.pickFilter = 0
            } catch (e) {
                app.pickReq = null
            }
        }
    }

    FileView {
        id: pickAnswer
        path: app.pickResultPath
        blockWrites: true        // erst schreiben, dann darf das Fenster zu
        atomicWrites: true
        printErrors: false
    }

    // Abgeben und Schluss. Antwortet das Fenster gar nicht (abgestürzt,
    // weggeklickt), wertet der Dienst das als Abbruch — deshalb ist die
    // Antwortdatei der einzige Weg, ein „ja" zu sagen.
    function pickFinish(ok, uris) {
        if (pickAnswered) return
        pickAnswered = true
        var d = { ok: ok === true, uris: uris || [] }
        if (pickFilter >= 0 && pickReq && pickReq.filters
                && pickFilter < pickReq.filters.length) {
            d.filterName = pickReq.filters[pickFilter].name
            d.filterGlobs = pickReq.filters[pickFilter].globs
        }
        try { pickAnswer.setText(JSON.stringify(d)) } catch (e) {}
        Qt.quit()
    }

    function pickCancel() { pickFinish(false, []) }

    // Was beim Druck auf den großen Knopf herauskommt.
    function pickConfirm() {
        if (!pickMode) return
        if (pickSaving) {
            var n = pickName.trim()
            if (n === "" || n.indexOf("/") >= 0) return
            var ziel = path + "/" + n
            // Gibt es die Datei schon, wird gefragt. Ein Dialog, der
            // wortlos überschreibt, ist der teuerste Klick im System.
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].name === n) {
                    dlg.mode = "confirm"
                    dlg.icon = K.UI.alert
                    dlg.title = "„" + n + "“ ersetzen?"
                    dlg.subtitle = "In diesem Ordner gibt es die Datei schon. "
                                 + "Der bisherige Inhalt geht dabei verloren."
                    dlg.okText = "Ersetzen"
                    dlg.danger = true
                    dlg.action = "pickOverwrite"
                    dlg.show()
                    return
                }
            }
            pickFinish(true, [K.toUri(ziel)])
            return
        }
        var out = []
        if (pickDirs) {
            for (var j = 0; j < selEntries.length; j++)
                if (selEntries[j].dir) out.push(K.toUri(selEntries[j].path))
            if (out.length === 0) out = [K.toUri(path)]   // der offene Ordner
        } else {
            for (var k = 0; k < selEntries.length; k++)
                if (!selEntries[k].dir) out.push(K.toUri(selEntries[k].path))
            if (out.length === 0) return
            if (!pickMulti) out = [out[0]]
        }
        pickFinish(true, out)
    }

    // Ob der große Knopf überhaupt etwas tun kann.
    readonly property bool pickReady: {
        if (!pickMode) return false
        if (pickSaving) return pickName.trim() !== "" && pickName.indexOf("/") < 0
        if (pickDirs) return true
        for (var i = 0; i < selEntries.length; i++) if (!selEntries[i].dir) return true
        return false
    }

    // Ansicht
    property bool gridMode: true
    property real tileSize: Noctis.u(120)
    property string sortKey: "name"
    property bool sortDesc: false
    property bool hiddenOn: false
    property bool detail: true
    // Ob sie WIRKLICH zu sehen ist, entscheidet die Breite mit. Bei einem
    // schmalen Fenster nähme die Spalte die halbe Fläche und die Dateien
    // stünden zu zweit nebeneinander — dann ist die Auskunft mehr wert als
    // das, was sie kostet, aber nur auf dem Papier. Die EINSTELLUNG bleibt
    // dabei unangetastet: wer das Fenster wieder breit zieht, bekommt seine
    // Spalte zurück, ohne sie neu einzuschalten.
    readonly property bool detailShown: detail && width >= Noctis.u(1040)

    // Auswahl. Der Schlüssel ist der PFAD, nicht die Nummer in der Liste:
    // nach dem Neuladen eines Ordners stimmen Nummern nicht mehr, Pfade schon.
    property var  selList: []
    property var  selMap: ({})
    property int  cursor: -1
    property bool keyboardActive: false
    property int  anchorIndex: -1

    // Zwischenablage
    property var  clipList: []
    property string clipMode: ""     // copy | cut

    // Suche
    property string query: ""

    // Ziehen
    property bool dragActive: false

    readonly property bool searching: query.trim() !== ""
    readonly property bool inTrash: path === "trash://"

    // ==================================================================
    //  Reiter
    //
    //  Jeder Reiter hat seinen eigenen Verlauf. Beim Wechsel wird der
    //  aktuelle Stand HINEIN gespeichert und der neue HERAUS geholt — der
    //  offene Ordner selbst bleibt eine einzige Eigenschaft (`path`).
    //  Andernfalls hinge jede Bindung der Oberfläche an tabs[i].path, und
    //  QML meldet Änderungen an verschachtelten Objekten nicht.
    // ==================================================================
    property var tabs: [{ path: "", hist: [], hi: -1 }]
    property int tabIndex: 0
    property var hist: []
    property int hi: -1

    readonly property bool canBack: hi > 0
    readonly property bool canForward: hi >= 0 && hi < hist.length - 1
    readonly property bool canUp: !inTrash && path !== "/" && path !== ""

    function tabLabel(p) {
        if (p === "trash://") return "Papierkorb"
        if (p === home) return "Persönlich"
        if (p === "/") return "Dateisystem"
        var b = p.substring(p.lastIndexOf("/") + 1)
        return b === "" ? p : b
    }

    function saveTab() {
        var t = tabs.slice()
        t[tabIndex] = { path: path, hist: hist.slice(), hi: hi }
        tabs = t
    }

    function selectTab(i) {
        if (i === tabIndex || i < 0 || i >= tabs.length) return
        saveTab()
        tabIndex = i
        var t = tabs[i]
        hist = t.hist.slice()
        hi = t.hi
        clearSel()
        setPath(t.path, false)
    }

    function openInNewTab(p) {
        saveTab()
        var t = tabs.slice()
        t.push({ path: p, hist: [p], hi: 0 })
        tabs = t
        tabIndex = t.length - 1
        hist = [p]
        hi = 0
        clearSel()
        setPath(p, false)
    }

    function closeTab(i) {
        if (tabs.length <= 1) { Qt.quit(); return }
        var t = tabs.slice()
        t.splice(i, 1)
        var ni = tabIndex
        if (i < tabIndex) ni = tabIndex - 1
        else if (i === tabIndex) ni = Math.min(i, t.length - 1)
        tabs = t
        if (i === tabIndex) {
            tabIndex = ni
            hist = t[ni].hist.slice()
            hi = t[ni].hi
            clearSel()
            setPath(t[ni].path, false)
        } else {
            tabIndex = ni
        }
    }

    // ==================================================================
    //  Navigation
    // ==================================================================
    function setPath(p, push) {
        if (p === "") return
        if (push !== false) {
            // Alles, was hinter der aktuellen Stelle im Verlauf liegt, ist
            // mit dem neuen Schritt ungültig geworden — genau wie im Browser.
            var h = hist.slice(0, hi + 1)
            if (h.length === 0 || h[h.length - 1] !== p) h.push(p)
            if (h.length > 120) h.shift()
            hist = h
            hi = h.length - 1
        }
        path = p
        query = ""
        top.clearSearch()
        // Wer woanders hingeht, hat die Suche hinter sich — also gehört die
        // Tastatur wieder der Fläche und nicht dem Suchfeld. Das deckt den
        // Weg über die Seitenleiste und die Pfadkette ab; für den Klick auf
        // eine Datei tut es `pick`.
        takeFocus()
        cursor = -1
        keyboardActive = false
        clearSel()
        reload()
        // Der Dialog merkt sich NICHTS. Wer eine Datei hochlädt, hat damit
        // nicht entschieden, wo sein Dateimanager beim nächsten Mal aufgehen
        // soll — das wäre ein Nebeneffekt, den niemand bestellt hat.
        if (p !== "trash://" && !pickMode) {
            saveConfig("lastPath", p)
            diskProc.p = p
            diskProc.running = true
        }
        saveTab()
    }

    function go(p) { if (p !== path) setPath(p, true) }

    function goTyped(t) {
        var p = t.trim()
        if (p === "") return
        if (p === "~") p = home
        else if (p.indexOf("~/") === 0) p = home + p.substring(1)
        if (p.length > 1 && p.charAt(p.length - 1) === "/") p = p.substring(0, p.length - 1)
        if (p.charAt(0) !== "/" && p !== "trash://") p = path + "/" + p
        go(p)
        takeFocus()
    }

    function back() { if (canBack) { hi--; path = hist[hi]; afterHistoryStep() } }
    function forward() { if (canForward) { hi++; path = hist[hi]; afterHistoryStep() } }
    function afterHistoryStep() {
        query = ""
        top.clearSearch()
        clearSel()
        cursor = -1
        reload()
        diskProc.p = path
        diskProc.running = true
        saveTab()
    }

    function up() {
        if (!canUp) return
        var parent = path.substring(0, path.lastIndexOf("/"))
        if (parent === "") parent = "/"
        var from = path
        go(parent)
        // Nach oben zu gehen heißt, den Ordner zu verlassen, in dem man war
        // — und der ist die interessanteste Zeile der neuen Liste. Also
        // wird er ausgewählt, statt dass man ihn sucht.
        pendingSelect = from
    }
    property string pendingSelect: ""

    function activate(e) {
        if (!e) return
        if (e.dir) { go(e.path); return }
        // Im Dialog heißt „öffnen" nicht starten, sondern abgeben. Ein
        // Doppelklick auf die Datei ist die schnellste Art zu antworten, und
        // genau die erwartet jeder, der aus einem anderen Programm kommt.
        if (pickMode) {
            if (pickSaving) { pickName = e.name; return }
            if (!pickDirs) { pickFinish(true, [K.toUri(e.path)]); return }
            return
        }
        if (inTrash) {
            note("Aus dem Papierkorb lässt sich nichts öffnen — erst zurücklegen.", true)
            return
        }
        openProc.args = [e.path]
        openProc.running = true
    }

    function prettyDir(p) {
        var d = p.substring(0, p.lastIndexOf("/"))
        if (d === home) return "Persönlich"
        if (d.indexOf(home + "/") === 0) return "~" + d.substring(home.length)
        return d === "" ? "/" : d
    }

    function takeFocus() { stage.forceActiveFocus() }

    function note(t, bad) {
        message = t
        messageBad = bad === true
        noteTimer.restart()
    }
    Timer { id: noteTimer; interval: 5200; onTriggered: app.message = "" }

    // ==================================================================
    //  Auswahl
    // ==================================================================
    function isSel(p) { return selMap[p] === true }
    function isCut(p) { return clipMode === "cut" && clipMap[p] === true }
    property var clipMap: ({})

    function setSel(list) {
        var m = {}
        for (var i = 0; i < list.length; i++) m[list[i]] = true
        selMap = m
        selList = list
    }
    function clearSel() { selMap = ({}); selList = [] }

    // Klick ins Leere: Auswahl weg UND Tastatur zurück in die Fläche.
    function clearSelFromView() { takeFocus(); clearSel() }

    function indexOfPath(p) {
        for (var i = 0; i < entries.length; i++) if (entries[i].path === p) return i
        return -1
    }

    function pick(e, mods) {
        if (!e) return
        // DIE TASTATUR ZURÜCKHOLEN.
        //
        //  Wer ins Suchfeld getippt hat und danach eine Datei anklickt, hat
        //  die Datei im Sinn — die Tastatur liegt aber noch im Feld. Strg+Z,
        //  Strg+C und die Pfeiltasten gingen dann an den Text und nicht an
        //  die Auswahl, und zwar lautlos: das Feld verschluckt sie, und in
        //  der Liste passiert nichts. Gefunden beim Durchprobieren, nachdem
        //  ein Rückgängig scheinbar grundlos nicht wirkte.
        //
        //  Hier ist die richtige Stelle, weil sie jeden Weg abdeckt, auf dem
        //  man eine Datei anfasst: Kachel, Zeile, Rahmen aufziehen.
        takeFocus()
        keyboardActive = false
        var i = indexOfPath(e.path)
        if (mods & Qt.ControlModifier) {
            var l = selList.slice()
            var at = l.indexOf(e.path)
            if (at >= 0) l.splice(at, 1)
            else l.push(e.path)
            setSel(l)
            anchorIndex = i
        } else if ((mods & Qt.ShiftModifier) && anchorIndex >= 0) {
            var a = Math.min(anchorIndex, i), b = Math.max(anchorIndex, i)
            var r = []
            for (var j = a; j <= b; j++) r.push(entries[j].path)
            setSel(r)
        } else {
            setSel([e.path])
            anchorIndex = i
        }
        cursor = i
        if (pickMode && pickSaving && !e.dir) pickName = e.name
    }

    function selectAll() {
        var l = []
        for (var i = 0; i < entries.length; i++) l.push(entries[i].path)
        setSel(l)
    }

    readonly property var selEntries: {
        var r = []
        for (var i = 0; i < entries.length; i++)
            if (selMap[entries[i].path] === true) r.push(entries[i])
        return r
    }
    readonly property int selDirs: {
        var n = 0
        for (var i = 0; i < selEntries.length; i++) if (selEntries[i].dir) n++
        return n
    }
    readonly property int selFiles: selEntries.length - selDirs
    readonly property real selBytes: {
        var b = 0
        for (var i = 0; i < selEntries.length; i++) if (!selEntries[i].dir) b += selEntries[i].size
        return b
    }
    readonly property var detailEntry: selEntries.length === 1 ? selEntries[0] : null

    onDetailEntryChanged: {
        infoData = null
        if (detailEntry) infoTimer.restart()
        else infoTimer.stop()
    }
    property var infoData: null
    Timer {
        id: infoTimer
        interval: 160        // beim Durchpfeilen nicht für jede Zeile ein Prozess
        onTriggered: {
            if (!app.detailEntry) return
            infoProc.p = app.detailEntry.path
            infoProc.running = true
        }
    }

    // ==================================================================
    //  Laden
    // ==================================================================
    function reload() {
        if (path === "") return
        loading = true
        listProc.wanted = true
        if (!listProc.running) listProc.running = true
    }

    function refresh() {
        reload()
        placesProc.running = true
        diskProc.p = path
        diskProc.running = true
    }

    Process {
        id: stateProc
        command: [Host.python, app.ctl, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { app.cfg = JSON.parse(this.text) } catch (e) { app.cfg = null }
                if (app.cfg) {
                    app.gridMode = app.cfg.view !== "list"
                    app.sortKey = app.cfg.sort || "name"
                    app.sortDesc = app.cfg.desc === true
                    app.hiddenOn = app.cfg.hidden === true
                    app.detail = app.cfg.detail !== false
                    app.tileSize = Noctis.u(app.cfg.tile || 120)
                }
                placesProc.running = true
                var start = (app.cfg && app.cfg.lastPath) ? app.cfg.lastPath : app.home
                // [eigenständig] Ein Ordner auf der Befehlszeile geht vor. Der
                // Starter der Quickshell-Fassung schrieb ihn dafür vorher als
                // „letzten Ort" in die Einstellungen; der Wirt reicht ihn
                // direkt durch.
                if (Host.startPath !== "") start = Host.startPath
                if (app.pickMode && app.pickReq && app.pickReq.currentFolder
                        && app.pickReq.currentFolder !== "")
                    start = app.pickReq.currentFolder
                app.tabs = [{ path: start, hist: [start], hi: 0 }]
                app.hist = [start]
                app.hi = 0
                app.setPath(start, false)
                diskProc.p = start
                diskProc.running = true
            }
        }
    }

    Process {
        id: listProc
        property bool wanted: false
        command: {
            if (app.path === "trash://") return [Host.python, app.ctl, "trash-list"]
            if (app.searching) return [Host.python, app.ctl, "search", app.path, app.query]
                                       .concat(app.hiddenOn ? ["--hidden"] : [])
            return [Host.python, app.ctl, "list", app.path, "--sort", app.sortKey]
                   .concat(app.sortDesc ? ["--desc"] : [])
                   .concat(app.hiddenOn ? ["--hidden"] : [])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                app.loading = false
                try {
                    var d = JSON.parse(this.text)
                    if (d.ok === false) {
                        app.rawEntries = []
                        app.note(d.err || "Ordner lässt sich nicht lesen", true)
                    } else {
                        app.rawEntries = d.entries || []
                        app.stats = d.stats || app.stats
                        app.writable = d.writable !== false
                    }
                } catch (e) {
                    app.rawEntries = []
                    app.note("Antwort unlesbar", true)
                }
                // Nach dem Hochgehen den verlassenen Ordner auswählen.
                if (app.pendingSelect !== "") {
                    var i = app.indexOfPath(app.pendingSelect)
                    if (i >= 0) { app.setSel([app.pendingSelect]); app.cursor = i; app.anchorIndex = i }
                    app.pendingSelect = ""
                }
            }
        }
        onExited: {
            // Kam während des Ladens eine neue Anfrage (getippte Suche,
            // Änderung im Ordner), dann jetzt noch einmal.
            if (listProc.wanted) { listProc.wanted = false; listProc.running = true }
        }
        onRunningChanged: if (running) listProc.wanted = false
    }

    Process {
        id: placesProc
        command: [Host.python, app.ctl, "places"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { app.places = JSON.parse(this.text) } catch (e) {}
            }
        }
    }

    Process {
        id: diskProc
        property string p: ""
        command: [Host.python, app.ctl, "disk", p]
        stdout: StdioCollector {
            onStreamFinished: { try { app.disk = JSON.parse(this.text) } catch (e) {} }
        }
    }

    Process {
        id: infoProc
        property string p: ""
        command: [Host.python, app.ctl, "info", p]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    // Zwischenzeitlich weitergeklickt? Dann gehört die
                    // Antwort zu etwas, das niemand mehr ansieht.
                    if (app.detailEntry && d.path === app.detailEntry.path) app.infoData = d
                } catch (e) {}
            }
        }
    }

    // ------------------------------------------------------------------
    //  Der Ordner unter Beobachtung (§40: Watcher statt Poller).
    //
    //  inotifywait meldet jede Änderung sofort. Ein Zeitgeber, der jede
    //  Sekunde nachsieht, wäre bei einem Download-Ordner eine Sekunde zu
    //  spät und kostet den ganzen Tag Prozesse. Gesammelt wird trotzdem:
    //  ein Entpacken löst hunderte Meldungen aus, und für jede neu zu laden
    //  hieße, die Liste hundertmal zu bauen.
    // ------------------------------------------------------------------
    Process {
        id: watchProc
        running: false
        // Über das Skript und nicht direkt: es bindet den Beobachter an
        // dieses Fenster. Direkt gestartet blieb er nach dem Schließen am
        // Leben — gefunden nach einem Testnachmittag, an dem vier davon
        // Ordnern zusahen, die längst niemand mehr offen hatte.
        command: [Host.python, app.ctl, "watch", app.watchDir]
        stdout: SplitParser { onRead: watchSettle.restart() }
    }
    property string watchDir: ""
    Timer { id: watchSettle; interval: 420; onTriggered: app.reload() }
    Timer {
        id: watchKick
        interval: 60
        onTriggered: {
            if (app.watchDir !== "" && app.watchDir.indexOf("://") < 0)
                watchProc.running = true
        }
    }
    onPathChanged: {
        watchProc.running = false
        watchDir = path
        watchKick.restart()
    }

    // ------------------------------------------------------------------
    //  Ruf von außen (§92)
    //
    //  Will jemand einen Ordner öffnen, während das Fenster schon steht —
    //  aus dem Dateidialog eines anderen Programms etwa, oder aus dem
    //  Terminal —, bekommt er einen neuen Reiter.
    //
    //  [eigenständig] Die Quickshell-Fassung ging dafür über einen Zettel
    //  (~/.cache/noctis-files/open), dem das Fenster zusah, und musste den
    //  Zettel von vorgestern beim Start ignorieren. Jetzt ruft der zweite
    //  Start das laufende Programm direkt an (Host.claim, eine Steckdose in
    //  $XDG_RUNTIME_DIR) — einen alten Ruf gibt es damit nicht mehr.
    // ------------------------------------------------------------------
    Connections {
        target: Host
        function onOpenRequested(p) {
            if (p === "" || p === app.path) return
            app.openInNewTab(p)
        }
    }

    // ==================================================================
    //  Vorschaubilder
    //
    //  Ein einziger langlebiger Prozess, der Pfade über die Standardeingabe
    //  entgegennimmt. Ein Prozess je Kachel wäre bei einem Ordner voller
    //  Filme ein Prozessgewitter, und das Fenster stünde, während es tobt.
    //
    //  Die Antworten werden gesammelt und alle 140 ms auf einmal übernommen.
    //  Jede einzeln zu übernehmen hieße, die Karte `thumbs` hundertmal neu zu
    //  setzen — und jedes Mal rechnet QML sämtliche Bindungen daran neu.
    // ==================================================================
    property var thumbs: ({})
    property var thumbAsked: ({})
    property var thumbInbox: ({})

    function wantThumb(p) {
        if (thumbAsked[p] === true) return
        thumbAsked[p] = true
        if (thumbProc.running)
            thumbProc.write(p + "\t" + Math.round(Math.max(160, tileSize * 2)) + "\n")
    }

    Process {
        id: thumbProc
        command: [Host.python, app.ctl, "thumbd"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: l => {
                var i = l.indexOf("\t")
                if (i < 0) return
                app.thumbInbox[l.substring(0, i)] = l.substring(i + 1)
                thumbFlush.restart()
            }
        }
        onExited: thumbRestart.restart()
    }
    Timer {
        id: thumbFlush
        interval: 140
        onTriggered: {
            var next = {}
            for (var k in app.thumbs) next[k] = app.thumbs[k]
            for (var j in app.thumbInbox) next[j] = app.thumbInbox[j]
            app.thumbInbox = ({})
            app.thumbs = next
        }
    }
    Timer {
        id: thumbRestart
        interval: 1500
        onTriggered: { app.thumbAsked = ({}); thumbProc.running = true }
    }

    // ==================================================================
    //  Einstellungen zurückschreiben
    // ==================================================================
    Process { id: cfgProc; property var args: []; command: [Host.python, app.ctl, "set"].concat(args) }
    property var cfgQueue: []
    function saveConfig(k, v) {
        // Mehrere Änderungen kurz hintereinander (Ansicht + Sortierung) in
        // einen Aufruf legen: sonst überholen sich zwei Schreibvorgänge und
        // der zweite überschreibt den ersten mit altem Stand.
        var q = cfgQueue.slice()
        q.push(String(k)); q.push(String(v))
        cfgQueue = q
        cfgWrite.restart()
    }
    Timer {
        id: cfgWrite
        interval: 260
        onTriggered: {
            if (app.cfgQueue.length === 0 || cfgProc.running) { if (cfgProc.running) cfgWrite.restart(); return }
            cfgProc.args = app.cfgQueue
            app.cfgQueue = []
            cfgProc.running = true
        }
    }

    function toggleView() {
        gridMode = !gridMode
        saveConfig("view", gridMode ? "grid" : "list")
    }
    function toggleDetail() { detail = !detail; saveConfig("detail", detail) }
    function toggleHidden() {
        hiddenOn = !hiddenOn
        saveConfig("hidden", hiddenOn)
        reload()
    }
    function sortBy(k) {
        if (sortKey === k) sortDesc = !sortDesc
        else { sortKey = k; sortDesc = (k === "mtime" || k === "size") }
        saveConfig("sort", sortKey)
        saveConfig("desc", sortDesc)
        reload()
    }
    function setTile(px) {
        tileSize = Noctis.u(Math.max(72, Math.min(240, px)))
        saveConfig("tile", Math.round(tileSize / Noctis.k))
    }

    function setQuery(t) {
        query = t
        searchDebounce.restart()
    }
    Timer {
        id: searchDebounce
        interval: 300
        onTriggered: { app.clearSel(); app.reload() }
    }

    // ==================================================================
    //  Ziehen und Ablegen
    // ==================================================================
    function dragPaths(e) {
        if (selMap[e.path] === true && selList.length > 0) return selList.slice()
        return [e.path]
    }
    function dragUris(e) {
        var ps = dragPaths(e)
        var out = []
        for (var i = 0; i < ps.length; i++) out.push(K.toUri(ps[i]))
        // Mit Wagenrücklauf, wie es die Festlegung für text/uri-list will.
        // Ohne ihn nehmen manche Programme nur die erste Adresse an.
        return out.join("\r\n") + "\r\n"
    }

    function pathsFromDrop(d) {
        var res = []
        var us = d.urls
        for (var i = 0; i < us.length; i++) {
            var p = K.fromUri(us[i])
            if (p.charAt(0) === "/") res.push(p)
        }
        return res
    }

    // Innen verschieben, von außen kopieren.
    //
    // Das ist keine Willkür, sondern das, was in beiden Fällen gemeint ist:
    // wer im selben Fenster etwas von einem Ordner in den anderen zieht, will
    // es dort HABEN und nicht zweimal. Wer etwas aus einem anderen Programm
    // hereinzieht, will eine Kopie — das Original gehört dem anderen Programm.
    // Wer es anders will, hält beim Loslassen Strg (kopieren) oder Umschalt
    // (verschieben); das reicht der Compositor als `proposedAction` durch.
    function dropOnto(dest, d) {
        if (dest === "" || dest.indexOf("://") > 0) return
        var ps = pathsFromDrop(d)
        if (ps.length === 0) return
        var verb = dragActive ? "move" : "copy"
        if (d.proposedAction === Qt.MoveAction) verb = "move"
        else if (d.proposedAction === Qt.LinkAction) verb = "link"
        else if (d.proposedAction === Qt.CopyAction && !dragActive) verb = "copy"

        // In den eigenen Ordner gezogen: nichts tun, statt hundert
        // „(2)"-Kopien anzulegen.
        var same = true
        for (var i = 0; i < ps.length; i++) {
            var par = ps[i].substring(0, ps[i].lastIndexOf("/"))
            if (par !== dest) { same = false; break }
        }
        if (same && verb === "move") return
        d.accept()
        runOp([verb, dest].concat(ps), "ask",
              verb === "move" ? "Verschieben" : (verb === "link" ? "Verknüpfen" : "Kopieren"))
    }

    function trashDropped(d) {
        var ps = pathsFromDrop(d)
        if (ps.length === 0) return
        d.accept()
        runOp(["trash"].concat(ps), "", "In den Papierkorb")
    }

    // ==================================================================
    //  Arbeiten an Dateien
    //
    //  Alles läuft durch EINE Stelle: runOp(). Dadurch gibt es genau einen
    //  Fortschrittsbalken, genau eine Rückfrage bei Namensgleichheit und
    //  genau eine Stelle, an der etwas rückgängig gemacht werden kann.
    // ==================================================================
    property bool opBusy: false
    property string opLabel: ""
    property real opProgress: 0
    property string opName: ""
    property var opArgs: []
    property string opConflict: ""
    property var undoStack: []

    function runOp(args, conflict, label) {
        if (opBusy) { note("Einen Augenblick — es läuft noch etwas.", false); return }
        opArgs = args
        opConflict = conflict || ""
        opLabel = label || ""
        opBusy = true
        opProgress = 0
        opName = ""
        opProc.args = args.concat(conflict ? ["--conflict", conflict] : [])
        opProc.running = true
    }

    Process {
        id: opProc
        property var args: []
        command: [Host.python, app.ctl, "op"].concat(args)
        stdout: SplitParser {
            onRead: l => {
                var d
                try { d = JSON.parse(l) } catch (e) { return }
                if (d.t === "p") {
                    app.opProgress = d.total > 0 ? d.done / d.total : 0
                    app.opName = d.name || ""
                } else if (d.t === "conflict") {
                    app.opBusy = false
                    app.askConflict(d.names)
                } else if (d.t === "done") {
                    app.opBusy = false
                    app.opProgress = 1
                    if (!d.ok) app.note(d.err || "Hat nicht geklappt", true)
                    else app.afterOp(d)
                    app.refresh()
                }
            }
        }
        onExited: app.opBusy = false
    }

    function afterOp(d) {
        var verb = opArgs[0]
        if (verb === "move") {
            var srcs = opArgs.slice(2)
            var back = []
            for (var i = 0; i < srcs.length; i++) {
                var from = srcs[i].substring(0, srcs[i].lastIndexOf("/"))
                back.push({ name: srcs[i].substring(srcs[i].lastIndexOf("/") + 1), to: from })
            }
            pushUndo({ kind: "move", dst: opArgs[1], items: back })
            note(srcs.length + (srcs.length === 1 ? " Eintrag" : " Einträge") + " verschoben")
        } else if (verb === "trash") {
            pushUndo({ kind: "trash", n: opArgs.length - 1 })
            var n = opArgs.length - 1
            note(n + (n === 1 ? " Eintrag" : " Einträge") + " im Papierkorb")
        } else if (verb === "rename") {
            pushUndo({ kind: "rename", path: d.path,
                       old: opArgs[1].substring(opArgs[1].lastIndexOf("/") + 1) })
            note("Umbenannt")
        } else if (verb === "copy") {
            note((opArgs.length - 2) + " kopiert")
        } else if (verb === "mkdir" || verb === "touch") {
            pendingSelect = d.path
        } else if (verb === "compress") {
            pendingSelect = d.path
            note("Archiv angelegt")
        } else if (verb === "extract") {
            pendingSelect = d.path
            note("Entpackt")
        }
    }

    function pushUndo(u) {
        var s = undoStack.slice()
        s.push(u)
        if (s.length > 12) s.shift()
        undoStack = s
    }

    // Rückgängig gibt es für das, was sich sauber umkehren lässt:
    // verschieben, umbenennen, wegwerfen. Für Kopieren NICHT — das
    // Gegenteil einer Kopie wäre Löschen, und ein Rückgängig, das Dateien
    // löscht, ist die schlechteste Art, hilfsbereit zu sein.
    function undo() {
        if (undoStack.length === 0) { note("Nichts rückgängig zu machen."); return }
        var s = undoStack.slice()
        var u = s.pop()
        undoStack = s
        if (u.kind === "move") {
            // Bündelweise zurück: alles, was in denselben Ordner gehört, in
            // einem Aufruf.
            var byDir = {}
            for (var i = 0; i < u.items.length; i++) {
                var it = u.items[i]
                if (!byDir[it.to]) byDir[it.to] = []
                byDir[it.to].push(u.dst + "/" + it.name)
            }
            for (var d in byDir) { runOp(["move", d].concat(byDir[d]), "keep", "Zurück"); break }
            note("Verschieben rückgängig gemacht")
        } else if (u.kind === "rename") {
            runOp(["rename", u.path, u.old], "", "Zurück")
        } else if (u.kind === "trash") {
            restoreProc.n = u.n
            restoreProc.running = true
            note("Aus dem Papierkorb zurückgeholt")
        }
    }

    // Zurückholen heißt hier: die n zuletzt weggeworfenen Einträge. Der
    // Papierkorb führt Buch über den Zeitpunkt, also ist „zuletzt" eine
    // beantwortbare Frage.
    Process {
        id: restoreProc
        property int n: 1
        command: [Host.python, app.ctl, "trash-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    var names = []
                    for (var i = 0; i < Math.min(restoreProc.n, d.entries.length); i++)
                        names.push(d.entries[i].trashName)
                    if (names.length > 0) {
                        restoreDo.args = names
                        restoreDo.running = true
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: restoreDo
        property var args: []
        command: [Host.python, app.ctl, "trash-restore"].concat(args)
        onExited: app.refresh()
    }

    // ==================================================================
    //  Befehle der Oberfläche
    // ==================================================================
    function selPaths() {
        return selList.length > 0 ? selList.slice()
             : (cursor >= 0 && cursor < entries.length ? [entries[cursor].path] : [])
    }

    function askNewFolder() {
        dlg.mode = "input"
        dlg.icon = K.UI.folderNew
        dlg.title = "Neuer Ordner"
        dlg.subtitle = "in " + tabLabel(path)
        dlg.placeholder = "Name"
        dlg.text = "Neuer Ordner"
        dlg.okText = "Anlegen"
        dlg.danger = false
        dlg.selectTo = -1
        dlg.action = "mkdir"
        dlg.show()
    }

    function askNewFile() {
        dlg.mode = "input"
        dlg.icon = K.UI.fileNew
        dlg.title = "Neue Datei"
        dlg.subtitle = "in " + tabLabel(path)
        dlg.placeholder = "Name mit Endung"
        dlg.text = "neu.txt"
        dlg.okText = "Anlegen"
        dlg.danger = false
        dlg.selectTo = 3
        dlg.action = "touch"
        dlg.show()
    }

    function askRename() {
        var e = detailEntry || (selEntries.length > 0 ? selEntries[0] : null)
        if (!e) return
        dlg.mode = "input"
        dlg.icon = K.UI.pencil
        dlg.title = "Umbenennen"
        dlg.subtitle = e.name
        dlg.placeholder = "Neuer Name"
        dlg.text = e.name
        dlg.okText = "Umbenennen"
        dlg.danger = false
        var dot = e.name.lastIndexOf(".")
        dlg.selectTo = (!e.dir && dot > 0) ? dot : -1
        dlg.action = "rename"
        dlg.actionPath = e.path
        dlg.show()
    }

    function askDelete() {
        var ps = selPaths()
        if (ps.length === 0) return
        dlg.mode = "confirm"
        dlg.icon = K.UI.burn
        dlg.title = ps.length === 1 ? "Endgültig löschen?" : ps.length + " Einträge endgültig löschen?"
        dlg.subtitle = ps.length === 1
                       ? "„" + ps[0].substring(ps[0].lastIndexOf("/") + 1)
                         + "“ wird nicht in den Papierkorb gelegt, sondern entfernt. "
                         + "Das lässt sich nicht rückgängig machen."
                       : "Sie werden nicht in den Papierkorb gelegt, sondern entfernt. "
                         + "Das lässt sich nicht rückgängig machen."
        dlg.okText = "Löschen"
        dlg.danger = true
        dlg.action = "delete"
        dlg.show()
    }

    function askEmptyTrash() {
        dlg.mode = "confirm"
        dlg.icon = K.UI.burn
        dlg.title = "Papierkorb leeren?"
        dlg.subtitle = "Alles darin wird endgültig entfernt."
        dlg.okText = "Leeren"
        dlg.danger = true
        dlg.action = "empty"
        dlg.show()
    }

    function askConflict(names) {
        dlg.mode = "choice"
        dlg.icon = K.UI.alert
        dlg.title = names.length === 1 ? "„" + names[0] + "“ gibt es dort schon"
                                       : names.length + " Namen gibt es dort schon"
        dlg.subtitle = names.length > 1 ? names.slice(0, 6).join(", ")
                                          + (names.length > 6 ? " …" : "") : ""
        dlg.choices = [
            { key: "keep",    label: "Beides behalten", variant: "filled" },
            { key: "replace", label: "Ersetzen", variant: "quiet", warn: true },
            { key: "skip",    label: "Überspringen", variant: "quiet" }
        ]
        dlg.action = "conflict"
        dlg.show()
    }

    function trashSelection() {
        var ps = selPaths()
        if (ps.length === 0) return
        if (inTrash) { askDelete(); return }
        runOp(["trash"].concat(ps), "", "In den Papierkorb")
    }

    function clipCopy() {
        var ps = selPaths()
        if (ps.length === 0) return
        clipList = ps
        clipMode = "copy"
        var m = {}
        for (var i = 0; i < ps.length; i++) m[ps[i]] = true
        clipMap = m
        Host.copyFiles("copy", ps)
        note(ps.length + (ps.length === 1 ? " Eintrag" : " Einträge") + " kopiert")
    }

    function clipCut() {
        var ps = selPaths()
        if (ps.length === 0) return
        clipList = ps
        clipMode = "cut"
        var m = {}
        for (var i = 0; i < ps.length; i++) m[ps[i]] = true
        clipMap = m
        Host.copyFiles("cut", ps)
        note(ps.length + (ps.length === 1 ? " Eintrag" : " Einträge") + " ausgeschnitten")
    }

    function clipPaste() {
        if (!writable || inTrash) { note("Hier lässt sich nichts ablegen.", true); return }
        if (clipList.length > 0) {
            runOp([clipMode === "cut" ? "move" : "copy", path].concat(clipList), "ask",
                  clipMode === "cut" ? "Verschieben" : "Kopieren")
            if (clipMode === "cut") { clipList = []; clipMap = ({}); clipMode = "" }
            return
        }
        // Nichts im eigenen Speicher: dann steht vielleicht etwas in der
        // Zwischenablage des Systems — aus einem anderen Dateimanager.
        //
        // [eigenständig] Die Zwischenablage geht über Qt statt über
        // wl-copy/wl-paste: so läuft es auch unter X11, und die Dateien
        // stehen in allen drei üblichen Formen gleichzeitig darin (GNOME,
        // KDE, Adressliste). wl-copy konnte je Aufruf nur eine Form, und der
        // zweite Aufruf ersetzte den ersten.
        var d = Host.pasteFiles()
        if (d.paths && d.paths.length > 0)
            runOp([d.mode === "cut" ? "move" : "copy", path].concat(d.paths),
                  "ask", d.mode === "cut" ? "Verschieben" : "Kopieren")
        else note("Die Zwischenablage enthält keine Dateien.")
    }

    function copyPath() {
        var ps = selPaths()
        if (ps.length === 0) ps = [path]
        Host.copyText(ps)
        note(ps.length === 1 ? "Pfad gemerkt" : ps.length + " Pfade gemerkt")
    }

    function duplicate() {
        var ps = selPaths()
        if (ps.length === 0) return
        runOp(["copy", path].concat(ps), "keep", "Verdoppeln")
    }

    function compress() {
        var ps = selPaths()
        if (ps.length === 0) return
        runOp(["compress", path].concat(ps), "", "Packen")
    }

    function extract() {
        var ps = selPaths()
        if (ps.length === 0) return
        runOp(["extract", ps[0], path], "", "Entpacken")
    }

    function openTerminal() {
        termProc.p = inTrash ? home : path
        termProc.running = true
    }
    Process { id: termProc; property string p: ""; command: [Host.python, app.ctl, "term", p] }

    Process { id: openProc; property var args: []; command: [Host.python, app.ctl, "open"].concat(args) }

    Process {
        id: appsProc
        property string p: ""
        command: [Host.python, app.ctl, "apps", p]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text)
                    var items = [], acts = []
                    for (var i = 0; i < d.apps.length; i++) {
                        items.push({ label: d.apps[i].name + (d.apps[i].default ? "  ·  Vorgabe" : ""),
                                     icon: K.UI.openNew })
                        acts.push("open:" + d.apps[i].id)
                    }
                    if (items.length === 0) {
                        items.push({ label: "Kein Programm gefunden", icon: K.UI.alert })
                        acts.push("")
                    }
                    app.menuActs = acts
                    menu.items = items
                    menu.popup(app.menuX, app.menuY)
                } catch (e) {}
            }
        }
    }

    function openWith() {
        var e = detailEntry || (selEntries.length > 0 ? selEntries[0] : null)
        if (!e) return
        appsProc.p = e.path
        appsProc.running = true
    }

    function toggleFavorite(p) {
        var isFav = false
        if (places) for (var i = 0; i < places.favorites.length; i++)
            if (places.favorites[i].path === p) isFav = true
        favProc.args = [isFav ? "remove" : "add", p]
        favProc.running = true
        note(isFav ? "Aus den Favoriten entfernt" : "Zu den Favoriten gelegt")
    }
    Process {
        id: favProc
        property var args: []
        command: [Host.python, app.ctl, "fav"].concat(args)
        onExited: placesProc.running = true
    }

    function mount(dev) { runOp(["mount", dev.dev], "", "Einhängen") }
    function unmount(dev) { runOp(["unmount", dev.dev], "", "Aushängen") }

    // ==================================================================
    //  Schnellansicht
    // ==================================================================
    function quickLook() {
        var e = detailEntry || (cursor >= 0 && cursor < entries.length ? entries[cursor] : null)
        if (!e) return
        if (quick.open) { quick.open = false; return }
        quick.entry = e
        quick.open = true
        if (!detailEntry) { setSel([e.path]); cursor = indexOfPath(e.path) }
    }
    function quickStep(d) {
        var i = indexOfPath(quick.entry ? quick.entry.path : "")
        var n = i + d
        if (n < 0 || n >= entries.length) return
        quick.entry = entries[n]
        setSel([entries[n].path])
        cursor = n
        viewer.positionAt(n)
    }

    // ==================================================================
    //  Menüs
    //
    //  Ein LMenu, das je nach Anlass anders gefüllt wird. Zu jedem Eintrag
    //  gehört ein Schlüssel in `menuActs` an derselben Stelle — LMenu meldet
    //  eine Nummer zurück, und eine Nummer allein sagt nicht, was gemeint war.
    // ==================================================================
    property var menuActs: []
    property real menuX: 0
    property real menuY: 0
    property string menuPath: ""
    property var menuDevice: null

    function menuForEntries(x, y) {
        menuX = x; menuY = y
        var ps = selPaths()
        var n = ps.length
        var e = selEntries.length > 0 ? selEntries[0] : null
        var items = [], acts = []

        function add(label, icon, act, warn) {
            items.push({ label: label, icon: icon, warn: warn === true })
            acts.push(act)
        }

        if (inTrash) {
            add("Zurücklegen", K.UI.restore, "restore")
            add("Endgültig löschen", K.UI.burn, "delete", true)
            menuActs = acts
            menu.items = items
            menu.popup(x, y)
            return
        }

        add(n > 1 ? "Alle öffnen" : "Öffnen", e && e.dir ? K.UI.folderOpen : K.UI.openNew, "open")
        if (n === 1 && e && e.dir) add("In neuem Reiter öffnen", K.UI.plus, "newtab")
        if (n === 1 && e && !e.dir) add("Öffnen mit …", K.UI.dots, "openwith")
        add("Vorschau", K.UI.eye, "quick")
        add("Kopieren", K.UI.copy, "copy")
        add("Ausschneiden", K.UI.cut, "cut")
        add("Verdoppeln", K.UI.duplicate, "duplicate")
        if (n === 1) add("Umbenennen", K.UI.pencil, "rename")
        add("Pfad merken", K.UI.link, "copypath")
        if (n === 1 && e && e.kind === "archive") add("Hierher entpacken", K.UI.zip, "extract")
        add(n > 1 ? "Als Archiv packen" : "Als Archiv packen", K.UI.zip, "compress")
        if (n === 1 && e && e.dir) add("Zu den Favoriten", K.UI.star, "fav")
        if (n === 1 && e && e.dir) add("Terminal hier öffnen", K.UI.term, "termhere")
        add("In den Papierkorb", K.UI.trash, "trash", true)

        menuActs = acts
        menu.items = items
        menu.popup(x, y)
    }

    function menuForFolder(x, y) {
        menuX = x; menuY = y
        var items = [], acts = []
        function add(label, icon, act, warn) {
            items.push({ label: label, icon: icon, warn: warn === true })
            acts.push(act)
        }
        if (inTrash) {
            add("Papierkorb leeren", K.UI.burn, "empty", true)
            add("Neu einlesen", K.UI.refresh, "reload")
        } else {
            add("Neuer Ordner", K.UI.folderNew, "mkdir")
            add("Neue Datei", K.UI.fileNew, "touch")
            add("Einfügen", K.UI.paste, "paste")
            add("Alles auswählen", K.UI.check, "all")
            add(gridMode ? "Als Liste" : "Als Raster", gridMode ? K.UI.list : K.UI.grid, "view")
            add("Sortieren …", K.UI.sort, "sortmenu")
            add(hiddenOn ? "Versteckte ausblenden" : "Versteckte einblenden",
                hiddenOn ? K.UI.eyeOff : K.UI.eye, "hidden")
            add("Zu den Favoriten", K.UI.star, "favhere")
            add("Terminal hier öffnen", K.UI.term, "term")
            add("Neu einlesen", K.UI.refresh, "reload")
        }
        menuActs = acts
        menu.items = items
        menu.popup(x, y)
    }

    // Die Filterliste des fragenden Programms als Menü — plus „Alle Dateien",
    // denn kein Filter ist auch eine Wahl, und manchmal die einzig richtige.
    function menuForPickFilter(x, y) {
        menuX = x; menuY = y
        var items = [], acts = []
        var fs = (pickReq && pickReq.filters) ? pickReq.filters : []
        for (var i = 0; i < fs.length; i++) {
            items.push({ label: fs[i].name, icon: pickFilter === i ? K.UI.check : "" })
            acts.push("filter:" + i)
        }
        items.push({ label: "Alle Dateien", icon: pickFilter < 0 ? K.UI.check : "" })
        acts.push("filter:-1")
        menuActs = acts
        menu.items = items
        menu.popup(x, y)
    }

    function menuForSort(x, y) {
        menuX = x; menuY = y
        var defs = [["name", "Name"], ["size", "Größe"], ["mtime", "Geändert"], ["kind", "Art"]]
        var items = [], acts = []
        for (var i = 0; i < defs.length; i++) {
            items.push({ label: defs[i][1] + (sortKey === defs[i][0]
                                              ? (sortDesc ? "  ↓" : "  ↑") : ""),
                         icon: sortKey === defs[i][0] ? K.UI.check : "" })
            acts.push("sort:" + defs[i][0])
        }
        items.push({ label: sortDesc ? "Aufsteigend" : "Absteigend", icon: K.UI.sort })
        acts.push("sortdir")
        menuActs = acts
        menu.items = items
        menu.popup(x, y)
    }

    function menuForPlace(p, isFav, dev, x, y) {
        menuX = x; menuY = y; menuPath = p; menuDevice = dev
        var items = [], acts = []
        if (p === "trash://") {
            items.push({ label: "Öffnen", icon: K.UI.trash }); acts.push("goplace")
            items.push({ label: "Papierkorb leeren", icon: K.UI.burn, warn: true }); acts.push("empty")
        } else {
            items.push({ label: "Öffnen", icon: K.UI.folderOpen }); acts.push("goplace")
            items.push({ label: "In neuem Reiter öffnen", icon: K.UI.plus }); acts.push("placetab")
            if (dev && dev.mounted) { items.push({ label: "Auswerfen", icon: K.UI.eject }); acts.push("eject") }
            if (dev && !dev.mounted) { items.push({ label: "Einhängen", icon: K.UI.disk }); acts.push("domount") }
            if (isFav) { items.push({ label: "Aus Favoriten entfernen", icon: K.UI.starOff }); acts.push("unfav") }
            else if (!dev) { items.push({ label: "Zu den Favoriten", icon: K.UI.star }); acts.push("favplace") }
        }
        menuActs = acts
        menu.items = items
        menu.popup(x, y)
    }

    function doAction(a) {
        if (!a || a === "") return
        if (a.indexOf("sort:") === 0) { sortBy(a.substring(5)); return }
        if (a.indexOf("filter:") === 0) { pickFilter = parseInt(a.substring(7)); return }
        if (a.indexOf("open:") === 0) {
            var e = selEntries.length > 0 ? selEntries[0] : null
            if (e) { openProc.args = [e.path, a.substring(5)]; openProc.running = true }
            return
        }
        switch (a) {
        case "open":      for (var i = 0; i < selEntries.length && i < 12; i++) activate(selEntries[i]); break
        case "newtab":    if (selEntries.length > 0) openInNewTab(selEntries[0].path); break
        case "openwith":  openWith(); break
        case "quick":     quickLook(); break
        case "copy":      clipCopy(); break
        case "cut":       clipCut(); break
        case "paste":     clipPaste(); break
        case "duplicate": duplicate(); break
        case "rename":    askRename(); break
        case "copypath":  copyPath(); break
        case "compress":  compress(); break
        case "extract":   extract(); break
        case "trash":     trashSelection(); break
        case "delete":    askDelete(); break
        case "restore":   restoreSelected(); break
        case "empty":     askEmptyTrash(); break
        case "mkdir":     askNewFolder(); break
        case "touch":     askNewFile(); break
        case "all":       selectAll(); break
        case "view":      toggleView(); break
        case "hidden":    toggleHidden(); break
        case "sortmenu":  menuForSort(menuX, menuY); break
        case "sortdir":   sortDesc = !sortDesc; saveConfig("desc", sortDesc); reload(); break
        case "reload":    refresh(); break
        case "term":      openTerminal(); break
        case "termhere":  if (selEntries.length > 0) { termProc.p = selEntries[0].path; termProc.running = true }; break
        case "fav":       if (selEntries.length > 0) toggleFavorite(selEntries[0].path); break
        case "favhere":   toggleFavorite(path); break
        case "favplace":  toggleFavorite(menuPath); break
        case "unfav":     toggleFavorite(menuPath); break
        case "goplace":   go(menuPath); break
        case "placetab":  openInNewTab(menuPath); break
        case "eject":     if (menuDevice) unmount(menuDevice); break
        case "domount":   if (menuDevice) mount(menuDevice); break
        }
    }

    function restoreSelected() {
        var names = []
        for (var i = 0; i < selEntries.length; i++)
            if (selEntries[i].trashName) names.push(selEntries[i].trashName)
        if (names.length === 0) return
        restoreDo.args = names
        restoreDo.running = true
        note(names.length + (names.length === 1 ? " Eintrag" : " Einträge") + " zurückgelegt")
    }

    function menuAtCursor() {
        if (selList.length === 0 && cursor < 0) {
            menuForFolder(stage.width * 0.4, stage.height * 0.35)
            return
        }
        var i = cursor >= 0 ? cursor : indexOfPath(selList[0])
        var pt = viewer.pointFor(i)
        var p = viewer.mapToItem(null, pt.x, pt.y)
        menuForEntries(p.x, p.y)
    }

    // ==================================================================
    //  Aufbau
    // ==================================================================
    // Die Scheibe. Keine eigene Rundung: Hyprland rundet Fenster selbst, und
    // zwei Rundungen übereinander ergeben an den Ecken einen hellen Saum.
    Rectangle {
        anchors.fill: parent
        color: Noctis.plateDeep
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true

        FmSidebar {
            id: rail
            app: app
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: Noctis.u(208)
        }

        FmTopBar {
            id: top
            app: app
            anchors.top: parent.top
            anchors.left: rail.right
            anchors.right: parent.right
        }

        LSurface {
            id: sheet
            anchors.top: top.bottom
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: statusBar.top
            anchors.margins: Noctis.u(12)
            anchors.topMargin: 0
            // Nur ein Hauch heller als die Scheibe, keine zweite Scheibe:
            // zwei Milchglasschichten übereinander sind zusammen fast
            // deckend, und dann ist die Fläche, auf der man liest, wieder
            // undurchsichtig.
            fill: Noctis.fill1
            clipContent: true

            FmView {
                id: viewer
                app: app
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: app.detailShown ? info.left : parent.right
                model: app.entries
                gridMode: app.gridMode
                tileSize: app.tileSize
                searching: app.searching
                visible: app.entries.length > 0
            }

            // ---- Leere Zustände ----
            // Nichts passt zum Filter — der Ordner selbst hat Inhalt.
            LEmpty {
                anchors.fill: parent
                anchors.rightMargin: app.detailShown ? info.width : 0
                visible: app.pickFiltered && !app.loading && !app.searching
                icon: K.UI.eyeOff
                title: "Nichts passt zum Filter"
                subtitle: {
                    var n = app.rawEntries.length
                    var f = (app.pickReq && app.pickFilter >= 0
                             && app.pickReq.filters && app.pickFilter < app.pickReq.filters.length)
                            ? app.pickReq.filters[app.pickFilter].name : ""
                    return "Hier liegen " + n + (n === 1 ? " Eintrag" : " Einträge")
                         + (f !== "" ? ", aber keiner davon ist „" + f + "“." : ".")
                }
                actionText: "Alle Dateien zeigen"
                onActionClicked: app.pickFilter = -1
            }

            LEmpty {
                anchors.fill: parent
                anchors.rightMargin: app.detailShown ? info.width : 0
                visible: app.entries.length === 0 && !app.loading && !app.searching
                         && !app.inTrash && !app.pickFiltered
                icon: K.UI.folderOpen
                title: "Dieser Ordner ist leer"
                subtitle: app.stats.hiddenSkipped > 0
                          ? app.stats.hiddenSkipped + " versteckte Einträge sind ausgeblendet."
                          : "Hier hineinziehen, was hierher gehört — oder einen Ordner anlegen."
                actionText: app.writable ? "Ordner anlegen" : ""
                onActionClicked: app.askNewFolder()
            }
            LEmpty {
                anchors.fill: parent
                anchors.rightMargin: app.detailShown ? info.width : 0
                visible: app.entries.length === 0 && !app.loading && app.searching
                icon: K.UI.search
                title: "Nichts gefunden"
                subtitle: "Kein Eintrag unterhalb von „" + app.tabLabel(app.path)
                          + "“ heißt so. Versteckte Dateien werden nur mitgesucht, "
                          + "wenn sie auch angezeigt werden."
            }
            LEmpty {
                anchors.fill: parent
                anchors.rightMargin: app.detailShown ? info.width : 0
                visible: app.entries.length === 0 && !app.loading && app.inTrash
                icon: K.UI.trash
                title: "Der Papierkorb ist leer"
                subtitle: "Was hier landet, bleibt liegen, bis man es wegwirft."
            }

            // ---- Auskunftsspalte ----
            Item {
                id: info
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: app.detailShown ? Noctis.u(272) : 0
                visible: width > 2
                clip: true

                Behavior on width {
                    NumberAnimation { duration: Noctis.mBase; easing.type: Noctis.easeOut }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Noctis.hairline
                }

                FmDetail {
                    app: app
                    anchors.fill: parent
                    anchors.leftMargin: 1
                }
            }
        }

        // ---------------- Fußleiste ----------------
        //
        //  Sie beantwortet drei Fragen, ohne dass man sie stellt: was liegt
        //  hier, was habe ich gewählt, und läuft gerade etwas. Der
        //  Fortschritt ersetzt dabei die anderen beiden — solange kopiert
        //  wird, ist nichts anderes wichtig.
        FmPickBar {
            id: pickBar
            app: app
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: implicitHeight
        }

        Item {
            id: statusBar
            anchors.left: rail.right
            anchors.right: parent.right
            anchors.bottom: pickBar.top
            height: Noctis.u(30)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Noctis.u(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Noctis.sp3
                visible: !app.opBusy

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (app.loading) return "Lädt …"
                        var s = app.viewStats
                        var parts = []
                        if (s.dirs > 0) parts.push(s.dirs + (s.dirs === 1 ? " Ordner" : " Ordner"))
                        if (s.files > 0) parts.push(s.files + (s.files === 1 ? " Datei" : " Dateien"))
                        if (parts.length === 0) return "Leer"
                        return parts.join(" · ") + (s.bytes > 0 ? "  ·  " + K.size(s.bytes) : "")
                    }
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tLabel
                    color: Noctis.ink3
                }

                Rectangle {
                    visible: app.selList.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: selText.implicitWidth + Noctis.u(16)
                    height: Noctis.u(20)
                    radius: height / 2
                    color: Noctis.accentSoft
                    Text {
                        id: selText
                        anchors.centerIn: parent
                        text: app.selList.length + " gewählt"
                              + (app.selBytes > 0 ? " · " + K.size(app.selBytes) : "")
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tMicro
                        font.weight: Noctis.wMed
                        color: Noctis.accent
                    }
                }

                Text {
                    visible: app.stats.hiddenSkipped > 0 && !app.hiddenOn
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.stats.hiddenSkipped + " versteckt"
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tMicro
                    color: Noctis.ink4
                }
            }

            // Fortschritt
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Noctis.u(18)
                anchors.right: parent.right
                anchors.rightMargin: Noctis.u(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Noctis.sp3
                visible: app.opBusy

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.opLabel + (app.opName !== "" ? " · " + app.opName : " …")
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tLabel
                    color: Noctis.ink2
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, parent.width * 0.5)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Noctis.u(180)
                    height: Noctis.u(4)
                    radius: height / 2
                    color: Noctis.fill2
                    Rectangle {
                        width: parent.width * Math.max(0.03, app.opProgress)
                        height: parent.height
                        radius: height / 2
                        color: Noctis.accent
                        Behavior on width { NumberAnimation { duration: 180 } }
                    }
                }
            }

            // Meldungen. Rechts, klein, und sie gehen von selbst wieder —
            // eine Meldung, die stehen bleibt, bis man sie wegklickt, ist
            // bei einem Dateimanager eine Strafe für erfolgreiche Arbeit.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Noctis.u(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Noctis.sp2
                visible: app.message !== ""
                opacity: app.message !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Noctis.mBase } }

                LIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.messageBad ? K.UI.alert : K.UI.check
                    size: Noctis.u(12)
                    color: app.messageBad ? Noctis.danger : Noctis.success
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.message
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tLabel
                    color: app.messageBad ? Noctis.danger : Noctis.ink3
                }
            }
        }

        // ---------------- Schnellansicht, Frage, Menü ----------------
        FmQuickLook { id: quick; app: app }

        FmDialog {
            id: dlg
            property string action: ""
            property string actionPath: ""

            onAccepted: v => {
                if (action === "mkdir") app.runOp(["mkdir", app.path, v], "", "Anlegen")
                else if (action === "touch") app.runOp(["touch", app.path, v], "", "Anlegen")
                else if (action === "rename") app.runOp(["rename", actionPath, v], "", "Umbenennen")
                else if (action === "delete") app.runOp(["delete"].concat(app.selPaths()), "", "Löschen")
                else if (action === "empty") { emptyProc.running = true; app.note("Papierkorb geleert") }
                else if (action === "pickOverwrite")
                    app.pickFinish(true, [K.toUri(app.path + "/" + app.pickName.trim())])
                app.takeFocus()
            }
            onChose: k => {
                if (action === "conflict") {
                    // Dieselbe Arbeit noch einmal, diesmal mit einer Ansage,
                    // was bei Namensgleichheit passieren soll.
                    app.runOp(app.opArgs, k, app.opLabel)
                }
                app.takeFocus()
            }
            onCancelled: app.takeFocus()
        }

        Process {
            id: emptyProc
            command: [Host.python, app.ctl, "trash-empty"]
            onExited: app.refresh()
        }

        LMenu {
            id: menu
            onChosen: i => app.doAction(app.menuActs[i])
        }

        // ================================================================
        //  Tastatur
        //
        //  Die Belegung ist die, die überall gilt — das ist hier kein Mangel
        //  an Eigenständigkeit, sondern der Sinn der Sache: Tastenwege sind
        //  Muskelgedächtnis, und ein Dateimanager, der Strg+C für etwas
        //  anderes benutzt, kostet mehr, als jede eigene Idee einbringt.
        // ================================================================
        Keys.onPressed: e => {
            // Steht etwas obenauf, gehört ihm die Tastatur.
            //
            //  Ohne diese Sperre passiert das hier: das Kontextmenü ist
            //  offen, man drückt Esc — das Menü bleibt stehen (es hört gar
            //  nicht zu) und die Auswahl darunter wird gelöscht. Danach
            //  bezieht sich jeder Menüeintrag auf nichts. Gesehen und
            //  behoben; die Reihenfolge ist Absicht: Frage vor Menü, denn
            //  eine Frage kann ein Menü geöffnet haben.
            if (dlg.open) {
                if (e.key === Qt.Key_Escape) { dlg.close(); dlg.cancelled() }
                // Eine Frage mit mehreren Wegen hat keine Eingabezeile, die
                // den Fokus halten könnte — ohne das hier käme man mit der
                // Tastatur nur wieder heraus, nicht hindurch. Eingabetaste
                // nimmt den ersten (den hervorgehobenen) Weg, die Ziffern
                // nehmen den Weg ihrer Nummer.
                else if (dlg.mode === "choice" && dlg.choices.length > 0) {
                    var pick = -1
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) pick = 0
                    else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9)
                        pick = e.key - Qt.Key_1
                    if (pick >= 0 && pick < dlg.choices.length) {
                        var k = dlg.choices[pick].key
                        dlg.close()
                        dlg.chose(k)
                    }
                }
                e.accepted = true
                return
            }
            if (menu.open) {
                if (e.key === Qt.Key_Escape) menu.close()
                e.accepted = true
                return
            }
            if (quick.open) {
                // Die Schnellansicht hat einen eigenen Tastaturteil und den
                // Fokus; hierher kommt nur, was sie nicht wollte.
                e.accepted = true
                return
            }

            var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
            var shift = (e.modifiers & Qt.ShiftModifier) !== 0
            var alt = (e.modifiers & Qt.AltModifier) !== 0

            if (ctrl) {
                switch (e.key) {
                case Qt.Key_C: app.clipCopy(); e.accepted = true; return
                case Qt.Key_X: app.clipCut(); e.accepted = true; return
                case Qt.Key_V: app.clipPaste(); e.accepted = true; return
                case Qt.Key_A: app.selectAll(); e.accepted = true; return
                case Qt.Key_Z: app.undo(); e.accepted = true; return
                case Qt.Key_H: app.toggleHidden(); e.accepted = true; return
                case Qt.Key_L: crumbEdit(); e.accepted = true; return
                case Qt.Key_F: top.focusSearch(); e.accepted = true; return
                case Qt.Key_T: app.openInNewTab(app.path); e.accepted = true; return
                case Qt.Key_W: app.closeTab(app.tabIndex); e.accepted = true; return
                case Qt.Key_N: if (shift) app.askNewFolder(); e.accepted = true; return
                case Qt.Key_D: app.duplicate(); e.accepted = true; return
                case Qt.Key_R: app.refresh(); e.accepted = true; return
                case Qt.Key_1: if (!app.gridMode) app.toggleView(); e.accepted = true; return
                case Qt.Key_2: if (app.gridMode) app.toggleView(); e.accepted = true; return
                case Qt.Key_I: app.toggleDetail(); e.accepted = true; return
                case Qt.Key_Tab:
                    app.selectTab((app.tabIndex + (shift ? -1 : 1) + app.tabs.length) % app.tabs.length)
                    e.accepted = true; return
                case Qt.Key_Plus:
                case Qt.Key_Equal: app.setTile(app.tileSize / Noctis.k + 16); e.accepted = true; return
                case Qt.Key_Minus: app.setTile(app.tileSize / Noctis.k - 16); e.accepted = true; return
                }
            }

            if (alt && e.key === Qt.Key_Left) { app.back(); e.accepted = true; return }
            if (alt && e.key === Qt.Key_Right) { app.forward(); e.accepted = true; return }
            if (alt && e.key === Qt.Key_Up) { app.up(); e.accepted = true; return }

            switch (e.key) {
            case Qt.Key_Backspace: app.up(); e.accepted = true; return
            case Qt.Key_F2: app.askRename(); e.accepted = true; return
            case Qt.Key_F5: app.refresh(); e.accepted = true; return
            case Qt.Key_Delete:
                if (shift) app.askDelete(); else app.trashSelection()
                e.accepted = true; return
            case Qt.Key_Space: app.quickLook(); e.accepted = true; return
            // Die Menü-Taste (und Umschalt+F10) öffnet dasselbe Menü wie der
            // Rechtsklick — an der Stelle, an der der Eintrag steht. Wer mit
            // der Tastatur arbeitet, kommt sonst an die Hälfte der Befehle
            // nicht heran.
            case Qt.Key_Menu:
                app.menuAtCursor(); e.accepted = true; return
            case Qt.Key_F10:
                if (shift) { app.menuAtCursor(); e.accepted = true }
                return
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (app.pickMode && (app.pickSaving || app.pickDirs)
                        && app.selEntries.length === 0) {
                    app.pickConfirm()
                } else if (app.cursor >= 0 && app.cursor < app.entries.length) {
                    app.activate(app.entries[app.cursor])
                } else if (app.selEntries.length > 0) {
                    app.activate(app.selEntries[0])
                } else if (app.pickMode) {
                    app.pickConfirm()
                }
                e.accepted = true; return
            case Qt.Key_Escape:
                if (app.searching) { top.clearSearch(); app.setQuery("") }
                else if (app.pickMode) app.pickCancel()
                else app.clearSel()
                e.accepted = true; return
            case Qt.Key_Home: moveCursorTo(0, shift); e.accepted = true; return
            case Qt.Key_End: moveCursorTo(app.entries.length - 1, shift); e.accepted = true; return
            case Qt.Key_Left: moveCursor(-1, 0, shift); e.accepted = true; return
            case Qt.Key_Right: moveCursor(1, 0, shift); e.accepted = true; return
            case Qt.Key_Up: moveCursor(0, -1, shift); e.accepted = true; return
            case Qt.Key_Down: moveCursor(0, 1, shift); e.accepted = true; return
            case Qt.Key_PageUp: moveCursor(0, -6, shift); e.accepted = true; return
            case Qt.Key_PageDown: moveCursor(0, 6, shift); e.accepted = true; return
            }

            // Tippen springt. Das ist die älteste Bedienidee eines
            // Dateimanagers und immer noch die schnellste: „u" springt zu
            // „urlaub", „ur" zu „urlaub" und nicht zu „unterlagen".
            if (e.text && e.text.length === 1 && e.text >= " " && !ctrl && !alt) {
                typeJump(e.text)
                e.accepted = true
            }
        }

        function crumbEdit() { top.editPath() }

        function moveCursor(dx, dy, extend) {
            var cols = app.gridMode ? viewer.columns : 1
            var i = app.cursor < 0 ? 0 : app.cursor + dx + dy * cols
            moveCursorTo(i, extend)
        }
        function moveCursorTo(i, extend) {
            if (app.entries.length === 0) return
            i = Math.max(0, Math.min(app.entries.length - 1, i))
            app.cursor = i
            app.keyboardActive = true
            if (extend && app.anchorIndex >= 0) {
                var a = Math.min(app.anchorIndex, i), b = Math.max(app.anchorIndex, i)
                var r = []
                for (var j = a; j <= b; j++) r.push(app.entries[j].path)
                app.setSel(r)
            } else {
                app.setSel([app.entries[i].path])
                app.anchorIndex = i
            }
            viewer.positionAt(i)
            if (quick.open) quick.entry = app.entries[i]
        }

        property string typeBuf: ""
        Timer { id: typeReset; interval: 900; onTriggered: stage.typeBuf = "" }
        function typeJump(ch) {
            typeBuf += ch.toLowerCase()
            typeReset.restart()
            for (var i = 0; i < app.entries.length; i++) {
                if (app.entries[i].name.toLowerCase().indexOf(typeBuf) === 0) {
                    moveCursorTo(i, false)
                    return
                }
            }
            // Nichts mit diesem Anfang: dann war es wohl ein neuer Anfang.
            if (typeBuf.length > 1) { typeBuf = ""; typeJump(ch) }
        }
    }
}
