// ============================================================================
//  FmQuickLook — die Leertaste.
//
//  Der schnellste Weg, eine Datei anzusehen, ohne ein Programm zu starten.
//  Einmal Leertaste: groß. Noch einmal: weg. Pfeiltasten gehen weiter, ohne
//  dass man schließen muss — das ist der eigentliche Gewinn: durch einen
//  Ordner Bilder blättern, ohne dreißig Fenster zu öffnen.
//
//  Was gezeigt wird, hängt von der Art ab; was NICHT geht, sagt es ehrlich
//  und bietet an, die Datei richtig zu öffnen. Eine Vorschau, die bei einem
//  Tabellendokument ein graues Rechteck zeigt, ist schlimmer als eine, die
//  „dafür braucht es ein Programm" sagt.
// ============================================================================

import QtQuick
import QtQuick.Effects
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root
    property var app: null
    property var entry: null
    property bool open: false

    readonly property var info: app ? app.infoData : null
    readonly property string kind: entry ? entry.kind : ""
    readonly property bool isImage: entry && entry.thumb === 1 && kind === "image"
    readonly property string madeThumb: (entry && app && app.thumbs[entry.path] !== undefined)
                                        ? app.thumbs[entry.path] : ""
    readonly property bool hasMade: madeThumb !== "" && madeThumb !== "!"
    readonly property bool isTextish: kind === "text" || kind === "code" || kind === "markup"

    anchors.fill: parent
    visible: open || fade.running
    z: 700
    focus: open

    onOpenChanged: {
        if (open) {
            forceActiveFocus()
            if (entry && entry.thumb === 2 && app) app.wantThumb(entry.path)
        } else if (app) {
            app.takeFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        // Kräftiger als ein übliches Abdunkeln. Der Grund: das Fenster ist
        // selbst schon durchscheinend und dunkel — bei 0,7 blieb die
        // Dateiliste so gut lesbar, dass die Vorschau wie ein Zettel darauf
        // wirkte statt wie eine eigene Ebene.
        color: Qt.rgba(0, 0, 0, Noctis.light ? 0.66 : 0.88)
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Noctis.mBase } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Noctis.u(28)
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Noctis.mBase } }
        Behavior on scale { NumberAnimation { duration: Noctis.mBase; easing.type: Noctis.easeOut } }

        // ---------------- Kopf ----------------
        Item {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Noctis.u(48)

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: closeB.left
                anchors.rightMargin: Noctis.sp4
                spacing: -Noctis.u(1)

                Text {
                    width: parent.width
                    text: root.entry ? root.entry.name : ""
                    elide: Text.ElideMiddle
                    font.family: Noctis.fontDisplay
                    font.pixelSize: Noctis.tH2
                    font.weight: Noctis.wTitle
                    font.letterSpacing: Noctis.lsTitle
                    color: "#ffffff"
                }
                Text {
                    width: parent.width
                    text: !root.entry ? "" :
                          K.label(root.entry.kind, root.entry.ext)
                          + (root.entry.dir ? "" : " · " + K.size(root.entry.size))
                          + (root.info && root.info.dim ? " · " + root.info.dim : "")
                    elide: Text.ElideRight
                    font.family: Noctis.fontUi
                    font.pixelSize: Noctis.tLabel
                    color: Qt.rgba(1, 1, 1, 0.62)
                }
            }

            Rectangle {
                id: closeB
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Noctis.u(36)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, closeTouch.containsMouse ? 0.24 : 0.12)
                Behavior on color { ColorAnimation { duration: Noctis.mFast } }

                LIcon {
                    anchors.centerIn: parent
                    text: K.UI.close
                    size: parent.width * 0.40
                    color: "#ffffff"
                }
                MouseArea {
                    id: closeTouch
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open = false
                }
            }
        }

        // ---------------- Bühne ----------------
        Item {
            id: stage
            anchors.top: head.bottom
            anchors.topMargin: Noctis.sp4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: foot.top
            anchors.bottomMargin: Noctis.sp4

            // Bild.
            //
            //  Mit gerundeten Ecken — auch ein Foto ist in dieser Sprache ein
            //  Kiesel (Regel 4). Gemacht wird das über eine Maske und nicht
            //  über ein Rechteck mit `clip`: `clip` schneidet rechteckig, die
            //  Rundung wäre wirkungslos. Ein Maskeneffekt für EIN großes Bild
            //  kostet nichts; für dreihundert Kacheln wäre er zu teuer, und
            //  genau deshalb sind die Kacheln im Raster nicht gerundet.
            Item {
                anchors.fill: parent
                visible: big.visible
                layer.enabled: big.status === Image.Ready
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: bigMask
                }

            Image {
                id: big
                visible: root.isImage || root.hasMade
                anchors.fill: parent
                source: root.isImage ? K.toUri(root.entry.path)
                        : (root.hasMade ? K.toUri(root.madeThumb) : "")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize.width: 2400
                sourceSize.height: 2400
            }
            }

            // Die Maske ist genau so groß wie das gezeichnete Bild, nicht wie
            // die Bühne — sonst rundete sie die Ecken der leeren Fläche
            // daneben und am Bild bliebe alles eckig.
            Item {
                id: bigMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    x: (parent.width - big.paintedWidth) / 2
                    y: (parent.height - big.paintedHeight) / 2
                    width: Math.max(1, big.paintedWidth)
                    height: Math.max(1, big.paintedHeight)
                    radius: Noctis.rCard
                    color: "#ffffff"
                }
            }

            // Text
            Rectangle {
                visible: root.isTextish && root.info && root.info.head !== undefined
                anchors.centerIn: parent
                width: Math.min(parent.width, Noctis.u(760))
                height: parent.height
                radius: Noctis.rCard
                color: Noctis.card
                clip: true

                LScroll {
                    anchors.fill: parent
                    anchors.margins: Noctis.padCard

                    Text {
                        width: parent.width
                        text: root.info && root.info.head ? root.info.head : ""
                        font.family: Noctis.fontMono
                        font.pixelSize: Noctis.u(12)
                        color: Noctis.ink
                        wrapMode: Text.Wrap
                        lineHeight: 1.45
                    }
                }
            }

            // Alles andere.
            //
            //  Hier steht bewusst eine KARTE und nicht nur ein Symbol auf
            //  dem abgedunkelten Grund: ohne Fläche schwebt die Auskunft im
            //  Nichts und sieht aus wie ein Fehler. Mit Fläche ist sie das,
            //  was sie ist — eine Antwort.
            Rectangle {
                visible: !big.visible && !(root.isTextish && root.info && root.info.head !== undefined)
                anchors.centerIn: parent
                width: Math.min(parent.width, Noctis.u(400))
                height: inner.implicitHeight + Noctis.padCard * 2
                radius: Noctis.rCard
                color: Noctis.card

                Column {
                    id: inner
                    anchors.centerIn: parent
                    width: parent.width - Noctis.padCard * 2
                    spacing: Noctis.sp4

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Noctis.u(112)
                        height: width
                        radius: Noctis.rInner
                        color: root.entry ? Noctis.alpha(K.tone(root.entry.kind, Noctis.accent),
                                                        Noctis.light ? 0.12 : 0.20)
                                          : Noctis.fill1

                        FmGlyph {
                            anchors.centerIn: parent
                            text: root.entry ? K.icon(root.entry.kind, root.entry.ext) : ""
                            size: parent.width * 0.44
                            color: root.entry ? K.tone(root.entry.kind, Noctis.accent) : Noctis.ink2
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.entry && root.entry.dir
                              ? "Ein Ordner"
                              : (root.entry && root.entry.kind === "pdf"
                                 ? "Für PDF-Seiten fehlt ein Umwandler"
                                 : "Dafür braucht es ein Programm")
                        font.family: Noctis.fontDisplay
                        font.pixelSize: Noctis.tH3
                        font.weight: Noctis.wTitle
                        font.letterSpacing: Noctis.lsTitle
                        color: Noctis.ink
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.entry && root.entry.dir
                              ? (root.entry.count === null ? "Mit Eingabe öffnen."
                                 : root.entry.count + (root.entry.count === 1 ? " Eintrag" : " Einträge")
                                   + " — mit Eingabe öffnen.")
                              : (root.entry && root.entry.kind === "pdf"
                                 ? "Ist poppler oder ghostscript eingerichtet, steht hier die erste Seite."
                                 : "Mit Öffnen geht die Datei ins passende Programm.")
                        font.family: Noctis.fontUi
                        font.pixelSize: Noctis.tLabel
                        color: Noctis.ink3
                        lineHeight: 1.3
                    }
                }
            }
        }

        // ---------------- Fuß ----------------
        Item {
            id: foot
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Noctis.u(52)

            Row {
                anchors.centerIn: parent
                spacing: Noctis.sp3

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Noctis.u(38)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, prevTouch.containsMouse ? 0.24 : 0.12)
                    LIcon {
                        anchors.centerIn: parent
                        text: K.UI.back
                        size: parent.width * 0.40
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: prevTouch
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.app.quickStep(-1)
                    }
                }

                LButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Öffnen"
                    icon: K.UI.openNew
                    variant: "filled"
                    boxHeight: Noctis.u(38)
                    onClicked: { root.open = false; root.app.activate(root.entry) }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Noctis.u(38)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, nextTouch.containsMouse ? 0.24 : 0.12)
                    LIcon {
                        anchors.centerIn: parent
                        text: K.UI.fwd
                        size: parent.width * 0.40
                        color: "#ffffff"
                    }
                    MouseArea {
                        id: nextTouch
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.app.quickStep(1)
                    }
                }
            }
        }
    }

    Keys.onPressed: e => {
        if (!root.open) return
        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Space) { root.open = false; e.accepted = true }
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) { root.app.quickStep(-1); e.accepted = true }
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) { root.app.quickStep(1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.open = false; root.app.activate(root.entry); e.accepted = true
        }
    }
}
