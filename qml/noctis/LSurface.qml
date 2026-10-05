// ============================================================================
//  LSurface — die Scheibe, auf der ein Fenster liegt.
//
//  Das ist die äußerste Fläche jedes Noctis-Moduls und das einzige Element der
//  Sprache, das Milchglas ist: alles Weitere liegt darauf und ist deckend.
//  Drei Dinge machen sie aus, und alle drei sind nötig —
//
//    Deckkraft   damit der Weichzeichner des Compositors etwas zu tun hat
//    Lichtkante  ein Hauch Weiß innen an der Oberkante. Ohne sie verläuft
//                die Scheibe auf einem hellen Hintergrundbild ins Nichts.
//
//  KEIN SCHLAGSCHATTEN (§83). Hier stand einer, gezeichnet über
//  `layer.effect: MultiEffect`. Das kann nicht funktionieren: ein Layer-
//  Effekt wird auf die Grenzen SEINES Items beschnitten, und eine LSurface
//  füllt ihren Container immer vollständig aus. Der Schatten hatte also
//  nirgends Platz und erschien als hartkantiger grauer Streifen unterhalb
//  der Fläche — am deutlichsten unter den Inseln der Leiste.
//
//  Ein Schatten bräuchte ein größeres Elternteil, in das er hineinragen
//  darf. Den Aufwand ist er nicht wert: die Tiefe entsteht in dieser Sprache
//  ohnehin aus Ton und Lichtkante, und über dem weichgezeichneten
//  Hintergrundbild hebt sich eine Scheibe auch ohne Schatten deutlich ab.
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    property color fill: Noctis.plate
    property int   radiusOverride: -1
    readonly property int r: radiusOverride >= 0 ? radiusOverride : Noctis.rCard
    // Bleibt als Eigenschaft bestehen, damit bestehende Aufrufer nicht
    // brechen — sie tut nur nichts mehr.
    property bool  shadow: false
    property bool  edge: true
    property bool  clipContent: true

    default property alias content: inner.data

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.r
        color: root.fill
        clip: root.clipContent

        // Die Lichtkante sitzt INNEN, einen Pixel vom Rand — außen liegend
        // wäre sie ein Rahmen, und Rahmen kennt diese Sprache nicht.
        Rectangle {
            visible: root.edge
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Noctis.lightEdge
        }

        Item { id: inner; anchors.fill: parent }
    }

}
