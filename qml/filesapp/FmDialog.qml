// ============================================================================
//  FmDialog — die Frage in der Mitte.
//
//  LSheet gibt es schon, aber das ist ein Blatt, das von unten hereinfährt
//  und zwei Drittel der Höhe nimmt. Für „Wie soll die Datei heißen?" ist das
//  zu viel Bewegung für zu wenig Frage. Hier steht eine kleine Karte in der
//  Mitte, der Grund dunkelt ab, und die Karte kommt aus sich heraus
//  (Maßstab 0.94 → 1) statt von irgendwoher — sie gehört zu nichts auf dem
//  Schirm, sie IST für einen Moment der Schirm.
//
//  Drei Bauarten, eine Datei:
//    input    ein Feld (umbenennen, neuer Ordner)
//    confirm  eine Warnung mit zwei Wegen (endgültig löschen)
//    choice   mehrere Wege (Ersetzen · Beides behalten · Überspringen)
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root

    property bool open: false
    property string mode: "input"           // input | confirm | choice
    property string title: ""
    property string subtitle: ""
    property string placeholder: ""
    property string okText: "Übernehmen"
    property string cancelText: "Abbrechen"
    property bool   danger: false
    property string icon: ""
    property var    choices: []             // [{ key, label, variant, warn }]
    property alias  text: field.text
    // Beim Umbenennen nur den Namen ohne Endung markieren: wer „urlaub.jpg"
    // umbenennt, will fast nie das „.jpg" mittippen.
    property int    selectTo: -1

    signal accepted(string value)
    signal chose(string key)
    signal cancelled()

    anchors.fill: parent
    visible: open || fade.running
    z: 800

    function show() {
        open = true
        if (mode === "input") {
            field.forceActiveFocus()
            if (selectTo > 0) field.select(0, selectTo)
            else field.selectAll()
        }
    }
    function close() { open = false; root.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Noctis.light ? 0.20 : 0.46)
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Noctis.mFast } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: { root.close(); root.cancelled() }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - Noctis.sp8, Noctis.u(420))
        height: col.implicitHeight + Noctis.padCard * 2
        radius: Noctis.rCard
        color: Noctis.card

        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }
        scale: root.open ? 1 : 0.94
        Behavior on scale {
            NumberAnimation { duration: Noctis.mBase; easing.type: Noctis.easeOut }
        }

        // Klicks hier sollen NICHT den Fänger dahinter erreichen.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Column {
            id: col
            anchors.centerIn: parent
            width: parent.width - Noctis.padCard * 2
            spacing: Noctis.sp4

            Row {
                width: parent.width
                spacing: Noctis.sp3

                Rectangle {
                    visible: root.icon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Noctis.u(42)
                    height: width
                    radius: Noctis.rTile
                    color: Noctis.alpha(root.danger ? Noctis.danger : Noctis.accent,
                                       Noctis.light ? 0.12 : 0.20)
                    LIcon {
                        anchors.centerIn: parent
                        text: root.icon
                        size: parent.width * 0.46
                        color: root.danger ? Noctis.danger : Noctis.accent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (root.icon !== "" ? Noctis.u(42) + Noctis.sp3 : 0)
                    spacing: Noctis.u(2)

                    Text {
                        width: parent.width
                        text: root.title
                        wrapMode: Text.WordWrap
                        font.family: Noctis.fontDisplay
                        font.pixelSize: Noctis.tH3
                        font.weight: Noctis.wTitle
                        font.letterSpacing: Noctis.lsTitle
                        color: Noctis.ink
                    }
                    Text {
                        width: parent.width
                        visible: root.subtitle !== ""
                        text: root.subtitle
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tLabel
                        color: Noctis.ink3
                        lineHeight: 1.3
                    }
                }
            }

            // ---- Feld ----
            Rectangle {
                visible: root.mode === "input"
                width: parent.width
                height: Noctis.u(44)
                radius: height / 2
                color: Noctis.well
                border.width: field.activeFocus ? 1 : 0
                border.color: Noctis.accentEdge

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: Noctis.u(18)
                    anchors.rightMargin: Noctis.u(18)
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tBodyL
                    color: Noctis.ink
                    selectionColor: Noctis.alpha(Noctis.accent, 0.35)
                    selectedTextColor: Noctis.ink
                    clip: true
                    onAccepted: if (text.trim() !== "") { root.close(); root.accepted(text.trim()) }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text.length === 0
                        text: root.placeholder
                        font: field.font
                        color: Noctis.ink4
                    }
                }
            }

            // ---- Wege ----
            Column {
                visible: root.mode === "choice"
                width: parent.width
                spacing: Noctis.sp2

                Repeater {
                    model: root.choices
                    delegate: LButton {
                        required property var modelData
                        width: col.width
                        wide: true
                        text: modelData.label
                        variant: modelData.variant ? modelData.variant : "quiet"
                        tone: modelData.warn === true ? Noctis.danger : Noctis.accent
                        boxHeight: Noctis.u(40)
                        onClicked: { root.close(); root.chose(modelData.key) }
                    }
                }
            }

            // ---- Knöpfe ----
            Row {
                visible: root.mode !== "choice"
                anchors.right: parent.right
                spacing: Noctis.sp2

                LButton {
                    text: root.cancelText
                    variant: "ghost"
                    boxHeight: Noctis.u(38)
                    onClicked: { root.close(); root.cancelled() }
                }
                LButton {
                    text: root.okText
                    variant: "filled"
                    tone: root.danger ? Noctis.danger : Noctis.accent
                    boxHeight: Noctis.u(38)
                    enabled: root.mode !== "input" || field.text.trim() !== ""
                    onClicked: {
                        root.close()
                        if (root.mode === "input") root.accepted(field.text.trim())
                        else root.accepted("")
                    }
                }
            }

            LButton {
                visible: root.mode === "choice"
                anchors.right: parent.right
                text: root.cancelText
                variant: "ghost"
                boxHeight: Noctis.u(38)
                onClicked: { root.close(); root.cancelled() }
            }
        }
    }

    Keys.onEscapePressed: { close(); cancelled() }
}
