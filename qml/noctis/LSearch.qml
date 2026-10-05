// ============================================================================
//  LSearch — das Suchfeld.
//
//  Es liegt TIEFER als seine Karte (Noctis.well), nicht höher. Ein Eingabefeld
//  ist eine Mulde, in die man etwas hineinschreibt — das ist der einzige
//  Ort in dieser Sprache, an dem etwas nach hinten tritt.
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    property string placeholder: "Suchen"
    property alias  text: field.text
    property alias  input: field
    // Für Passwortfelder: LSearch { echoMode: TextInput.Password }
    property alias  echoMode: field.echoMode
    property real   boxHeight: Noctis.u(46)
    property string icon: "󰍉"
    property bool   clearable: true

    signal accepted(string text)
    signal edited(string text)

    implicitHeight: boxHeight
    implicitWidth: Noctis.u(320)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Noctis.well
        border.width: field.activeFocus ? 1 : 0
        border.color: Noctis.accentEdge

        LIcon {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: root.boxHeight * 0.42
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: root.boxHeight * 0.38
            color: field.activeFocus ? Noctis.accent : Noctis.ink3
            Behavior on color { ColorAnimation { duration: Noctis.mFast } }
        }

        TextInput {
            id: field
            anchors.left: glyph.right
            anchors.leftMargin: root.boxHeight * 0.30
            anchors.right: clearBtn.left
            anchors.rightMargin: Noctis.sp2
            anchors.verticalCenter: parent.verticalCenter
            font.family: Noctis.fontUi
            font.pixelSize: root.boxHeight * 0.34
            color: Noctis.ink
            selectionColor: Noctis.alpha(Noctis.accent, 0.35)
            selectedTextColor: Noctis.ink
            clip: true
            onAccepted: root.accepted(text)
            onTextEdited: root.edited(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text.length === 0
                text: root.placeholder
                font: field.font
                color: Noctis.ink4
            }
        }

        Item {
            id: clearBtn
            width: visible ? root.boxHeight * 0.7 : 0
            height: width
            anchors.right: parent.right
            anchors.rightMargin: root.boxHeight * 0.24
            anchors.verticalCenter: parent.verticalCenter
            visible: root.clearable && field.text.length > 0

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: clearTouch.containsMouse ? Noctis.fill2 : "transparent"
                LIcon {
                    anchors.centerIn: parent
                    text: "󰅖"
                    size: parent.width * 0.46
                    color: Noctis.ink3
                }
            }
            MouseArea {
                id: clearTouch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { field.text = ""; root.edited("") }
            }
        }
    }
}
