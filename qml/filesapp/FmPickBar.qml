// ============================================================================
//  FmPickBar — die Leiste, die aus dem Dateimanager einen Dialog macht.
//
//  Sie erscheint nur, wenn das Fenster als Dateiauswahl des Systems läuft
//  (siehe filesapp/portal.py). Darüber bleibt alles, was das Suchen leicht
//  macht — Seitenleiste, Vorschaubilder, Suche, Sortierung. Das ist der
//  ganze Sinn der Sache: ein Dialog, der so viel kann wie der Dateimanager,
//  weil er derselbe ist.
//
//  Die Leiste liegt auf der Scheibe und nicht auf einer Karte. Sie ist kein
//  Inhalt, sondern der Rand des Fensters — wie die Fußzeile darüber, nur mit
//  einer Entscheidung darin. Rechts steht genau EINE gefüllte Pille (Regel 3:
//  eine Farbe pro Fläche), und die ist die Antwort auf die gestellte Frage.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null

    readonly property bool an: app && app.pickMode
    implicitHeight: an ? Noctis.u(64) : 0
    visible: an

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Noctis.hairline
    }

    // ---------------- Name (beim Speichern) ----------------
    Row {
        id: links
        anchors.left: parent.left
        anchors.leftMargin: Noctis.u(18)
        anchors.right: rechts.left
        anchors.rightMargin: Noctis.sp4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Noctis.sp3

        Text {
            visible: root.app && root.app.pickSaving
            anchors.verticalCenter: parent.verticalCenter
            text: "Name"
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tMicro
            font.weight: Noctis.wMed
            font.letterSpacing: Noctis.lsMicro
            font.capitalization: Font.AllUppercase
            color: Noctis.ink3
        }

        Rectangle {
            id: feld
            visible: root.app && root.app.pickSaving
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Noctis.u(420), links.width - Noctis.u(80))
            height: Noctis.u(38)
            radius: height / 2
            color: Noctis.well
            border.width: name.activeFocus ? 1 : 0
            border.color: Noctis.accentEdge

            TextInput {
                id: name
                anchors.fill: parent
                anchors.leftMargin: Noctis.u(16)
                anchors.rightMargin: Noctis.u(16)
                verticalAlignment: TextInput.AlignVCenter
                font.family: Noctis.fontUi
                font.pixelSize: Noctis.tBody
                color: Noctis.ink
                selectionColor: Noctis.alpha(Noctis.accent, 0.35)
                selectedTextColor: Noctis.ink
                clip: true
                text: root.app ? root.app.pickName : ""
                onTextEdited: root.app.pickName = text
                onAccepted: root.app.pickConfirm()
                Keys.onEscapePressed: root.app.pickCancel()
            }
        }

        // Im Öffnen-Modus steht hier, was die Antwort wäre. Ohne diese Zeile
        // muss man raten, ob der Knopf die markierte Datei meint oder den
        // Ordner, in dem man steht.
        Text {
            visible: root.app && !root.app.pickSaving
            anchors.verticalCenter: parent.verticalCenter
            width: links.width - Noctis.sp3
            elide: Text.ElideMiddle
            text: {
                if (!root.app) return ""
                var n = root.app.selEntries.length
                if (root.app.pickDirs) {
                    var d = []
                    for (var i = 0; i < root.app.selEntries.length; i++)
                        if (root.app.selEntries[i].dir) d.push(root.app.selEntries[i].name)
                    if (d.length === 0)
                        return "Dieser Ordner: " + root.app.tabLabel(root.app.path)
                    return d.length === 1 ? d[0] : d.length + " Ordner gewählt"
                }
                var f = []
                for (var j = 0; j < root.app.selEntries.length; j++)
                    if (!root.app.selEntries[j].dir) f.push(root.app.selEntries[j].name)
                if (f.length === 0) return "Keine Datei gewählt"
                return f.length === 1 ? f[0] : f.length + " Dateien gewählt"
            }
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tBody
            font.weight: Noctis.wMed
            color: root.app && root.app.pickReady ? Noctis.ink : Noctis.ink3
        }
    }

    // ---------------- Filter und Knöpfe ----------------
    Row {
        id: rechts
        anchors.right: parent.right
        anchors.rightMargin: Noctis.u(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Noctis.sp2

        // Der Filter ist eine Pille, kein Klapplistchen: sie zeigt, was
        // gerade gilt, und öffnet auf Klick dieselbe Art Menü wie überall
        // sonst im Programm.
        Item {
            visible: root.app && root.app.pickReq
                     && root.app.pickReq.filters && root.app.pickReq.filters.length > 1
            anchors.verticalCenter: parent.verticalCenter
            width: filterRow.implicitWidth + Noctis.u(26)
            height: Noctis.u(34)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: filterTouch.containsMouse ? Noctis.fill2 : Noctis.fill1
                Behavior on color { ColorAnimation { duration: Noctis.mFast } }
            }
            Row {
                id: filterRow
                anchors.centerIn: parent
                spacing: Noctis.u(6)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!root.app || !root.app.pickReq) return ""
                        var fs = root.app.pickReq.filters
                        var i = root.app.pickFilter
                        return (i >= 0 && i < fs.length) ? fs[i].name : "Alle Dateien"
                    }
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tBody
                    font.weight: Noctis.wMed
                    color: Noctis.ink2
                }
                LIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: K.UI.down
                    size: Noctis.u(11)
                    color: Noctis.ink3
                }
            }
            MouseArea {
                id: filterTouch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var p = mapToItem(null, 0, 0)
                    root.app.menuForPickFilter(p.x, p.y)
                }
            }
        }

        Item { width: Noctis.sp2; height: 1 }

        LButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "Abbrechen"
            variant: "ghost"
            boxHeight: Noctis.u(40)
            onClicked: root.app.pickCancel()
        }
        LButton {
            anchors.verticalCenter: parent.verticalCenter
            text: root.app ? root.app.pickAccept : ""
            variant: "filled"
            boxHeight: Noctis.u(40)
            enabled: root.app && root.app.pickReady
            onClicked: root.app.pickConfirm()
        }
    }

    function focusName() {
        if (root.app && root.app.pickSaving) {
            name.forceActiveFocus()
            // Beim Speichern ist die Endung fast nie gemeint: „bericht" soll
            // man überschreiben können, ohne „.pdf" neu zu tippen.
            var dot = name.text.lastIndexOf(".")
            if (dot > 0) name.select(0, dot)
            else name.selectAll()
        }
    }
}
