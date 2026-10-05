// ============================================================================
//  LToolButton — der kleine runde Knopf einer Werkzeugleiste.
//
//  Er stand als FmIconButton in Noctis Files und war dort der Grund, warum
//  dessen Kopfzeile aufgeräumt aussieht: acht Knöpfe nebeneinander, keiner
//  davon beschriftet, und trotzdem findet man sie — der Name kommt nach
//  einem halben Augenblick als Fähnchen.
//
//  Im übrigen System stand an derselben Stelle jedes Mal ein handgebautes
//  Rectangle mit MouseArea: im Kopf des QuickDashboards, in QuickHead, in
//  der Mitteilungskarte, in LHeader. Alle vier hatten leicht verschiedene
//  Durchmesser, verschiedene Überfahr-Töne und keiner einen Hinweis. Genau
//  daran sieht man ein System, das aus Teilen besteht.
//
//  Unterschied zu LCircleButton: der trägt seine Beschriftung UNTER sich und
//  ist 52 Punkte groß — gedacht für vier Knöpfe auf einer Profilkarte, nicht
//  für acht in einer Zeile.
//
//  Das Fähnchen kommt verzögert und geht sofort. Andersherum — sofort da,
//  langsam weg — klebt es am Zeiger und verdeckt den nächsten Knopf.
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    property string icon: ""
    property string hint: ""
    property bool   active: false
    property color  tone: Noctis.accent
    property real   boxSize: Noctis.u(32)
    property bool   danger: false
    // Rot erst beim Überfahren. Für das Schließen und das Wegwischen: der
    // Knopf soll nicht schon im Ruhezustand nach Gefahr aussehen, sonst
    // liest man die halbe Werkzeugleiste als Warnung.
    property bool   dangerOnHover: false
    // Ein Knopf, der auch im Ruhezustand eine Fläche hat. Gebraucht auf
    // Glas ohne Karte darunter, wo ein unsichtbarer Knopf keinen Ort hat.
    property bool   resting: false
    // Wohin das Fähnchen aufgeht. Unten ist die Regel; oben braucht es, wer
    // am unteren Fensterrand sitzt.
    property bool   hintAbove: false

    signal clicked(real mx, real my)

    implicitWidth: boxSize
    implicitHeight: boxSize
    opacity: enabled ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.active ? Noctis.alpha(root.tone, Noctis.light ? 0.14 : 0.22)
             : touch.pressed ? Noctis.press
             : touch.containsMouse ? Noctis.fill2
             : root.resting ? Noctis.fill1 : "transparent"
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }

        LIcon {
            anchors.centerIn: parent
            text: root.icon
            size: root.boxSize * 0.46
            color: root.danger ? Noctis.danger
                 : (root.dangerOnHover && touch.containsMouse) ? Noctis.danger
                 : root.active ? root.tone
                 : touch.containsMouse ? Noctis.ink : Noctis.ink2
            Behavior on color { ColorAnimation { duration: Noctis.mFast } }
        }
    }

    scale: touch.pressed ? 0.92 : 1.0
    Behavior on scale { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse.x, mouse.y)
    }

    Timer {
        id: linger
        interval: 550
        running: touch.containsMouse && root.hint !== "" && root.enabled
        onTriggered: tip.shown = true
    }
    Connections {
        target: touch
        function onContainsMouseChanged() { if (!touch.containsMouse) tip.shown = false }
    }

    Rectangle {
        id: tip
        property bool shown: false
        z: 400
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: root.hintAbove ? undefined : parent.bottom
        anchors.bottom: root.hintAbove ? parent.top : undefined
        anchors.topMargin: Noctis.u(4)
        anchors.bottomMargin: Noctis.u(4)
        width: tipText.implicitWidth + Noctis.u(16)
        height: Noctis.u(24)
        radius: height / 2
        color: Noctis.popover
        border.width: 1
        border.color: Noctis.hairlineUp
        visible: opacity > 0.01
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mFast } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.hint
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tLabel
            color: Noctis.ink2
        }
    }
}
