// ============================================================================
//  FmView — die Fläche, auf der die Dateien liegen.
//
//  Zwei Ansichten aus derselben Quelle: Raster und Liste. Umgeschaltet wird
//  nur die Sichtbarkeit, nicht der Zustand — wer in der Liste zwölf Dateien
//  ausgewählt hat und aufs Raster wechselt, hat dort dieselben zwölf.
//
//  --- WARUM HIER EINE FLÄCHE ÜBER ALLEM LIEGT -------------------------------
//  Ein Klick ins Leere muss die Auswahl aufheben, ein Rechtsklick ins Leere
//  muss das Menü des ORDNERS öffnen, und ein Zug ins Leere muss einen Rahmen
//  aufziehen. Eine GridView gibt davon nichts weiter: sie nimmt jeden Druck
//  an, um daraus vielleicht ein Rollen zu machen, und was darunter liegt,
//  sieht ihn nie.
//
//  Deshalb liegt `catcher` DARÜBER und fragt die Ansicht bei jedem Druck:
//  „ist an dieser Stelle überhaupt etwas?" (indexAt). Ist dort eine Kachel,
//  gibt er den Druck mit `accepted = false` weiter und die Kachel bekommt
//  ihn, als läge nichts darüber. Ist dort nichts, gehört der Druck ihm.
//  Das ist die einzige Stelle der App, an der eine unsichtbare Fläche Klicks
//  abfängt — und sie gibt fast jeden davon wieder her.
// ============================================================================

