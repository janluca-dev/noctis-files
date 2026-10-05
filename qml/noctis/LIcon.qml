// ============================================================================
//  LIcon — ein Symbol aus der Nerd-Font.
//
//  Eigene Komponente, weil sonst in jedem Modul font.family und die
//  Ausrichtung neu geschrieben würden — und genau dort schleichen sich die
//  Abweichungen ein, die ein System uneinheitlich aussehen lassen.
// ============================================================================

import QtQuick
import "../"

Text {
    property real size: Noctis.tH3
    text: ""
    font.family: Noctis.fontIcon
    font.pixelSize: size
    color: Noctis.ink2
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
