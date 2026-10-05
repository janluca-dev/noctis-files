// ============================================================================
//  FmCrumbs — der Pfad als Kette anklickbarer Stücke.
//
//  Ein Dateimanager, der den Pfad nur als Text zeigt, zwingt zum Zurückgehen
//  in Einzelschritten. Hier ist jedes Stück ein Ziel — und zugleich ein
//  Ablageort: zieht man Dateien auf „Persönlich", landen sie dort, ohne dass
//  man erst hinnavigieren müsste.
//
//  Der Pfad liegt in einer Mulde (Noctis.well), nicht auf einer Karte. Er ist
//  ein Eingabefeld — man kann ihn anklicken und tippen (oder Strg+L), und
//  etwas, in das man schreibt, tritt in dieser Sprache nach hinten.
//
//  Ist der Pfad zu lang, wird NICHT gekürzt, sondern gerollt, und zwar ans
//  Ende. Gekürzte Pfade („/home/…/Bilder") sehen ordentlich aus und sagen
//  einem im entscheidenden Moment nicht, in welchem der vier Ordner namens
//  „Bilder" man gerade steht.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null
    property bool editing: false

    readonly property string path: app ? app.path : ""
    readonly property bool special: path.indexOf("://") > 0

    implicitHeight: Noctis.u(38)

    // Wie breit die Mulde sein müsste, damit der ganze Pfad hineinpasst.
    // Die Werkzeugleiste gibt ihr so viel davon, wie übrig ist — eine Mulde,
    // die immer die volle Breite einnimmt, ist zu drei Vierteln leer und
    // sieht aus wie ein Eingabefeld, in das man etwas eintragen müsste.
    readonly property real wantedWidth: chain.width + Noctis.u(40)

    function segments() {
        if (special) return []
        var home = app ? app.home : ""
        var res = []
        if (home !== "" && (path === home || path.indexOf(home + "/") === 0)) {
            res.push({ label: "Persönlich", path: home, icon: K.UI.home })
            var restStr = path.substring(home.length)
            var parts = restStr.split("/").filter(function (x) { return x !== "" })
            var acc = home
            for (var i = 0; i < parts.length; i++) {
                acc += "/" + parts[i]
                res.push({ label: parts[i], path: acc, icon: "" })
            }
            return res
        }
        res.push({ label: "Dateisystem", path: "/", icon: K.UI.disk })
        var ps = path.split("/").filter(function (x) { return x !== "" })
        var a = ""
        for (var j = 0; j < ps.length; j++) {
            a += "/" + ps[j]
            res.push({ label: ps[j], path: a, icon: "" })
        }
        return res
    }

    function beginEdit() {
        field.text = path
        editing = true
        field.forceActiveFocus()
        field.selectAll()
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Noctis.well
        border.width: field.activeFocus ? 1 : 0
        border.color: Noctis.accentEdge
    }

    // ---------------- Lesen ----------------
    Flickable {
        id: flick
        visible: !root.editing
        anchors.fill: parent
        anchors.leftMargin: Noctis.u(6)
        anchors.rightMargin: Noctis.u(6)
        contentWidth: chain.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        // Immer das Ende zeigen: der Ordner, in dem man steht, ist das
        // Wichtigste an einem Pfad.
        onContentWidthChanged: contentX = Math.max(0, contentWidth - width)

        Row {
            id: chain
            height: flick.height
            spacing: 0

            // Papierkorb und Suche haben keinen Pfad, sondern einen Namen.
            Item {
                visible: root.special
                width: visible ? specialRow.implicitWidth + Noctis.u(20) : 0
                height: parent.height
                Row {
                    id: specialRow
                    anchors.centerIn: parent
                    spacing: Noctis.u(7)
                    LIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: K.UI.trash
                        size: Noctis.u(13)
                        color: Noctis.ink2
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Papierkorb"
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tBody
                        font.weight: Noctis.wTitle
                        color: Noctis.ink
                    }
                }
            }

            Repeater {
                model: root.segments()

                delegate: Row {
                    id: crumb
                    required property var modelData
                    required property int index
                    height: chain.height

                    readonly property bool last: index === root.segments().length - 1

                    LIcon {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: K.UI.fwd
                        size: Noctis.u(11)
                        color: Noctis.ink4
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: seg.implicitWidth + Noctis.u(16)
                        height: Noctis.u(28)

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: crumbDrop.containsDrag
                                   ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.18 : 0.26)
                                   : crumbTouch.containsMouse ? Noctis.fill2 : "transparent"
                            Behavior on color { ColorAnimation { duration: Noctis.mFast } }
                        }

                        Row {
                            id: seg
                            anchors.centerIn: parent
                            spacing: Noctis.u(6)
                            LIcon {
                                visible: modelData.icon !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                size: Noctis.u(12)
                                color: crumb.last ? Noctis.ink : Noctis.ink3
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font.family: Noctis.fontUi
                                font.pixelSize: Noctis.tBody
                                font.weight: crumb.last ? Noctis.wTitle : Noctis.wMed
                                color: crumb.last ? Noctis.ink : Noctis.ink2
                            }
                        }

                        MouseArea {
                            id: crumbTouch
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton)
                                    root.app.openInNewTab(modelData.path)
                                else
                                    root.app.go(modelData.path)
                            }
                        }

                        DropArea {
                            id: crumbDrop
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: d => root.app.dropOnto(modelData.path, d)
                        }
                    }
                }
            }
        }
    }

    // Die freie Fläche rechts neben der Kette gehört dem Tippen: ein Klick
    // dorthin macht aus dem Pfad ein Eingabefeld. Das ist die Stelle, an der
    // jeder hinklickt, der eine Adresse eingeben will.
    MouseArea {
        visible: !root.editing
        anchors.left: flick.left
        anchors.right: flick.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.min(flick.width, chain.width - flick.contentX)
        cursorShape: Qt.IBeamCursor
        onClicked: root.beginEdit()
    }

    // ---------------- Schreiben ----------------
    TextInput {
        id: field
        visible: root.editing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Noctis.u(18)
        anchors.rightMargin: Noctis.u(18)
        anchors.verticalCenter: parent.verticalCenter
        font.family: Noctis.fontMono
        font.pixelSize: Noctis.tBody
        color: Noctis.ink
        selectionColor: Noctis.alpha(Noctis.accent, 0.35)
        selectedTextColor: Noctis.ink
        clip: true

        onAccepted: {
            root.editing = false
            root.app.goTyped(text)
        }
        Keys.onEscapePressed: { root.editing = false; root.app.takeFocus() }
        onActiveFocusChanged: if (!activeFocus) root.editing = false
    }
}
