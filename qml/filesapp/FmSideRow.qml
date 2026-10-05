// ============================================================================
//  FmSideRow — eine Zeile der Seitenleiste.
//
//  Drei Zustände, die man auseinanderhalten muss: hier bin ich gerade (Akzent
//  plus Balken links), hier könnte ich hin (Überfahren), hier landet das, was
//  ich in der Hand habe (Akzentfläche mit Rand). Der dritte ist der
//  wichtigste — wer Dateien zieht, sieht die Leiste nur aus dem Augenwinkel.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root

    property var app: null
    property string label: ""
    property string path: ""
    property string icon: ""
    property color tone: Noctis.accent
    property string trailing: ""
    property bool favorite: false
    property bool acceptsDrop: true
    property var device: null

    readonly property bool here: app && app.path === path && path !== ""
    readonly property bool mountable: device !== null && !device.mounted
    readonly property bool dropping: drop.containsDrag && acceptsDrop && !mountable

    width: parent ? parent.width : 0
    height: Noctis.u(34)

    Rectangle {
        anchors.fill: parent
        radius: Noctis.rTile
        color: root.dropping ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.18 : 0.26)
             : root.here ? Noctis.alpha(Noctis.accent, Noctis.light ? 0.12 : 0.18)
             : touch.containsMouse ? Noctis.fill1 : "transparent"
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
        border.width: root.dropping ? 1 : 0
        border.color: Noctis.accentEdge
    }

    Rectangle {
        visible: root.here
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Noctis.u(3)
        height: parent.height * 0.44
        radius: width / 2
        color: Noctis.accent
    }

    LIcon {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Noctis.u(12)
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: Noctis.u(14)
        color: root.here ? Noctis.accent : root.tone
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
    }

    Text {
        anchors.left: glyph.right
        anchors.leftMargin: Noctis.u(10)
        anchors.right: tail.left
        anchors.rightMargin: Noctis.sp2
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideMiddle
        font.family: Noctis.fontUi
        font.pixelSize: Noctis.tBody
        font.weight: root.here ? Noctis.wTitle : Noctis.wMed
        color: root.here ? Noctis.ink : Noctis.ink2
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
    }

    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Noctis.u(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Noctis.u(4)

        // Anzahl im Papierkorb — eine Zahl, kein Wort.
        Rectangle {
            visible: root.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Noctis.u(18), badge.implicitWidth + Noctis.u(9))
            height: Noctis.u(18)
            radius: height / 2
            color: Noctis.fill2
            Text {
                id: badge
                anchors.centerIn: parent
                text: root.trailing
                font.family: Noctis.fontNum
                font.features: Noctis.tabular
                font.pixelSize: Noctis.tMicro
                font.weight: Noctis.wMed
                color: Noctis.ink3
            }
        }

        // Auswerfen. Nur sichtbar, wenn man mit der Maus darauf ist —
        // ein Knopf, der immer da steht, wird irgendwann aus Versehen
        // getroffen, und dann ist der Stick weg, während noch kopiert wird.
        Item {
            visible: root.device !== null && root.device.mounted && touch.containsMouse
            anchors.verticalCenter: parent.verticalCenter
            width: Noctis.u(20)
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ejectTouch.containsMouse ? Noctis.fill3 : "transparent"
                LIcon {
                    anchors.centerIn: parent
                    text: K.UI.eject
                    size: Noctis.u(11)
                    color: Noctis.ink2
                }
            }
            MouseArea {
                id: ejectTouch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.app.unmount(root.device)
            }
        }

        // Ein Gerät, das noch nicht eingehängt ist, sagt das mit einem Punkt.
        Rectangle {
            visible: root.mountable
            anchors.verticalCenter: parent.verticalCenter
            width: Noctis.u(6)
            height: width
            radius: width / 2
            color: Noctis.ink4
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                var p = root.mapToItem(null, mouse.x, mouse.y)
                root.app.menuForPlace(root.path, root.favorite, root.device, p.x, p.y)
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.path !== "") root.app.openInNewTab(root.path)
            } else if (root.mountable) {
                root.app.mount(root.device)
            } else if (root.path !== "") {
                root.app.go(root.path)
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.acceptsDrop && root.path !== "" && !root.mountable
        keys: ["text/uri-list"]
        onDropped: d => {
            if (root.path === "trash://") root.app.trashDropped(d)
            else root.app.dropOnto(root.path, d)
        }
    }
}
