// ============================================================================
//  FmThumb — das Bild einer Datei.
//
//  Drei Fälle, und der Aufrufer muss keinen davon kennen:
//
//    1  Qt kann die Datei selbst laden (PNG, JPEG, WebP, SVG …). Dann wird
//       sie direkt angezeigt, verkleinert über `sourceSize` — ein 40-MP-Foto
//       darf nicht in voller Größe im Speicher landen, nur weil eine Kachel
//       130 Punkte breit ist.
//
//    2  Es muss erst eines werden (Film, PDF, HEIC, RAW). Dann wird beim
//       Programm ein Vorschaubild bestellt; bis es da ist, steht das Symbol
//       der Dateiart. Nachgereicht wird es weich eingeblendet — ein Bild,
//       das hart erscheint, wirkt wie ein Fehler.
//
//    3  Es gibt keines (Text, Quelltext, Archiv, Ordner). Dann ist das
//       Symbol das Bild, auf getönter Fläche wie bei LIconTile.
//
//  ANPASSEN, NICHT BESCHNEIDEN. Ein hochkant fotografiertes Bild in ein
//  Quadrat zu schneiden nimmt ihm den Kopf ab. Hier bleibt jedes Bild in
//  seinem Seitenverhältnis und bekommt Luft — das ist Regel 1, und es ist
//  nebenbei die ehrlichere Vorschau.
// ============================================================================

import QtQuick
import "../noctis"
import "../"
import "FmKind.js" as K

Item {
    id: root

    property var  app: null
    property var  entry: null
    property real boxSize: Noctis.u(96)
    property bool showKindBadge: true      // das Filmzeichen über einem Film
    property real glyphScale: 0.46
    // Die getönte Fläche hinter dem Symbol. In der LISTE gehört sie hin —
    // dort ist sie die Kachel aus LIconTile und macht die Zeile lesbar. Im
    // RASTER nicht: dreißig getönte Quadrate nebeneinander sind dreißig
    // Kästen, und diese Sprache kennt keine Kästen (Regel 4). Dort trägt das
    // Symbol allein, groß und in seinem Ton — genau das, was LCard mit
    // `filled: false` meint.
    property bool plate: true

    readonly property string path: entry ? entry.path : ""
    readonly property string kind: entry ? entry.kind : "other"
    readonly property color  tone: K.tone(kind, Noctis.accent)

    // Fall 1 direkt, Fall 2 über das Programm.
    readonly property int mode: !entry ? 0 : entry.thumb
    readonly property string madeThumb: (mode === 2 && app && app.thumbs[path] !== undefined)
                                        ? app.thumbs[path] : ""
    readonly property string src: mode === 1 ? K.toUri(path)
                                : (madeThumb !== "" && madeThumb !== "!" ? K.toUri(madeThumb) : "")

    width: boxSize
    height: boxSize

    // Bestellen, sobald diese Kachel entsteht — also genau dann, wenn die
    // Liste sie braucht. Eine Bestellung für tausend Dateien auf einmal
    // hätte den Rechner eine Minute lang beschäftigt, und die ersten zwölf
    // Bilder wären trotzdem nicht schneller da gewesen.
    Component.onCompleted: if (mode === 2 && app) app.wantThumb(path)
    onPathChanged: if (mode === 2 && app) app.wantThumb(path)

    // ---------------- Symbol ----------------
    Rectangle {
        id: pad
        anchors.centerIn: parent
        width: root.boxSize
        height: root.boxSize
        radius: Math.max(Noctis.u(8), root.boxSize * 0.22)
        color: (img.shown || !root.plate) ? "transparent"
                                          : Noctis.alpha(root.tone, Noctis.light ? 0.12 : 0.20)
        Behavior on color { ColorAnimation { duration: Noctis.mFast } }

        FmGlyph {
            anchors.centerIn: parent
            opacity: img.shown ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Noctis.mBase } }
            text: root.entry ? K.icon(root.kind, root.entry.ext) : ""
            size: root.boxSize * root.glyphScale
            color: root.tone
        }

    }

    // ---------------- Bild ----------------
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: Math.round(root.boxSize * 0.04)
        source: root.src
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectFit
        // Zwei Dinge über sourceSize: es begrenzt, was Qt einliest (nicht
        // nur, was es zeichnet), und eine der beiden Kanten muss 0 bleiben,
        // sonst verzerrt Qt das Seitenverhältnis.
        sourceSize.width: Math.round(root.boxSize * 2)
        sourceSize.height: Math.round(root.boxSize * 2)
        smooth: true
        mipmap: true

        readonly property bool shown: source != "" && status === Image.Ready
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Noctis.mBase; easing.type: Noctis.easeSoft } }
    }

    // Das Zeichen der Art über dem Bild — bei einem Film die Klappe, bei
    // einem PDF der Schriftzug. Ohne das sieht ein Film aus wie ein Foto,
    // und man wundert sich, warum sich ein Abspieler öffnet.
    Rectangle {
        visible: root.showKindBadge && img.shown
                 && (root.kind === "video" || root.kind === "pdf")
        anchors.right: img.right
        anchors.bottom: img.bottom
        anchors.margins: Noctis.u(3)
        width: Noctis.u(20)
        height: width
        radius: width / 2
        color: Qt.rgba(0, 0, 0, 0.55)

        LIcon {
            anchors.centerIn: parent
            text: root.kind === "video" ? K.icon("video", "") : K.icon("pdf", "")
            size: parent.width * 0.56
            color: "#ffffff"
        }
    }
}
