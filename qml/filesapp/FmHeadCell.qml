// ============================================================================
//  FmHeadCell — eine Spaltenüberschrift, die sortiert.
//
//  Klein, grau, gesperrt: dasselbe Etikett wie überall in Noctis (LLabel).
//  Aktiv wird es farbig und bekommt einen Pfeil — mehr Hinweis braucht es
//  nicht, und weniger wäre zu wenig.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null
    property string label: ""
    property string keyName: "name"
    property bool alignRight: false

    readonly property bool active: app && app.sortKey === keyName

    implicitWidth: row.implicitWidth + Noctis.sp3
    implicitHeight: Noctis.u(22)

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Noctis.u(4)
        radius: Noctis.rMini
        color: touch.containsMouse ? Noctis.fill1 : "transparent"
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.alignRight ? parent.right : undefined
        anchors.left: root.alignRight ? undefined : parent.left
        spacing: Noctis.u(3)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tMicro
            font.weight: Noctis.wMed
            font.letterSpacing: Noctis.lsMicro
            font.capitalization: Font.AllUppercase
            color: root.active ? Noctis.accent : Noctis.ink3
            Behavior on color { ColorAnimation { duration: Noctis.mFast } }
        }
        LIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            text: root.app && root.app.sortDesc ? K.UI.down : K.UI.upSmall
            size: Noctis.u(10)
            color: Noctis.accent
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        anchors.margins: -Noctis.u(4)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.app.sortBy(root.keyName)
    }
}
