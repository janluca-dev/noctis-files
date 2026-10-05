// ============================================================================
//  FmDetailRow — Etikett links, Wert rechts.
//
//  Der Größenkontrast aus Regel 2 im Kleinen: das Etikett winzig und grau,
//  der Wert normal und dunkel. Beide gleich groß zu setzen wäre eine
//  Tabelle — und eine Tabelle liest man Zeile für Zeile, statt den Blick
//  fallen zu lassen.
// ============================================================================

import QtQuick
import "../noctis"
import "../"

Item {
    id: root
    property string label: ""
    property string value: ""
    property bool mono: false

    width: parent ? parent.width : 0
    height: visible && value !== "" ? Math.max(Noctis.u(26), val.implicitHeight + Noctis.u(8)) : 0
    visible: value !== ""

    Text {
        id: lab
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Noctis.u(5)
        width: Noctis.u(104)
        text: root.label
        elide: Text.ElideRight
        font.family: Noctis.fontUi
        font.pixelSize: Noctis.tMicro
        font.weight: Noctis.wMed
        font.letterSpacing: Noctis.lsMicro
        font.capitalization: Font.AllUppercase
        color: Noctis.ink4
    }

    Text {
        id: val
        anchors.left: lab.right
        anchors.leftMargin: Noctis.sp2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Noctis.u(2)
        text: root.value
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: 3
        elide: Text.ElideRight
        font.family: root.mono ? Noctis.fontMono : Noctis.fontUi
        font.pixelSize: root.mono ? Noctis.u(11) : Noctis.tBody
        color: Noctis.ink
    }
}
