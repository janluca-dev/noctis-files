// ============================================================================
//  FmTopBar — Reiter und Werkzeugleiste.
//
//  Die Reihenfolge von links nach rechts ist die Reihenfolge der Fragen:
//  Wo war ich (zurück/vor/hoch) · Wo bin ich (der Pfad) · Was suche ich
//  (das Suchfeld) · Wie will ich es sehen (Ansicht, Sortierung).
//
//  Die Reiterzeile erscheint erst ab dem zweiten Reiter. Eine Zeile, die bei
//  einem einzigen Reiter dessen Namen wiederholt — der schon im Pfad
//  darunter steht —, kostet vierzig Punkte Höhe und sagt nichts.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null

    readonly property bool manyTabs: app && app.tabs.length > 1
    implicitHeight: (manyTabs ? Noctis.u(36) : 0) + Noctis.u(54)

    // ---------------- Reiter ----------------
    Item {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Noctis.u(12)
        anchors.rightMargin: Noctis.u(12)
        height: root.manyTabs ? Noctis.u(36) : 0
        visible: root.manyTabs
        clip: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            spacing: Noctis.u(4)

            Repeater {
                model: root.app ? root.app.tabs : []

                delegate: Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool here: root.app.tabIndex === index

                    width: Math.min(Noctis.u(210), label.implicitWidth + Noctis.u(62))
                    height: Noctis.u(28)

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: tab.here ? Noctis.card
                             : tabTouch.containsMouse ? Noctis.fill2 : Noctis.fill1
                        Behavior on color { ColorAnimation { duration: Noctis.mFast } }
                    }

                    LIcon {
                        id: tabIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Noctis.u(11)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.path === "trash://" ? K.UI.trash : K.UI.folder
                        size: Noctis.u(11)
                        color: tab.here ? Noctis.accent : Noctis.ink3
                    }

                    Text {
                        id: label
                        anchors.left: tabIcon.right
                        anchors.leftMargin: Noctis.u(7)
                        anchors.right: closeBtn.left
                        anchors.rightMargin: Noctis.u(3)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.app.tabLabel(modelData.path)
                        elide: Text.ElideMiddle
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tLabel
                        font.weight: tab.here ? Noctis.wTitle : Noctis.wMed
                        color: tab.here ? Noctis.ink : Noctis.ink2
                    }

                    Item {
                        id: closeBtn
                        anchors.right: parent.right
                        anchors.rightMargin: Noctis.u(5)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Noctis.u(18)
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: closeTouch.containsMouse ? Noctis.fill3 : "transparent"
                            LIcon {
                                anchors.centerIn: parent
                                text: K.UI.close
                                size: Noctis.u(9)
                                color: Noctis.ink3
                            }
                        }
                        MouseArea {
                            id: closeTouch
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.app.closeTab(tab.index)
                        }
                    }

                    MouseArea {
                        id: tabTouch
                        anchors.fill: parent
                        anchors.rightMargin: Noctis.u(22)
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) root.app.closeTab(tab.index)
                            else root.app.selectTab(tab.index)
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onEntered: root.app.selectTab(tab.index)
                    }
                }
            }

            FmIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: K.UI.plus
                hint: "Neuer Reiter"
                boxSize: Noctis.u(26)
                onClicked: root.app.openInNewTab(root.app.path)
            }
        }
    }

    // ---------------- Werkzeuge ----------------
    Item {
        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Noctis.u(12)
        anchors.rightMargin: Noctis.u(12)

        Row {
            id: nav
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Noctis.u(1)

            FmIconButton {
                icon: K.UI.back
                hint: "Zurück"
                enabled: root.app && root.app.canBack
                onClicked: root.app.back()
            }
            FmIconButton {
                icon: K.UI.fwd
                hint: "Vor"
                enabled: root.app && root.app.canForward
                onClicked: root.app.forward()
            }
            FmIconButton {
                icon: K.UI.up
                hint: "Eine Ebene höher"
                enabled: root.app && root.app.canUp
                onClicked: root.app.up()
            }
        }

        FmCrumbs {
            id: crumbs
            app: root.app
            anchors.left: nav.right
            anchors.leftMargin: Noctis.sp3
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Noctis.u(150),
                            Math.min(tools.x - x - Noctis.sp4, crumbs.wantedWidth))
        }

        Row {
            id: tools
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Noctis.u(2)

            LSearch {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                width: Noctis.u(196)
                boxHeight: Noctis.u(34)
                placeholder: "Suchen"
                icon: K.UI.search
                onEdited: t => root.app.setQuery(t)
                Keys.onEscapePressed: { text = ""; root.app.setQuery(""); root.app.takeFocus() }
            }

            Item { width: Noctis.sp2; height: 1 }

            FmIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.app && root.app.gridMode ? K.UI.list : K.UI.grid
                hint: root.app && root.app.gridMode ? "Als Liste" : "Als Raster"
                onClicked: root.app.toggleView()
            }
            FmIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: K.UI.sort
                hint: "Sortieren"
                onClicked: (mx, my) => {
                    var p = mapToItem(null, mx, my)
                    root.app.menuForSort(p.x, p.y)
                }
            }
            FmIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: K.UI.pane
                hint: "Auskunft"
                active: root.app && root.app.detailShown
                onClicked: root.app.toggleDetail()
            }
            FmIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: K.UI.dots
                hint: "Mehr"
                onClicked: (mx, my) => {
                    var p = mapToItem(null, mx, my)
                    root.app.menuForFolder(p.x, p.y)
                }
            }
        }
    }

    // Das Suchfeld von außen füllen können (Strg+F, oder beim Wechsel des
    // Ordners leeren).
    function focusSearch() { search.input.forceActiveFocus(); search.input.selectAll() }
    function clearSearch() { search.text = "" }
    function editPath() { crumbs.beginEdit() }
}