import QtQuick
import QtQuick.Effects
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root

    property var app: null
    property var model: []
    property bool gridMode: true
    property real tileSize: Noctis.u(120)
    property bool searching: false

    readonly property var view: gridMode ? grid : list
    // Wie viele Kacheln nebeneinander? Die Tastatursteuerung braucht das,
    // um zu wissen, was „eine Zeile tiefer" bedeutet.
    readonly property int columns: Math.max(1, Math.floor(grid.width / grid.cellWidth))

    // Die Ansichten sitzen in `box`; wer von außen rechnet, muss deren
    // Ursprung mitzählen.
    readonly property real vx: box.x + view.x
    readonly property real vy: box.y + view.y

    function positionAt(i) {
        if (i < 0) return
        view.positionViewAtIndex(i, gridMode ? GridView.Contain : ListView.Contain)
    }
    function cellRect(i) {
        if (gridMode) {
            var cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
            var r = Math.floor(i / cols), c = i % cols
            return Qt.rect(c * grid.cellWidth, r * grid.cellHeight,
                           grid.cellWidth, grid.cellHeight)
        }
        return Qt.rect(0, i * list.rowH, list.width, list.rowH)
    }
    // Wo liegt der Eintrag Nummer i auf dem Schirm? Gebraucht für das
    // Kontextmenü per Tastatur (Menü-Taste): es muss dort aufgehen, wo der
    // Eintrag steht, und nicht in einer Ecke.
    function pointFor(i) {
        var r = cellRect(i)
        return Qt.point(vx + r.x - view.contentX + r.width * 0.5,
                        vy + r.y - view.contentY + r.height * 0.55)
    }

    function indexAtPoint(x, y) {
        if (gridMode) return grid.indexAt(x + grid.contentX, y + grid.contentY)
        return list.indexAt(x + list.contentX, y + list.contentY)
    }

    // ------------------------------------------------------------------
    //  Kopfzeile der Liste — zugleich die Sortierung.
    //
    //  Die Spaltenüberschrift IST der Schalter. Ein eigener Knopf „sortieren"
    //  neben einer Tabelle, deren Überschriften nicht klickbar sind, ist eine
    //  verpasste Gelegenheit: hier hat jeder schon einmal hingeklickt.
    // ------------------------------------------------------------------
    Item {
        id: head
        visible: !root.gridMode
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Noctis.u(30) : 0

        Row {
            anchors.fill: parent
            anchors.leftMargin: Noctis.u(52)
            anchors.rightMargin: Noctis.u(18)

            Item {
                width: parent.width - Noctis.u(88) - Noctis.u(96) - Noctis.sp4 * 2
                height: parent.height
                FmHeadCell { app: root.app; label: "Name"; keyName: "name"
                             anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
            }
            Item {
                width: Noctis.u(88) + Noctis.sp4
                height: parent.height
                FmHeadCell { app: root.app; label: "Größe"; keyName: "size"; alignRight: true
                             anchors.right: parent.right; anchors.rightMargin: Noctis.sp4
                             anchors.verticalCenter: parent.verticalCenter }
            }
            Item {
                width: Noctis.u(96) + Noctis.sp4
                height: parent.height
                FmHeadCell { app: root.app; label: "Geändert"; keyName: "mtime"; alignRight: true
                             anchors.right: parent.right; anchors.rightMargin: Noctis.sp4
                             anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Noctis.u(16)
            anchors.rightMargin: Noctis.u(16)
            height: 1
            color: Noctis.hairline
        }
    }

    // ------------------------------------------------------------------
    //  Raster
    // ------------------------------------------------------------------
    // ------------------------------------------------------------------
    //  Die Hülle um beide Ansichten.
    //
    //  Sie ist da, damit der Inhalt an Ober- und Unterkante AUSBLENDET
    //  statt abgeschnitten zu werden — dieselbe Maske wie in LScroll und aus
    //  demselben Grund: eine Liste, die an der Kartenkante hart abreißt,
    //  macht aus der Karte einen Kasten mit Rahmen. Die Kopfzeile der Liste
    //  liegt bewusst AUSSERHALB dieser Hülle; eine ausgeblendete
    //  Spaltenüberschrift wäre ein Fehler und kein Übergang.
    // ------------------------------------------------------------------
    Item {
        id: box
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        readonly property bool rolling: root.view && root.view.contentHeight > root.view.height + 4
        readonly property bool fadeTop: rolling && root.view.contentY > 2
        readonly property bool fadeBottom: rolling
            && (root.view.contentHeight - root.view.contentY - root.view.height) > 2

        // [eigenständig] Die Ebene schaltet einen Durchlauf SPÄTER um als
        // `rolling`. `rolling` kippt mitten in einer Größenänderung (beim
        // ersten Aufziehen des Fensters von 0×0 auf volle Größe), und Qt 6.11
        // stürzt ab, wenn in diesem Moment eine Ebene verschwindet, deren
        // Beobachter gerade abgearbeitet werden (QQuickShaderEffectSource::
        // itemGeometryChanged). Ein Bild Verzug sieht niemand.
        property bool layerOn: false
        function syncLayer() { layerOn = rolling }
        onRollingChanged: Qt.callLater(syncLayer)
        Component.onCompleted: syncLayer()
        layer.enabled: layerOn
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
        }

    GridView {
        id: grid
        visible: root.gridMode
        anchors.fill: parent
        anchors.margins: Noctis.u(10)
        anchors.topMargin: Noctis.u(8)
        clip: true
        model: root.model
        cellWidth: root.tileSize + Noctis.u(12)
        cellHeight: root.tileSize + Noctis.u(52)
        cacheBuffer: 900
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3500
        currentIndex: root.app ? root.app.cursor : -1
        highlightFollowsCurrentItem: false

        delegate: FmTile {
            required property var modelData
            required property int index
            app: root.app
            entry: modelData
            index: index
            tileSize: root.tileSize
            width: grid.cellWidth
            height: grid.cellHeight
        }

        // Der Zeiger der Tastatur: ein feiner Rahmen, keine Füllung. Eine
        // gefüllte Fläche hier wäre von einer Auswahl nicht zu unterscheiden.
        Rectangle {
            visible: root.gridMode && root.app && root.app.cursor >= 0
                     && root.app.keyboardActive
            x: root.cellRect(root.app ? root.app.cursor : 0).x + Noctis.u(3)
            y: root.cellRect(root.app ? root.app.cursor : 0).y + Noctis.u(3)
            width: grid.cellWidth - Noctis.u(6)
            height: grid.cellHeight - Noctis.u(6)
            radius: Noctis.rTile
            color: "transparent"
            border.width: 1
            border.color: Noctis.accentEdge
            z: 5
            Behavior on x { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }
            Behavior on y { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }
        }
    }

    // ------------------------------------------------------------------
    //  Liste
    // ------------------------------------------------------------------
    ListView {
        id: list
        visible: !root.gridMode
        anchors.fill: parent
        anchors.margins: Noctis.u(10)
        anchors.topMargin: Noctis.u(4)
        clip: true
        model: root.model
        cacheBuffer: 900
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3500

        readonly property real rowH: Noctis.u(46)

        delegate: FmRow {
            required property var modelData
            required property int index
            app: root.app
            entry: modelData
            index: index
            width: list.width
            showPath: root.searching
        }

        Rectangle {
            visible: !root.gridMode && root.app && root.app.cursor >= 0
                     && root.app.keyboardActive
            x: Noctis.u(4)
            y: root.cellRect(root.app ? root.app.cursor : 0).y + 1
            width: list.width - Noctis.u(8)
            height: list.rowH - 2
            radius: Noctis.rTile
            color: "transparent"
            border.width: 1
            border.color: Noctis.accentEdge
            z: 5
            Behavior on y { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }
        }
    }

    }

    // Die Maske: weiß heißt sichtbar. Die Verlaufsmarken wandern weich mit,
    // der Schalter oben hängt dagegen NUR daran, ob überhaupt gerollt werden
    // kann — sonst würde die Zwischenebene beim Anrollen an- und
    // abgeschaltet, und das sieht man als Ruck.
    Item {
        id: fadeMask
        x: box.x
        y: box.y
        width: box.width
        height: box.height
        visible: false
        layer.enabled: true

        readonly property real stop: box.height > 0
                                     ? Math.min(0.30, Noctis.u(20) / box.height) : 0.04

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0
                               color: Qt.rgba(1, 1, 1, box.fadeTop ? 0 : 1) }
                GradientStop { position: box.fadeTop ? fadeMask.stop : 0.0001
                               color: "#ffffff" }
                GradientStop { position: box.fadeBottom ? 1 - fadeMask.stop : 0.9999
                               color: "#ffffff" }
                GradientStop { position: 1.0
                               color: Qt.rgba(1, 1, 1, box.fadeBottom ? 0 : 1) }
            }
        }
    }

    // ------------------------------------------------------------------
    //  Rollleiste — dieselbe schmale Pille wie in LScroll.
    // ------------------------------------------------------------------
    Rectangle {
        readonly property var f: root.view
        visible: f && f.contentHeight > f.height + 4
        width: Noctis.u(4)
        radius: width / 2
        anchors.right: parent.right
        anchors.rightMargin: Noctis.u(4)
        color: Noctis.alpha(Noctis.inkBase, Noctis.light ? 0.22 : 0.28)
        y: (f && f.contentHeight > 0)
           ? root.vy + (f.contentY / f.contentHeight) * f.height : 0
        height: (f && f.contentHeight > 0)
                ? Math.max(Noctis.u(28), (f.height / f.contentHeight) * f.height) : 0
        opacity: (f && f.moving) || edgeHover.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mBase } }
    }
    MouseArea {
        id: edgeHover
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Noctis.u(18)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ------------------------------------------------------------------
    //  Der Fänger (siehe Kopf)
    // ------------------------------------------------------------------
    MouseArea {
        id: catcher
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 3

        // HIER DARF KEIN `propagateComposedEvents` STEHEN.
        //
        //  Es stand hier, und es hat das Kontextmenü der freien Fläche
        //  unbrauchbar gemacht: das Menü ging beim Drücken auf und
        //  verschwand beim Loslassen wieder. Sichtbar war es nur, solange
        //  man die Taste hielt.
        //
        //  Der Grund liegt daran, wie Qt „geklickt" herstellt. Das ist kein
        //  Ereignis, das vom System kommt, sondern eines, das die MouseArea
        //  aus Drücken und Loslassen ZUSAMMENSETZT. Mit
        //  `propagateComposedEvents` und ohne eigenen `onClicked` reicht sie
        //  dieses zusammengesetzte Ereignis an die Szene weiter — und dort
        //  liegt inzwischen das offene Menü mit seiner Fangfläche ganz oben.
        //  Das Menü hielt den Klick also für „irgendwohin geklickt" und tat,
        //  was es tun soll: sich schließen.
        //
        //  Gebraucht wird die Eigenschaft hier ohnehin nicht. Dass ein Druck
        //  auf eine Kachel durchgereicht wird, macht `mouse.accepted = false`
        //  im `onPressed` — ein anderer Mechanismus, der ohne diese
        //  Eigenschaft auskommt. Gibt der Fänger den Druck ab, bekommt er
        //  danach gar nichts mehr; behält er ihn, gehört ihm der ganze
        //  Vorgang bis zum Loslassen. Beides ist richtig so.

        property point origin: Qt.point(0, 0)
        property bool banding: false

        onPressed: mouse => {
            var inView = mouse.y >= root.vy
            var idx = inView ? root.indexAtPoint(mouse.x - root.vx,
                                                 mouse.y - root.vy) : -1
            if (idx >= 0 || !inView) {
                mouse.accepted = false          // gehört der Kachel
                return
            }
            root.app.keyboardActive = false
            if (mouse.button === Qt.RightButton) {
                root.app.takeFocus()
                var p = root.mapToItem(null, mouse.x, mouse.y)
                root.app.menuForFolder(p.x, p.y)
                return
            }
            if (!(mouse.modifiers & Qt.ControlModifier)) root.app.clearSelFromView()
            else root.app.takeFocus()
            origin = Qt.point(mouse.x, mouse.y)
            banding = true
            band.x = mouse.x; band.y = mouse.y; band.width = 0; band.height = 0
            catcher.addMode = (mouse.modifiers & Qt.ControlModifier) !== 0
            catcher.baseSel = root.app.selList.slice()
        }

        property bool addMode: false
        property var baseSel: []

        onPositionChanged: mouse => {
            if (!banding) return
            band.x = Math.min(origin.x, mouse.x)
            band.y = Math.min(origin.y, mouse.y)
            band.width = Math.abs(mouse.x - origin.x)
            band.height = Math.abs(mouse.y - origin.y)
            root.selectInBand()
        }
        onReleased: banding = false
        onCanceled: banding = false
    }

    // Was der Rahmen berührt, ist ausgewählt. Gerechnet statt geraten: bei
    // festen Zellgrößen weiß man ohne Nachsehen, welche Nummer an welcher
    // Stelle liegt — und das gilt auch für die tausend Kacheln, die gerade
    // gar nicht gebaut sind, weil sie außerhalb des Schirms liegen.
    function selectInBand() {
        if (!app) return
        var bx = band.x - vx + view.contentX
        var by = band.y - vy + view.contentY
        var bw = band.width, bh = band.height
        var hit = catcher.addMode ? catcher.baseSel.slice() : []
        var seen = {}
        for (var i = 0; i < hit.length; i++) seen[hit[i]] = true
        for (var j = 0; j < model.length; j++) {
            var r = cellRect(j)
            if (r.x < bx + bw && r.x + r.width > bx
                && r.y < by + bh && r.y + r.height > by) {
                var p = model[j].path
                if (!seen[p]) { hit.push(p); seen[p] = true }
            }
        }
        app.setSel(hit)
    }

    Rectangle {
        id: band
        visible: catcher.banding && (width > 2 || height > 2)
        z: 4
        color: Noctis.alpha(Noctis.accent, Noctis.light ? 0.12 : 0.18)
        border.width: 1
        border.color: Noctis.accentEdge
        radius: Noctis.rMini
    }

    // ------------------------------------------------------------------
    //  Ziel für Gezogenes: hier ist der OFFENE Ordner gemeint.
    // ------------------------------------------------------------------
    DropArea {
        id: bigDrop
        anchors.fill: parent
        keys: ["text/uri-list"]
        // GANZ NACH HINTEN. Ein gezogener Stapel wird dem obersten Ziel
        // zugestellt, das ihn haben will — und diese Fläche deckt das ganze
        // Raster ab. Läge sie oben, bekäme SIE jeden Zug und die
        // Ordnerkacheln nie einen: „auf einen Ordner ziehen" hätte
        // ausgesehen wie „in den offenen Ordner ziehen", und die Datei wäre
        // eine Ebene zu hoch gelandet. Hinten fängt sie genau das auf, was
        // neben den Kacheln landet.
        z: -1
        onDropped: drop => root.app.dropOnto(root.app.path, drop)
    }

    Rectangle {
        visible: bigDrop.containsDrag
        anchors.fill: parent
        anchors.margins: Noctis.u(6)
        radius: Noctis.rInner
        color: Noctis.alpha(Noctis.accent, 0.07)
        border.width: 2
        border.color: Noctis.accentEdge
        z: 6

        Column {
            anchors.centerIn: parent
            spacing: Noctis.sp3
            LIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: K.UI.share
                size: Noctis.u(40)
                color: Noctis.accent
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hier ablegen"
                font.family: Noctis.fontDisplay
                font.pixelSize: Noctis.tH3
                font.weight: Noctis.wTitle
                color: Noctis.accent
            }
        }
    }
}
