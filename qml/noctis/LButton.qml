// ============================================================================
//  LButton — die Pille.
//
//  Vier Stufen von „das ist DIE Aktion" bis „das ist nur auch noch da":
//
//    filled   gefüllt mit dem Akzent. Genau EINE pro Fläche. In den
//             Vorlagen ist das der blaue „Upload"-Knopf neben dem hellen
//             „Cancel" — der Kontrast macht die Entscheidung für den
//             Benutzer, nicht der Text.
//    tonal    Akzent als Tönung. Für die zweitwichtigste Sache.
//    quiet    neutral gefüllt. Der Normalfall.
//    ghost    nur Schrift. Für Abbrechen, Zurück, Mehr.
//
//  Die Höhe ist fest und die Ecken sind halbrund — eine Pille mit Radius 8
//  wäre ein Knopf, und Knöpfe kennt diese Sprache nicht.
// ============================================================================

import QtQuick
import "../"

Item {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "quiet"     // filled | tonal | quiet | ghost
    property color  tone: Noctis.accent
    property real   boxHeight: Noctis.u(42)
    property bool   wide: false          // füllt die Breite des Elternteils
    property bool   compact: false
    property alias  hovered: touch.containsMouse

    signal clicked()

    readonly property bool filled: variant === "filled"

    readonly property color bg: !enabled ? Noctis.fill1
                              : filled ? (touch.pressed ? Noctis.down(tone, 0.12)
                                          : touch.containsMouse ? Noctis.accentHover : tone)
                              : variant === "tonal" ? Noctis.alpha(tone, touch.containsMouse ? (Noctis.light ? 0.16 : 0.24)
                                                                                            : (Noctis.light ? 0.10 : 0.16))
                              : variant === "quiet" ? (touch.pressed ? Noctis.press
                                                       : touch.containsMouse ? Noctis.fill2 : Noctis.fill1)
                              : (touch.containsMouse ? Noctis.fill1 : "transparent")

    readonly property color fg: !enabled ? Noctis.ink4
                              : filled ? Noctis.onColor(tone)
                              : variant === "tonal" ? tone
                              : Noctis.ink

    implicitWidth: wide ? 0 : (row.implicitWidth + boxHeight * (compact ? 0.7 : 1.0))
    implicitHeight: boxHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.bg
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: root.text !== "" && root.icon !== "" ? Noctis.sp2 : 0

            LIcon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                size: root.boxHeight * 0.40
                color: root.fg
            }
            Text {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: Noctis.fontUi
                font.pixelSize: root.boxHeight * 0.355
                font.weight: Noctis.wMed
                color: root.fg
                Behavior on color { ColorAnimation { duration: Noctis.mFast } }
            }
        }
    }

    scale: touch.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: Noctis.mFast; easing.type: Noctis.easeSoft } }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
