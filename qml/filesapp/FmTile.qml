// ============================================================================
//  FmTile — eine Datei im Raster.
//
//  Die Kachel ist der Ort, an dem drei Dinge zusammenkommen, die in jedem
//  Dateimanager auseinanderfallen: sie zeigt etwas an, sie ist auswählbar,
//  und sie ist der Griff, mit dem man die Datei aus dem Fenster herauszieht.
//
//  --- ZIEHEN NACH DRAUSSEN --------------------------------------------------
//  Qt kennt zwei Arten zu ziehen. Die eine bleibt im eigenen Fenster
//  (Drag.Internal) — damit kann man Kacheln umsortieren, mehr nicht. Die
//  andere (Drag.Automatic) übergibt an das FENSTERSYSTEM: von da an ist es
//  dasselbe Ziehen, das aus jedem anderen Programm kommt, und der Browser,
//  der Chat und der Bildbetrachter nehmen es entgegen. Dafür braucht es
//    · Drag.Automatic,
//    · die Nutzlast als „text/uri-list" (die Adressen, eine je Zeile) und
//    · das Setzen von Drag.active — von selbst passiert nichts.
//
//  Das Bild am Mauszeiger ist die Kachel selbst: grabToImage() malt sie in
//  ein Bild und reicht es weiter. Ohne das hängt am Zeiger ein Umriss, und
//  man sieht nicht, was man trägt.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root

    property var  app: null
    property var  entry: null
    property int  index: -1
    property real tileSize: Noctis.u(120)

    readonly property bool selected: app && entry ? app.isSel(entry.path) : false
    readonly property bool cut: app && entry ? app.isCut(entry.path) : false
    readonly property bool dropInto: entry && entry.dir && dropZone.containsDrag

    implicitWidth: tileSize
    implicitHeight: tileSize + Noctis.u(44)

    // ---------------- Fläche ----------------
    Rectangle {
        id: plate
        anchors.fill: parent
        anchors.margins: Noctis.u(3)
        radius: Noctis.rTile
        color: root.dropInto ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.16 : 0.24)
             : root.selected ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.12 : 0.18)
             : touch.containsMouse ? Noctis.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }

        border.width: root.dropInto ? 1 : 0
        border.color: Noctis.accentEdge
    }

    scale: touch.pressed && !dragging ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }

    // Ausgeschnittenes bleibt sichtbar, aber blass: es liegt noch da und ist
    // doch schon woanders. Verschwinden darf es erst beim Einfügen.
    opacity: root.cut ? 0.45 : 1.0
    Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }

    FmThumb {
        id: thumb
        app: root.app
        entry: root.entry
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Noctis.u(10)
        boxSize: root.tileSize - Noctis.u(26)
        plate: false
        glyphScale: 0.74
    }

    Column {
        anchors.top: thumb.bottom
        anchors.topMargin: Noctis.u(6)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Noctis.u(6)
        anchors.rightMargin: Noctis.u(6)
        spacing: Noctis.u(1)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.entry ? root.entry.name : ""
            elide: Text.ElideMiddle
            maximumLineCount: 2
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tLabel
            font.weight: root.selected ? Noctis.wTitle : Noctis.wMed
            color: root.selected ? Noctis.accent : Noctis.ink
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.entry !== null
            text: !root.entry ? ""
                  : root.entry.orig !== undefined ? root.app.prettyDir(root.entry.orig)
                  // Bei einer Suche ist die Größe die uninteressanteste
                  // Angabe: gefunden ist gefunden, die Frage ist WO.
                  : root.app.searching ? root.app.prettyDir(root.entry.path)
                  : root.entry.dir ? (root.entry.count === null ? ""
                                      : (root.entry.count === 1 ? "1 Eintrag"
                                         : root.entry.count + " Einträge"))
                  : K.size(root.entry.size)
            elide: Text.ElideRight
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tMicro
            color: Noctis.ink4
        }
    }

    // Eine Verknüpfung trägt ihr Zeichen an der Ecke — sonst hält man sie
    // für das Original und wundert sich, dass Löschen nichts löscht.
    Rectangle {
        visible: root.entry && root.entry.link
        anchors.left: thumb.left
        anchors.bottom: thumb.bottom
        width: Noctis.u(17)
        height: width
        radius: width / 2
        color: Noctis.card
        border.width: 1
        border.color: Noctis.hairline
        LIcon {
            anchors.centerIn: parent
            text: K.UI.link
            size: parent.width * 0.55
            color: Noctis.ink3
        }
    }

    // ---------------- Bedienung ----------------

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        // Das Ziehen übernimmt die MouseArea selbst: `drag.target` macht sie
        // zur Zieh-Erkennung mit Schwelle, und sobald die überschritten ist,
        // setzt sie `drag.active` — woran unten `Drag.active` hängt. Gezogen
        // wird ein unsichtbarer Stellvertreter, damit die Kachel an ihrem
        // Platz bleibt; sichtbar ist ohnehin das Bild am Mauszeiger.
        drag.target: dragProxy
        drag.threshold: 10
        drag.smoothed: false

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) root.armDrag()
            if (mouse.button === Qt.RightButton) {
                // Ein Rechtsklick auf etwas Unausgewähltes wählt es zuerst
                // aus. Alles andere führt dazu, dass das Menü sich auf etwas
                // bezieht, das man gar nicht sieht.
                if (!root.selected) root.app.pick(root.entry, 0)
                var p = root.mapToItem(null, mouse.x, mouse.y)
                root.app.menuForEntries(p.x, p.y)
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.entry && root.entry.dir) root.app.openInNewTab(root.entry.path)
            }
        }

        onClicked: mouse => {
            if (mouse.button !== Qt.LeftButton) return
            root.app.pick(root.entry, mouse.modifiers)
        }

        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton) root.app.activate(root.entry)
        }

        // Die Bremse löst sich erst beim Loslassen. Täte sie es schon, wenn
        // der Zug endet, liefe sie ins Leere: die Maustaste hängt ja noch,
        // die MouseArea meldet weiter „ich ziehe", und der eben abgebrochene
        // Zug begänne sofort von vorn.
        onReleased: root.dragStop = false
        onCanceled: root.dragStop = false

    }

    // Der Stellvertreter, an dem die MouseArea zieht. Ohne Anker und ohne
    // Größe: er darf sich bewegen, ohne dass man es sieht.
    Item { id: dragProxy; width: 1; height: 1; visible: false }

    // ---------------- Ziehen nach draußen ----------------
    //
    //  Qt kennt zwei Arten zu ziehen. Die eine bleibt im eigenen Fenster
    //  (Drag.Internal) — damit kann man Kacheln umsortieren, mehr nicht. Die
    //  andere (Drag.Automatic) übergibt an das FENSTERSYSTEM: von da an ist
    //  es dasselbe Ziehen, das aus jedem anderen Programm kommt, und der
    //  Browser, der Chat und der Bildbetrachter nehmen es entgegen.
    //
    //  DER WEG DAHIN WAR EIN UMWEG, UND DER STEHT HIER, DAMIT IHN NIEMAND
    //  NOCH EINMAL GEHT. Zuerst stand hier ein Aufruf von `startDrag()` —
    //  von Hand, nach eigener Schwellenrechnung im `onPositionChanged`. Das
    //  kann nicht gehen: `startDrag()` verlangt, dass der Zug BEREITS läuft
    //  („startDrag() drag must be active"), es ist kein Startknopf. Es warnte
    //  ins Protokoll und tat nichts — jahrelang wäre das nicht aufgefallen,
    //  weil ein nicht beginnender Zug genauso aussieht wie ein Zug, den das
    //  Ziel nicht annimmt.
    //
    //  Richtig ist der Weg, den auch Qts eigenes Beispiel geht: `Drag.active`
    //  an `drag.active` der MouseArea hängen. Die MouseArea kennt die
    //  Schwelle, und das Umlegen von `Drag.active` ist der Start. Alles, was
    //  der Zug mitnehmen soll, muss VORHER stehen — deshalb wird die Nutzlast
    //  beim Drücken gesetzt und nicht erst bei der Bewegung.
    property var  dragData: ({})
    property var  grabbed: null      // festhalten: sonst räumt die
                                     // Speicherverwaltung das Bild weg
    readonly property bool dragging: root.Drag.active

    function armDrag() {
        if (!app || !entry) return
        // Was gezogen wird: die Auswahl, wenn diese Kachel dazugehört —
        // sonst nur sie selbst. Wer eine unausgewählte Datei anfasst, meint
        // diese eine und nicht die zehn von vorhin.
        dragData = {
            "text/uri-list": app.dragUris(entry),
            "text/plain": app.dragPaths(entry).join("\n")
        }
        grabbed = null
        root.grabToImage(function (res) { root.grabbed = res },
                         Qt.size(root.width, root.height))
    }

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: root.dragData
    Drag.imageSource: root.grabbed ? root.grabbed.url : ""
    // NOTBREMSE. Ein Zug, den das Fenstersystem nicht annimmt, endet nie von
    //  selbst: Qt wartet in einer eigenen Ereignisschleife auf ein „fallen
    //  gelassen" oder „abgebrochen", das nie kommt, und das Fenster antwortet
    //  derweil auf nichts. Beobachtet bei künstlich erzeugten Mausklicks, bei
    //  denen der Compositor den Zug gar nicht erst beginnt — bei einer
    //  richtigen Maus soll das nicht vorkommen, aber „soll nicht" ist bei
    //  einem eingefrorenen Dateimanager zu wenig.
    //
    //  Deshalb hängt `Drag.active` nicht nackt an der MouseArea, sondern an
    //  ihr UND an dieser Bremse. Nach einer Minute ohne Ende wird abgebrochen;
    //  wer so lange zieht, hat sich ohnehin anders entschieden.
    property bool dragStop: false

    Timer {
        interval: 60000
        running: root.Drag.active
        onTriggered: root.dragStop = true
    }

    Drag.active: touch.drag.active && !root.dragStop
    Drag.onActiveChanged: {
        if (!root.app) return
        root.app.dragActive = root.Drag.active
        // Nach dem Loslassen kann woanders etwas gelandet sein.
        if (!root.Drag.active) root.app.refresh()
    }

    // ---------------- Ziel für anderes ----------------
    DropArea {
        id: dropZone
        anchors.fill: parent
        enabled: root.entry !== null && root.entry.dir && !root.dragging
        keys: ["text/uri-list"]
        onDropped: drop => root.app.dropOnto(root.entry.path, drop)
    }
}
