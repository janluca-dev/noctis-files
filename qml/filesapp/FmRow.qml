// ============================================================================
//  FmRow — eine Datei in der Liste.
//
//  Dieselbe Bedienung wie die Kachel (auswählen, öffnen, ziehen, Rechtsklick),
//  nur in einer Zeile. Was sich unterscheidet, ist die Auskunft: im Raster
//  steht unter dem Bild nur das Nötigste, hier stehen Größe und Datum in
//  eigenen Spalten — dafür nimmt man ja die Liste.
//
//  Die Zeile ist niedriger als eine LRow (46 statt 60). Das ist kein Bruch
//  mit der Sprache, sondern ihre Anwendung: eine Einstellungszeile wird
//  einmal gelesen und dann angetippt, eine Dateiliste wird ÜBERFLOGEN. Bei
//  60 Punkten passen zwölf Dateien auf den Schirm, und man rollt durch
//  einen Ordner, den man auf einen Blick überschauen müsste.
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
    property bool showThumbs: true
    property bool showPath: false      // in Suchergebnissen: wo liegt das?

    readonly property bool selected: app && entry ? app.isSel(entry.path) : false
    readonly property bool cut: app && entry ? app.isCut(entry.path) : false
    readonly property bool dropInto: entry && entry.dir && dropZone.containsDrag

    implicitHeight: Noctis.u(46)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Noctis.u(4)
        anchors.rightMargin: Noctis.u(4)
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: Noctis.rTile
        color: root.dropInto ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.16 : 0.24)
             : root.selected ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.10 : 0.16)
             : touch.containsMouse ? Noctis.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
        border.width: root.dropInto ? 1 : 0
        border.color: Noctis.accentEdge
    }

    opacity: root.cut ? 0.45 : 1.0
    Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }

    FmThumb {
        id: thumb
        app: root.app
        entry: root.entry
        anchors.left: parent.left
        anchors.leftMargin: Noctis.u(12)
        anchors.verticalCenter: parent.verticalCenter
        boxSize: Noctis.u(28)
        glyphScale: 0.52
        showKindBadge: false
    }

    Column {
        id: names
        anchors.left: thumb.right
        anchors.leftMargin: Noctis.u(12)
        anchors.right: cols.left
        anchors.rightMargin: Noctis.sp4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Name und — falls es eine Verknüpfung ist — das Kettenglied
        // dahinter. Im Raster sitzt dieses Zeichen an der Ecke des Bildes;
        // in einer Zeile gibt es dort keine Ecke, also steht es hinter dem
        // Namen. Beides sagt dasselbe: hier liegt nicht die Datei selbst.
        Row {
            width: parent.width
            spacing: Noctis.u(5)

            Text {
                width: Math.min(implicitWidth,
                                parent.width - (linkMark.visible ? Noctis.u(16) : 0))
                text: root.entry ? root.entry.name : ""
                elide: Text.ElideMiddle
                font.family: Noctis.fontUi
                font.pixelSize: Noctis.tBody
                font.weight: root.selected ? Noctis.wTitle : Noctis.wMed
                color: root.selected ? Noctis.accent : Noctis.ink
            }
            LIcon {
                id: linkMark
                anchors.verticalCenter: parent.verticalCenter
                visible: root.entry !== null && root.entry.link
                text: K.UI.link
                size: Noctis.tLabel
                color: Noctis.ink4
            }
        }
        Text {
            width: parent.width
            visible: root.entry !== null
                     && (root.showPath || root.entry.orig !== undefined)
            text: !root.entry ? ""
                  : root.app.prettyDir(root.entry.orig !== undefined
                                       ? root.entry.orig : root.entry.path)
            elide: Text.ElideMiddle
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tMicro
            color: Noctis.ink4
        }
    }

    Row {
        id: cols
        anchors.right: parent.right
        anchors.rightMargin: Noctis.u(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Noctis.sp4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Noctis.u(88)
            horizontalAlignment: Text.AlignRight
            text: !root.entry ? ""
                  : root.entry.dir ? (root.entry.count === null ? "—" : root.entry.count + " ›")
                  : K.size(root.entry.size)
            font.family: Noctis.fontNum
            font.features: Noctis.tabular
            font.pixelSize: Noctis.tLabel
            color: Noctis.ink3
            elide: Text.ElideRight
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Noctis.u(96)
            horizontalAlignment: Text.AlignRight
            text: root.entry ? K.when(root.entry.mtime, false) : ""
            font.family: Noctis.fontNum
            font.features: Noctis.tabular
            font.pixelSize: Noctis.tLabel
            color: Noctis.ink4
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        // Das Ziehen übernimmt die MouseArea selbst: `drag.target` macht sie
        // zur Zieh-Erkennung mit Schwelle, und sobald die überschritten ist,
        // setzt sie `drag.active` — woran unten `Drag.active` hängt. Gezogen
        // wird ein unsichtbarer Stellvertreter, damit die Zeile an ihrem
        // Platz bleibt; sichtbar ist ohnehin das Bild am Mauszeiger.
        drag.target: dragProxy
        drag.threshold: 10
        drag.smoothed: false

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) root.armDrag()
            if (mouse.button === Qt.RightButton) {
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
        // Was gezogen wird: die Auswahl, wenn diese Zeile dazugehört —
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

    DropArea {
        id: dropZone
        anchors.fill: parent
        enabled: root.entry !== null && root.entry.dir && !root.dragging
        keys: ["text/uri-list"]
        onDropped: drop => root.app.dropOnto(root.entry.path, drop)
    }
}
