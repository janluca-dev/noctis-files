// ============================================================================
//  LScroll — Rollbereich mit schmaler Leiste und weichen Kanten.
//
//  Zwei Dinge, die eine gerollte Liste in dieser Sprache braucht:
//
//    Die Leiste ist eine dünne Pille, die nur beim Rollen und beim
//    Überfahren sichtbar wird. Eine dauerhaft sichtbare Rollleiste ist ein
//    Streifen Grau an der Kante jeder Fläche.
//
//    Oben und unten blendet der Inhalt aus. Ohne das schneidet eine Liste
//    am Kartenrand hart ab und die Karte wirkt wie ein Fenster mit Rahmen.
//
//  --- WIE DAS AUSBLENDEN GEMACHT WIRD (§83) ---------------------------------
//  Früher lagen an Ober- und Unterkante zwei Rechtecke mit einem Verlauf von
//  `fadeColor` nach durchsichtig. Das stimmt nur, solange der Untergrund
//  GENAU diese Farbe hat — also auf einer deckenden Karte. Auf der Scheibe
//  eines Fensters ist der Untergrund Milchglas, und ein deckendes Rechteck
//  darüber ist dann als hellerer Streifen zu sehen: der „weiße Rest" an der
//  Kante. Schlimmer noch: jeder Aufrufer musste die richtige Farbe kennen
//  und von Hand mitgeben, und genau das geht irgendwann schief.
//
//  Jetzt wird nicht übermalt, sondern MASKIERT: der Inhalt selbst verliert
//  an der Kante seine Deckkraft. Das ist unabhängig davon, was dahinter
//  liegt, und der Aufrufer muss gar nichts mehr wissen.
// ============================================================================

import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: root

    property alias flick: flick
    property alias contentHeight: flick.contentHeight
    property bool  fadeEdges: true
    property real  fadeSize: Noctis.u(22)

    // Wird nicht mehr gebraucht (siehe Kopf), bleibt aber als Eigenschaft
    // bestehen: bestehende Aufrufer setzen sie, und eine unbekannte
    // Eigenschaft ist in QML ein Fehler, kein Achselzucken.
    property color fadeColor: "transparent"

    default property alias content: holder.data

    clip: true

    readonly property bool scrollable: flick.contentHeight > flick.height + 4
    readonly property bool fadeTop: fadeEdges && flick.contentY > 2
    readonly property bool fadeBottom: fadeEdges
                                       && (flick.contentHeight - flick.contentY - flick.height) > 2

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: holder.childrenRect.height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3500
        maximumFlickVelocity: 3800

        Item {
            id: holder
            width: flick.width
            height: childrenRect.height
        }
    }

    Rectangle {
        id: bar
        visible: root.scrollable
        width: Noctis.u(4)
        radius: width / 2
        anchors.right: parent.right
        anchors.rightMargin: Noctis.u(2)
        color: Noctis.alpha(Noctis.inkBase, Noctis.light ? 0.22 : 0.28)

        y: flick.contentHeight > 0
           ? (flick.contentY / flick.contentHeight) * flick.height : 0
        height: flick.contentHeight > 0
                ? Math.max(Noctis.u(28), (flick.height / flick.contentHeight) * flick.height) : 0

        opacity: flick.moving || hoverArea.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mBase } }
    }

    MouseArea {
        id: hoverArea
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Noctis.u(18)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ------------------------------------------------------------------
    //  Die Maske
    //
    //  Nur einschalten, wenn überhaupt gerollt werden kann. Der Schalter
    //  hängt bewusst NICHT an der Rollposition — sonst würde die
    //  Zwischenebene beim Anrollen an- und abgeschaltet, und das sieht man
    //  als Ruck. Die Verlaufsmarken wandern statt dessen weich mit.
    // ------------------------------------------------------------------
    //
    //  [Noctis Files, eigenständig] Umgeschaltet wird einen Durchlauf
    //  später — dieselbe Absicherung wie in FmView.qml: eine Ebene, die
    //  mitten in einer Größenänderung verschwindet, bringt Qt 6.11 zum
    //  Absturz.
    readonly property bool wantLayer: root.fadeEdges && root.scrollable
    property bool layerOn: false
    function syncLayer() { layerOn = wantLayer }
    onWantLayerChanged: Qt.callLater(syncLayer)
    Component.onCompleted: syncLayer()
    layer.enabled: layerOn
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: fadeMask
    }

    Item {
        id: fadeMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real stop: root.height > 0
                                     ? Math.min(0.45, root.fadeSize / root.height) : 0.05

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0
                               color: Qt.rgba(1, 1, 1, root.fadeTop ? 0 : 1) }
                GradientStop { position: root.fadeTop ? fadeMask.stop : 0.0001
                               color: "#ffffff" }
                GradientStop { position: root.fadeBottom ? 1 - fadeMask.stop : 0.9999
                               color: "#ffffff" }
                GradientStop { position: 1.0
                               color: Qt.rgba(1, 1, 1, root.fadeBottom ? 0 : 1) }
            }
        }
    }
}
