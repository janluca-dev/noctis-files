// ============================================================================
//  LMenu — das Kontextmenü (§86).
//
//  Ein Menü ist in dieser Sprache kein eigenes Fenster, sondern eine KARTE,
//  die dort aufgeht, wo geklickt wurde. Es liegt deshalb im selben Rahmen wie
//  alles andere und hält sich an dessen Grenzen: `popup()` schiebt es zurück,
//  sobald es hinausragen würde. Ein Menü, dessen letzter Eintrag hinter der
//  Fensterkante liegt, ist schlimmer als eins, das etwas verrutscht steht.
//
//  Es bringt seinen eigenen Fänger mit — die Fläche unter ihm nimmt den
//  nächsten Klick entgegen und schließt. Das ist die eine Stelle, an der eine
//  unsichtbare Fläche Klicks abfangen darf: solange das Menü steht, gehört
//  der nächste Klick ihm.
//
//  Verwendung:
//
//      LMenu {
//          id: menu
//          items: [ { label: "Starten", icon: "󰐊" },
//                   { label: "Löschen", icon: "󰩹", warn: true } ]
//          onChosen: (i) => { … }
//      }
//      … irgendwo: menu.popup(x, y)
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    // Jeder Eintrag: { label, icon (optional), warn (optional) }
    property var items: []

    readonly property bool open: panel.shown
    signal chosen(int index)

    // Deckt den ganzen Rahmen ab, in dem es sitzt.
    anchors.fill: parent
    visible: panel.shown
    z: 200

    function popup(x, y) {
        panel.wantX = x
        panel.wantY = y
        panel.shown = true
    }
    function close() { panel.shown = false }

    MouseArea {
        anchors.fill: parent
        enabled: panel.shown
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.close()
    }

    Rectangle {
        id: panel

        property bool shown: false
        property real wantX: 0
        property real wantY: 0

        readonly property int pad: Noctis.u(6)
        width: col.implicitWidth + pad * 2
        height: col.implicitHeight + pad * 2

        // In den Rahmen zurückschieben. Nach oben klappen, wenn unten kein
        // Platz mehr ist — dasselbe, was ein Menü am Bildschirmrand tut.
        x: Math.max(Noctis.sp2, Math.min(root.width - width - Noctis.sp2, wantX))
        y: (wantY + height > root.height - Noctis.sp2)
           ? Math.max(Noctis.sp2, wantY - height)
           : wantY

        radius: Noctis.rTile
        color: Noctis.popover
        border.width: 1
        border.color: Noctis.hairlineUp

        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }
        scale: shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }
        transformOrigin: Item.TopLeft

        Column {
            id: col
            x: panel.pad
            y: panel.pad
            spacing: 1

            Repeater {
                model: root.items

                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index

                    implicitWidth: Math.max(Noctis.u(170),
                                            glyph.width + label.implicitWidth + Noctis.u(30))
                    implicitHeight: Noctis.u(32)
                    width: implicitWidth
                    height: implicitHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Noctis.rMini
                        color: touch.containsMouse
                               ? (entry.modelData.warn === true ? Noctis.alpha(Noctis.danger, 0.16)
                                                                : Noctis.fill2)
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }

                    LIcon {
                        id: glyph
                        anchors.left: parent.left
                        anchors.leftMargin: Noctis.u(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Noctis.u(18)
                        text: entry.modelData.icon || ""
                        size: Noctis.u(13)
                        color: entry.modelData.warn === true ? Noctis.danger : Noctis.ink2
                    }
                    Text {
                        id: label
                        anchors.left: glyph.right
                        anchors.leftMargin: Noctis.u(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label || ""
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tBody
                        font.weight: Noctis.wMed
                        color: entry.modelData.warn === true ? Noctis.danger : Noctis.ink
                    }

                    MouseArea {
                        id: touch
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.close(); root.chosen(entry.index) }
                    }
                }
            }
        }
    }
}
