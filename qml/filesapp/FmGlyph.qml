// ============================================================================
//  FmGlyph — ein Symbol, das WIRKLICH in der Mitte steht.
//
//  LIcon setzt ein Zeichen aus der Nerd-Font und tut das überall im System
//  richtig — bei 12 bis 20 Punkten. Hier werden dieselben Zeichen 70 Punkte
//  groß, und dabei fällt etwas auf, das vorher niemand sehen konnte:
//
//    Iosevka meldet für ein Symbol eine LAUFWEITE von einer Zelle (32 bei
//    64 px), zeichnet aber 54 Punkte breit. Qt zentriert die Zeile nach der
//    Laufweite; was darüber hinaussteht, hängt rechts heraus. Das Symbol
//    steht dadurch um (Breite − Laufweite) / 2 zu weit rechts — gemessen
//    12 Punkte bei einem 70 Punkte großen Ordner. Neben einer zentrierten
//    Beschriftung sieht man das sofort, und man sieht auch nicht, WARUM es
//    schief aussieht. Genau solche Abweichungen machen eine Oberfläche
//    unruhig, ohne dass man den Finger darauf legen kann.
//
//  TextMetrics kennt beide Maße. Die Verschiebung ist damit kein geratener
//  Korrekturwert, sondern eine Rechnung, die für jedes Zeichen und jede
//  Schrift stimmt:
//
//      Versatz = Laufweite / 2 − (Tintenkasten-Mitte)
//
//  Senkrecht stimmt es bereits: dort misst Qt mit der Oberlänge, und die
//  Symbole sind in ihrer Zeile mittig geschnitten (nachgerechnet: 0,25
//  Punkte Abweichung bei 64 px).
// ============================================================================

import QtQuick
import "../noctis"
import "../"

Item {
    id: root

    property string text: ""
    property real size: Noctis.tH3
    property color color: Noctis.ink2

    implicitWidth: size
    implicitHeight: size

    TextMetrics {
        id: fm
        font.family: Noctis.fontIcon
        font.pixelSize: root.size
        text: root.text
    }

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset:
            Math.round(fm.advanceWidth / 2
                       - (fm.tightBoundingRect.x + fm.tightBoundingRect.width / 2))
        text: root.text
        font.family: Noctis.fontIcon
        font.pixelSize: root.size
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
