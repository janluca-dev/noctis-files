// ============================================================================
//  FmDetail — die Auskunftsspalte rechts.
//
//  Sie beantwortet genau eine Frage: was ist das da, das ich gerade angeklickt
//  habe? Deshalb steht oben ein großes Bild und darunter eine Liste von
//  Zeilen — und nicht umgekehrt. Bei mehreren ausgewählten Dateien wird aus
//  der Auskunft eine Summe: wie viele, wie groß zusammen. Auch das ist eine
//  Frage, die man oft hat und die kein Dateimanager beantwortet, ohne dass
//  man ein Fenster öffnet.
//
//  Die Spalte ist NICHT modal und hält nichts auf. Sie lädt ihre Angaben
//  nebenher; solange sie fehlen, steht das, was ohnehin schon bekannt ist
//  (Name, Art, Größe aus der Liste). Ein Feld, das erst leer ist und dann
//  gefüllt wird, ist besser als eines, das auf sich warten lässt.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null

    readonly property var one: app ? app.detailEntry : null
    readonly property var info: app ? app.infoData : null
    readonly property int n: app ? app.selList.length : 0
    readonly property bool many: n > 1

    // ---------------- Mehrere: die Summe ----------------
    Column {
        visible: root.many
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Noctis.padInner
        spacing: Noctis.sp4

        Item {
            width: parent.width
            height: Noctis.u(96)

            Rectangle {
                anchors.centerIn: parent
                width: Noctis.u(84)
                height: width
                radius: Noctis.rInner
                color: Noctis.alpha(Noctis.accent, Noctis.light ? 0.12 : 0.20)

                Text {
                    anchors.centerIn: parent
                    text: root.n
                    font.family: Noctis.fontNum
                    font.features: Noctis.tabular
                    font.pixelSize: Noctis.u(38)
                    font.weight: Noctis.wDisplay
                    font.letterSpacing: Noctis.lsDisplay
                    color: Noctis.accent
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "ausgewählt"
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tMicro
            font.weight: Noctis.wMed
            font.letterSpacing: Noctis.lsMicro
            font.capitalization: Font.AllUppercase
            color: Noctis.ink3
        }

        FmDetailRow { label: "Zusammen"; value: K.size(root.app ? root.app.selBytes : 0) }
        FmDetailRow { label: "Ordner"; value: String(root.app ? root.app.selDirs : 0) }
        FmDetailRow { label: "Dateien"; value: String(root.app ? root.app.selFiles : 0) }
    }

    // ---------------- Eines: die Auskunft ----------------
    LScroll {
        visible: !root.many && root.one !== null
        anchors.fill: parent
        fadeSize: Noctis.u(18)

        Column {
            width: parent.width
            spacing: Noctis.sp4
            topPadding: Noctis.padInner
            bottomPadding: Noctis.padInner
            leftPadding: Noctis.padInner
            rightPadding: Noctis.padInner

            // Das Bild. Groß — es ist der Grund, warum diese Spalte offen ist.
            Item {
                width: parent.width - Noctis.padInner * 2
                height: width * 0.72

                Rectangle {
                    anchors.fill: parent
                    radius: Noctis.rInner
                    color: Noctis.fill1
                }

                FmThumb {
                    anchors.centerIn: parent
                    app: root.app
                    entry: root.one
                    boxSize: Math.min(parent.width, parent.height) - Noctis.sp3
                    glyphScale: 0.40
                }
            }

            Column {
                width: parent.width - Noctis.padInner * 2
                spacing: Noctis.u(3)

                Text {
                    width: parent.width
                    text: root.one ? root.one.name : ""
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.family: Noctis.fontDisplay
                    font.pixelSize: Noctis.tH3
                    font.weight: Noctis.wTitle
                    font.letterSpacing: Noctis.lsTitle
                    color: Noctis.ink
                }
                Text {
                    width: parent.width
                    text: root.one ? K.label(root.one.kind, root.one.ext) : ""
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tLabel
                    color: Noctis.ink3
                }
            }

            // Im Papierkorb ist „Öffnen" die falsche Hauptsache. Was man
            // dort will, ist zurückholen — und zwar an die Stelle, von der
            // es kam.
            LButton {
                width: parent.width - Noctis.padInner * 2
                wide: true
                text: root.app && root.app.inTrash ? "Zurücklegen" : "Öffnen"
                icon: root.app && root.app.inTrash ? K.UI.restore
                      : (root.one && root.one.dir ? K.UI.folderOpen : K.UI.openNew)
                variant: "filled"
                boxHeight: Noctis.u(38)
                onClicked: {
                    if (root.app.inTrash) root.app.restoreSelected()
                    else root.app.activate(root.one)
                }
            }

            // Im Papierkorb bleibt von dieser Reihe genau ein Knopf übrig:
            //  umbenennen und kopieren ergeben dort keinen Sinn, und der
            //  Papierkorb-Knopf wäre eine Aufforderung, etwas ein zweites Mal
            //  wegzuwerfen. Was bleibt, ist der Weg ohne Wiederkehr — und der
            //  steht rot am Rand, nicht in der Mitte.
            Row {
                width: parent.width - Noctis.padInner * 2
                spacing: Noctis.sp2

                readonly property bool trashMode: root.app && root.app.inTrash

                FmIconButton {
                    visible: !parent.trashMode
                    icon: K.UI.pencil
                    hint: "Umbenennen"
                    boxSize: Noctis.u(34)
                    onClicked: root.app.askRename()
                }
                FmIconButton {
                    visible: !parent.trashMode
                    icon: K.UI.copy
                    hint: "Kopieren"
                    boxSize: Noctis.u(34)
                    onClicked: root.app.clipCopy()
                }
                FmIconButton {
                    visible: !parent.trashMode
                    icon: K.UI.link
                    hint: "Pfad merken"
                    boxSize: Noctis.u(34)
                    onClicked: root.app.copyPath()
                }
                Item {
                    width: parent.width - Noctis.u(34) * (parent.trashMode ? 1 : 4)
                           - Noctis.sp2 * (parent.trashMode ? 1 : 4)
                    height: 1
                }
                FmIconButton {
                    icon: parent.trashMode ? K.UI.burn : K.UI.trash
                    hint: parent.trashMode ? "Endgültig löschen" : "In den Papierkorb"
                    boxSize: Noctis.u(34)
                    danger: true
                    onClicked: {
                        if (root.app.inTrash) root.app.askDelete()
                        else root.app.trashSelection()
                    }
                }
            }

            Rectangle {
                width: parent.width - Noctis.padInner * 2
                height: 1
                color: Noctis.hairline
            }

            Column {
                width: parent.width - Noctis.padInner * 2
                spacing: Noctis.u(2)

                FmDetailRow {
                    label: root.one && root.one.dir ? "Inhalt" : "Größe"
                    value: {
                        if (!root.one) return ""
                        if (root.one.dir) {
                            if (root.info && root.info.deepSize !== undefined)
                                return K.size(root.info.deepSize)
                            return root.one.count === null ? "—"
                                 : (root.one.count === 1 ? "1 Eintrag" : root.one.count + " Einträge")
                        }
                        return K.size(root.one.size)
                    }
                }
                FmDetailRow {
                    label: "Geändert"
                    value: root.one ? K.when(root.one.mtime, true) : ""
                }
                // Nur im Papierkorb: woher es kam und wann es dorthin ging.
                // Ohne das ist ein Papierkorb eine Kiste mit Namen darin.
                FmDetailRow {
                    visible: root.one && root.one.orig !== undefined
                    label: "Lag in"
                    value: root.one && root.one.orig ? root.app.prettyDir(root.one.orig) : ""
                }
                FmDetailRow {
                    visible: root.one && root.one.deletedAt !== undefined
                    label: "Weggeworfen"
                    value: root.one && root.one.deletedAt ? K.when(root.one.deletedAt, true) : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.dim !== undefined
                    label: "Abmessungen"
                    value: root.info && root.info.dim ? root.info.dim : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.duration !== undefined && root.info.duration > 0
                    label: "Dauer"
                    value: root.info ? K.duration(root.info.duration) : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.artist !== undefined
                    label: "Künstler"
                    value: root.info && root.info.artist ? root.info.artist : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.album !== undefined
                    label: "Album"
                    value: root.info && root.info.album ? root.info.album : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.lines !== undefined
                    label: "Zeilen"
                    value: root.info && root.info.lines !== undefined ? String(root.info.lines) : ""
                }
                FmDetailRow {
                    visible: root.info && root.info.members !== undefined
                                       && root.info.members !== null
                    label: "Enthält"
                    value: root.info && root.info.members ? root.info.members.n + " Einträge" : ""
                }
                FmDetailRow {
                    label: "Art"
                    value: root.info && root.info.mime ? root.info.mime : ""
                    mono: true
                }
                FmDetailRow {
                    label: "Rechte"
                    value: root.one ? root.one.mode : ""
                    mono: true
                }
                FmDetailRow {
                    visible: root.info && root.info.owner !== undefined
                    label: "Gehört"
                    value: root.info ? root.info.owner + " · " + root.info.group : ""
                }
                FmDetailRow {
                    visible: root.one && root.one.link
                    label: "Zeigt auf"
                    value: root.info && root.info.target ? root.info.target : ""
                    mono: true
                }
            }

            // Ein Blick in die Datei. Nur die ersten Zeilen — wer mehr will,
            // öffnet sie. Aber die Frage „ist das die richtige Datei?"
            // beantwortet schon die erste Zeile.
            Column {
                width: parent.width - Noctis.padInner * 2
                spacing: Noctis.sp2
                visible: root.info && root.info.head !== undefined

                Text {
                    text: "Anfang"
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tMicro
                    font.weight: Noctis.wMed
                    font.letterSpacing: Noctis.lsMicro
                    font.capitalization: Font.AllUppercase
                    color: Noctis.ink4
                }
                Rectangle {
                    width: parent.width
                    height: Math.min(Noctis.u(160), peek.implicitHeight + Noctis.sp4)
                    radius: Noctis.rTile
                    color: Noctis.well
                    clip: true

                    Text {
                        id: peek
                        anchors.fill: parent
                        anchors.margins: Noctis.sp3
                        text: root.info && root.info.head ? root.info.head : ""
                        font.family: Noctis.fontMono
                        font.pixelSize: Noctis.u(10)
                        color: Noctis.ink2
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        lineHeight: 1.35
                    }
                }
            }

            Item { width: 1; height: Noctis.sp4 }
        }
    }

    // ---------------- Nichts gewählt ----------------
    Column {
        visible: !root.many && root.one === null
        anchors.centerIn: parent
        width: parent.width - Noctis.sp7
        spacing: Noctis.sp3

        LIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: K.UI.info
            size: Noctis.u(30)
            color: Noctis.ink4
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Nichts ausgewählt"
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tBody
            font.weight: Noctis.wMed
            color: Noctis.ink3
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Eine Datei anklicken, und hier steht, was es ist."
            wrapMode: Text.WordWrap
            font.family: Noctis.fontUi
            font.pixelSize: Noctis.tLabel
            color: Noctis.ink4
            lineHeight: 1.25
        }
    }
}
