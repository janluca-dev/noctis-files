// ============================================================================
//  LSideHead — die Überschrift einer Gruppe in einer Seitenleiste.
//
//  Aus Noctis Files (FmSideHead) ins System übernommen. Sie ist der Grund,
//  warum die Leiste des Dateimanagers mit fünfzehn Einträgen übersichtlicher
//  ist als eine Einstellungsliste mit dreizehn: eine Gruppe, die eine
//  Überschrift hat, muss man nur einmal lesen — danach springt man in die
//  richtige und überfliegt nur noch vier Zeilen statt dreizehn.
//
//  Kein Strich, keine Fläche, nur Schrift und Luft darüber. Ein Trennstrich
//  wäre ein rechter Winkel in einer Sprache, die keine hat (Regel 4).
//
//  ink3 und nicht ink4: ink4 ist die Stufe für Zierde. Eine
//  Gruppenüberschrift ist keine Zierde — im Hellmodus verschwindet sie auf
//  ink4 fast vollständig.
// ============================================================================

import QtQuick
import "../"

Item {
    property alias text: t.text
    // Die erste Überschrift einer Leiste braucht keinen Vorlauf, die
    // folgenden schon: sie trennen ja etwas ab.
    property bool first: false
    property real indent: Noctis.u(12)

    width: parent ? parent.width : 0
    height: visible ? (first ? Noctis.u(20) : Noctis.u(30)) : 0

    Text {
        id: t
        anchors.left: parent.left
        anchors.leftMargin: parent.indent
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Noctis.u(4)
        font.family: Noctis.fontUi
        font.pixelSize: Noctis.tMicro
        font.weight: Noctis.wMed
        font.letterSpacing: Noctis.lsMicro
        font.capitalization: Font.AllUppercase
        color: Noctis.ink3
    }
}
