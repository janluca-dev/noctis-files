// ============================================================================
//  FmSidebar — die Seitenleiste: Orte, Favoriten, Geräte, Papierkorb.
//
//  Sie ist nach Verlässlichkeit geordnet, nicht nach Häufigkeit: zuerst das,
//  was IMMER da ist (das eigene Verzeichnis und seine Unterordner), dann das,
//  was man selbst abgelegt hat, dann das, was man angesteckt hat und morgen
//  vielleicht nicht mehr. Deshalb wandert auch nichts von unten nach oben,
//  wenn man es oft benutzt — eine Leiste, deren Reihenfolge sich ändert,
//  muss man jedes Mal neu lesen.
//
//  Jede Zeile ist zugleich ein Ziel: zieht man Dateien darauf, landen sie
//  dort. Das ist der kürzeste Weg von „Downloads" nach „Dokumente", den ein
//  Dateimanager anbieten kann.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null

    readonly property var places: app && app.places ? app.places : null

    // ---------------- Kopf: das Zeichen ----------------
    Item {
        id: brand
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Noctis.u(14)
        height: Noctis.u(52)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Noctis.u(6)
            spacing: Noctis.u(9)

            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: "noctis-files.svg"
                sourceSize.width: 96
                sourceSize.height: 96
                width: Noctis.u(30)
                height: width
                fillMode: Image.PreserveAspectFit
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -Noctis.u(3)
                Text {
                    text: "Noctis"
                    font.family: Noctis.fontDisplay
                    font.pixelSize: Noctis.u(18)
                    font.weight: Noctis.wDisplay
                    font.letterSpacing: Noctis.lsTitle
                    color: Noctis.ink
                }
                Text {
                    text: "Files"
                    font.family: Noctis.fontDisplay
                    font.pixelSize: Noctis.u(18)
                    font.weight: Noctis.wDisplay
                    font.letterSpacing: Noctis.lsTitle
                    color: Noctis.accent
                }
            }
        }
    }

    // ---------------- Die Listen ----------------
    LScroll {
        anchors.top: brand.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.leftMargin: Noctis.u(10)
        anchors.rightMargin: Noctis.u(10)
        anchors.bottomMargin: Noctis.sp2

        Column {
            width: parent.width
            spacing: Noctis.u(2)

            FmSideHead { text: "Orte"; first: true }

            Repeater {
                model: root.places ? root.places.dirs : []
                FmSideRow {
                    required property var modelData
                    app: root.app
                    label: modelData.label
                    path: modelData.path
                    icon: K.placeIcon(modelData.icon)
                    tone: K.placeTone(modelData.icon, Noctis.accent)
                }
            }

            FmSideRow {
                app: root.app
                label: "Dateisystem"
                path: "/"
                icon: K.UI.disk
                tone: Noctis.ink3
            }

            FmSideRow {
                app: root.app
                label: "Papierkorb"
                path: "trash://"
                icon: K.UI.trash
                tone: Noctis.ink3
                trailing: root.places && root.places.trash.count > 0
                          ? String(root.places.trash.count) : ""
                acceptsDrop: true
            }

            FmSideHead {
                text: "Favoriten"
                visible: root.places && root.places.favorites.length > 0
            }
            Repeater {
                model: root.places ? root.places.favorites : []
                FmSideRow {
                    required property var modelData
                    app: root.app
                    label: modelData.label
                    path: modelData.path
                    icon: K.UI.star
                    tone: Noctis.warning
                    favorite: true
                }
            }

            FmSideHead {
                text: "Geräte"
                visible: root.places && root.places.devices.length > 0
            }
            Repeater {
                model: root.places ? root.places.devices : []
                FmSideRow {
                    required property var modelData
                    app: root.app
                    label: modelData.label
                    path: modelData.path
                    device: modelData
                    icon: K.UI.disk
                    tone: modelData.mounted ? Noctis.success : Noctis.ink3
                }
            }

            Item { width: 1; height: Noctis.sp4 }
        }
    }

    // ---------------- Fuß: wie voll ist es hier? ----------------
    //
    //  Der Balken zeigt den Datenträger des OFFENEN Ordners, nicht den des
    //  Systems. Wer in einem Ordner auf dem Stick steht, will wissen, wie
    //  voll der Stick ist.
    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Noctis.u(18)
        height: Noctis.u(50)

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: Noctis.u(6)

            Row {
                width: parent.width
                Text {
                    text: root.app && root.app.disk
                          ? K.size(root.app.disk.free) + " frei" : ""
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.u(10)
                    font.weight: Noctis.wMed
                    color: Noctis.ink2
                }
                Item { width: parent.width - 1; height: 1 }
            }

            Rectangle {
                width: parent.width
                height: Noctis.u(4)
                radius: height / 2
                color: Noctis.fill2

                Rectangle {
                    readonly property real f: root.app && root.app.disk && root.app.disk.total > 0
                                              ? root.app.disk.used / root.app.disk.total : 0
                    width: Math.max(height, parent.width * f)
                    height: parent.height
                    radius: height / 2
                    color: f > 0.92 ? Noctis.danger : (f > 0.8 ? Noctis.warning : Noctis.accent)
                    Behavior on width { NumberAnimation { duration: Noctis.mBase; easing.type: Noctis.easeSoft } }
                    Behavior on color { ColorAnimation { duration: Noctis.mBase } }
                }
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.app && root.app.disk
                      ? K.size(root.app.disk.used) + " von " + K.size(root.app.disk.total) + " belegt"
                      : ""
                font.family: Noctis.fontUi
                font.pixelSize: Noctis.u(9)
                color: Noctis.ink3
            }
        }
    }
}
