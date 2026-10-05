// ============================================================================
//  LEmpty — der leere Zustand.
//
//  Die erste Vorlage im Satz und die wichtigste Lehre daraus: ein leeres
//  Fenster ist keine Panne, sondern eine Gelegenheit. Symbol mit Schein,
//  ein Satz, was hier hingehört, ein Satz, wie es dahin kommt — und wenn
//  möglich ein Knopf, der genau das tut.
//
//  Kein „Keine Daten vorhanden."
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    property string icon: "󰋼"
    property string title: ""
    property string subtitle: ""
    property string actionText: ""
    property color  tone: Noctis.accent
    property real   iconSize: Noctis.u(76)

    signal actionClicked()

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Noctis.sp8, Noctis.u(360))
        spacing: Noctis.sp4

        // Der Schein macht aus einem grauen Symbol ein Ziel.
        Item {
            width: root.iconSize
            height: root.iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.45
                height: width
                radius: width / 2
                color: Noctis.alpha(root.tone, Noctis.light ? 0.10 : 0.14)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Noctis.alpha(root.tone, Noctis.light ? 0.16 : 0.22)
                LIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    size: parent.width * 0.44
                    color: root.tone
                }
            }
        }

        Text {
            width: parent.width
            visible: root.title !== ""
            text: root.title
            horizontalAlignment: Text.AlignHCenter
            font.family: Noctis.fontDisplay
            font.pixelSize: Noctis.tH2
            font.weight: Noctis.wDisplay
            font.letterSpacing: Noctis.lsTitle
            color: Noctis.ink
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            horizontalAlignment: Text.AlignHCenter
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tBodyL
            color: Noctis.ink3
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }

        LButton {
            visible: root.actionText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.actionText
            variant: "filled"
            tone: root.tone
            onClicked: root.actionClicked()
        }
    }
}
