pragma Singleton

// ============================================================================
//  Noctis.qml — die Designsprache „Noctis".
//
//  Das hier ist KEINE Weiterentwicklung von Theme.qml. Theme.qml beschreibt
//  das bisherige Erscheinungsbild (und den noch älteren Classic-Zustand);
//  diese Datei beschreibt ein zweites, vollständig eigenes. Beide leben
//  nebeneinander, beide lesen dieselbe ~/.config/noctis/theme.json — aber
//  keine einzige Farbe, kein Radius und keine Schriftgröße wird von dort
//  übernommen. „Neu entworfen" heißt: bei Null angefangen.
//
//  Umgeschaltet wird über `skin` in der theme.json:
//
//      "skin": "noctis"     → die neuen Module (noctis/Noctis*.qml)
//      "skin": "modern"    → die bestehenden Module, neutrale Palette
//      "skin": "classic"   → die bestehenden Module, Matugen-Palette
//
//  WindowRegistry.js entscheidet anhand dieses Werts, WELCHE QML-Datei ein
//  Widget öffnet. Steht kein Noctis-Gegenstück bereit, fällt die Registry auf
//  das bestehende Modul zurück — die Oberfläche ist dadurch zu keinem
//  Zeitpunkt kaputt, nur teilweise noch alt.
//
//  ---------------------------------------------------------------------
//  DIE SIEBEN REGELN, aus denen alles andere folgt
//  ---------------------------------------------------------------------
//
//  1  LUFT ZUERST. Der Rand einer Karte ist kein Abstandshalter, sondern
//     ein Gestaltungsmittel. 28–32 px Polsterung innen, 20 px zwischen
//     Karten. Lieber weniger anzeigen als enger setzen.
//
//  2  GRÖSSENKONTRAST STATT FARBE. Die Zahl riesig und schwarz, ihr
//     Etikett winzig und grau. Ein Verhältnis von mindestens 1:3 zwischen
//     Wert und Beschriftung. Das ist der Grund, warum die Vorlagen ruhig
//     wirken, obwohl viel auf ihnen steht.
//
//  3  EINE FARBE PRO FLÄCHE. Alles Grau, genau eine Sache farbig. Farbe
//     bedeutet hier immer „das ist der nächste Schritt" oder „das ist
//     gerade aktiv" — nie Dekoration.
//
//  4  KIESEL, KEINE KÄSTEN. Radius 30 außen, 22 innen, 18 an Kacheln,
//     alles Klickbare ist eine Pille oder ein Kreis. Ein rechter Winkel
//     kommt in dieser Sprache nicht vor.
//
//  5  TIEFE ÜBER TON UND SCHATTEN. Karte auf Karte wird eine Stufe heller,
//     nie eine Linie dazwischen. Ränder gibt es nur als Lichtkante auf
//     Glas.
//
//  6  EIN FARBVERLAUF IST EIN EREIGNIS. Genau eine Fläche pro Fenster darf
//     ein Verlauf sein — die Wetterkarte, der Schlafbogen, das Konto. Der
//     Rest ist Weiß auf Hellgrau bzw. Anthrazit auf Schwarz. Zwei Verläufe
//     nebeneinander sehen sofort nach Bastelei aus.
//
//  7  BEWEGUNG ERKLÄRT, SIE SCHMÜCKT NICHT. Etwas kommt von dort, wo es
//     herkommt, und geht dorthin, wo es hingehört. 260 ms, weich auslaufend.
//
//  Alle Maße sind für 1920 px Bildschirmbreite gedacht. Die Module schicken
//  sie durch ihren Scaler (s()), damit sie auf 4K mitwachsen.
// ============================================================================

import QtQuick
import NoctisHost

// Eigenständige Fassung (Noctis Files als Paket): Quickshells `Singleton`
// wird zu einem schlichten QtObject, die beiden Dateibeobachter hängen als
// Eigenschaften daran. Alles andere ist Ziffer für Ziffer dieselbe Datei wie
// ~/.config/hypr/scripts/quickshell/Noctis.qml — wer dort etwas an Farben
// oder Maßen ändert, zieht es hier nach.
QtObject {
    id: root

    // ==================================================================
    //  Benutzerwerte aus ~/.config/noctis/theme.json
    // ==================================================================
    property string skin: "modern"
    // Ohne theme.json (jeder Rechner außerhalb des Noctis-Systems) richtet
    // sich der Modus nach dem Schreibtisch, und Milchglas gibt es nur dort,
    // wo der Compositor wirklich weichzeichnet — sonst wäre die Scheibe ein
    // Fenster, durch das man den Schreibtisch scharf sieht.
    property string mode: Qt.styleHints.colorScheme === Qt.ColorScheme.Light ? "light" : "dark"
    property string accentName: "blue"
    property string accentCustom: ""
    property real   glassAlpha: Host.compositorBlur ? 0.82 : 1.0   // eigener Regler-Bereich, s.u.
    property real   uiRadius: 1.0

    // ==================================================================
    //  SKALIERUNG — einmal hier, nicht in jedem Modul.
    //
    //  Der bisherige Look reicht in jedem Widget einen eigenen `Scaler`
    //  herum und schreibt jede Zahl als s(24). Das ist fehleranfällig
    //  (vergisst man das s(), stimmt genau ein Abstand nicht) und macht
    //  jede Zeile länger. In Noctis sind die Marken SELBST schon skaliert:
    //  `Noctis.sp5` ist bereits der Wert für DIESEN Bildschirm.
    //
    //  Wer die Breite setzt, ist das Fenster — Main.qml, die Leiste, das
    //  Dock schreiben beim Öffnen bzw. beim Monitorwechsel ihre eigene
    //  Bildschirmbreite hierher.
    // ==================================================================
    property real screenWidth: 1920

    readonly property real k: {
        if (screenWidth <= 0) return 1.0
        var r = screenWidth / 1920.0
        // Unter 1920 flacher abfallen als linear (sonst wird alles winzig),
        // darüber genauso gedämpft mitwachsen — auf 4K soll eine Karte
        // größer, aber nicht doppelt so groß werden.
        return r <= 1.0 ? Math.max(0.55, Math.pow(r, 0.85)) : Math.pow(r, 0.85)
    }

    function u(v) { return Math.round(v * k) }

    // Ist Noctis überhaupt an? Module fragen das nicht ab (sie werden ja nur
    // dann geladen), die Leiste und das Dock dagegen schon — die laufen als
    // Dauerprozess und müssen im Betrieb umschalten.
    readonly property bool active: skin === "noctis"
    readonly property bool light: mode === "light"

    // ==================================================================
    //  Hilfsfunktionen
    // ==================================================================
    // Qt.darker(x, 1.0) ist der kürzeste Weg, aus „#f2f2f4" eine echte Farbe
    // zu machen: es nimmt Zeichenketten an und gibt unverändert eine color
    // zurück. Ohne diese Umwandlung liefert c.r bei einer Zeichenkette
    // `undefined`, Qt.rgba() macht daraus Schwarz — und man sucht lange,
    // warum eine Fläche in JEDEM Modus dunkel bleibt.
    function toColor(c) { return Qt.darker(c, 1.0) }

    function alpha(c, a) {
        var q = toColor(c)
        return Qt.rgba(q.r, q.g, q.b, a)
    }

    function mix(x, y, f) {
        var a = toColor(x), b = toColor(y)
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f,
                       a.a + (b.a - a.a) * f)
    }

    // Wahrgenommene Helligkeit (Rec. 709) — entscheidet über schwarze oder
    // weiße Schrift auf einer gefüllten Fläche.
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    function onColor(c) { return lum(c) > 0.60 ? "#0b0b0d" : "#ffffff" }

    // Ton heller/dunkler machen, ohne den Buntton zu verschieben. Qt.lighter()
    // multipliziert und kippt gesättigte Farben ins Grelle; das hier mischt
    // gegen Weiß bzw. Schwarz und bleibt ruhig.
    function up(c, f)   { var q = toColor(c); return mix(q, Qt.rgba(1, 1, 1, q.a), f) }
    function down(c, f) { var q = toColor(c); return mix(q, Qt.rgba(0, 0, 0, q.a), f) }

    // §98 Eine FREMDE Farbe auf den Grund dieses Modus holen.
    //
    // Die Töne dieser Datei sind für hell und dunkel getrennt gewählt und
    // brauchen das nicht. Gebraucht wird es, sobald eine Farbe von außen
    // kommt und niemand sie vorher gesehen hat — die Leitfarbe aus dem Logo
    // einer fremden App zum Beispiel. Spotify-Grün ist auf Weiß zu hell,
    // Discord-Blau auf Schwarz zu dunkel, und beide würden als winzige
    // Versalzeile verschwinden.
    //
    // Der Buntton bleibt unangetastet, nur die Helligkeit wird in das
    // Fenster geschoben, in dem eine Farbe auf DIESEM Grund noch trägt.
    // Sitzt sie schon darin, passiert nichts.
    function readable(c) {
        var q = toColor(c)
        var l = lum(q)
        if (light) return l > 0.45 ? down(q, Math.min(0.60, (l - 0.45) * 1.9)) : q
        return l < 0.42 ? up(q, Math.min(0.65, (0.42 - l) * 1.8)) : q
    }

    // ==================================================================
    //  AKZENT
    //
    //  Neun Töne, je einer für hell und dunkel. Sie sind kräftiger als die
    //  Systemfarben des bisherigen Looks: Noctis setzt Farbe extrem sparsam
    //  ein (Regel 3), und das eine farbige Element auf einer sonst grauen
    //  Fläche darf dann auch leuchten.
    // ==================================================================
    readonly property var accents: ({
        "blue":     { label: "Blau",     light: "#0b67ff", dark: "#3d8bff" },
        "indigo":   { label: "Indigo",   light: "#4f46e5", dark: "#7c7cff" },
        "purple":   { label: "Violett",  light: "#8b3dff", dark: "#a970ff" },
        "pink":     { label: "Pink",     light: "#e8306f", dark: "#ff5c8a" },
        "red":      { label: "Rot",      light: "#e02424", dark: "#ff5a4d" },
        "orange":   { label: "Orange",   light: "#f26b0f", dark: "#ff8c3a" },
        "amber":    { label: "Bernstein",light: "#d98200", dark: "#ffb020" },
        "green":    { label: "Grün",     light: "#0f9d58", dark: "#2fd47a" },
        "teal":     { label: "Türkis",   light: "#0891a6", dark: "#34d0e8" },
        "graphite": { label: "Graphit",  light: "#3a3a40", dark: "#c8c8d0" }
    })

    readonly property var accentOrder: ["blue", "indigo", "purple", "pink",
                                        "red", "orange", "amber", "green",
                                        "teal", "graphite"]

    // Matugen-Palette — nur als Quelle für „Akzent aus dem Hintergrundbild".
    // Noctis färbt seine Flächen NICHT nach dem Wallpaper: eine Oberfläche,
    // die bei jedem Bildwechsel ihre Grundtöne tauscht, kann keine eigene
    // Handschrift haben.
    property var mat: ({ blue: "#89b4fa", mauve: "#cba6f7", teal: "#94e2d5" })

    readonly property color accent: {
        if (accentCustom !== "") return accentCustom
        if (accentName === "auto") return mat.blue
        var a = accents[accentName]
        if (!a) a = accents["blue"]
        return light ? a.light : a.dark
    }

    readonly property color onAccent:    onColor(accent)
    readonly property color accentHover: light ? down(accent, 0.10) : up(accent, 0.12)
    readonly property color accentSoft:  alpha(accent, light ? 0.10 : 0.16)
    readonly property color accentEdge:  alpha(accent, light ? 0.28 : 0.34)
    // Der weiche Schein unter einem aktiven Element (Upload-Kreis, aktive
    // Kachel). In den Vorlagen ist das der Unterschied zwischen „Knopf" und
    // „hier musst du hin".
    readonly property color accentGlow:  alpha(accent, light ? 0.22 : 0.30)

    // ==================================================================
    //  FLÄCHEN
    //
    //  Der Hellmodus ist die Heimat dieser Sprache: warmes Hellgrau als
    //  Grund, reines Weiß als Karte. Der Dunkelmodus ist keine Umkehrung,
    //  sondern eine eigene Übersetzung — tiefes Neutralschwarz als Grund,
    //  Karten eine deutliche Stufe darüber, damit die Schichtung sichtbar
    //  bleibt (im Hellmodus trennt Weiß gegen Grau, im Dunkelmodus muss der
    //  Sprung größer sein, sonst verschwindet die Karte).
    // ==================================================================

    // Der Grund, auf dem alles liegt — die Fläche des Fensters selbst.
    readonly property color ground:    light ? "#eeeef0" : "#0c0c0e"

    // Milchglas: die schwebende Fensterfläche über dem Hintergrundbild.
    // Der Weichzeichner kommt vom Compositor (layerrule in hyprland.conf),
    // hier steht nur die Deckkraft. Unter 0.45 blurrt Hyprland nicht mehr
    // (ignore_alpha = 0.35) — deshalb ist das der harte Boden des Reglers.
    readonly property color plateBase:     light ? "#f2f2f4" : "#141417"
    readonly property color plateDeepBase: light ? "#e8e8ec" : "#0e0e10"
    readonly property color plate:     alpha(plateBase, glassAlpha)
    readonly property color plateDeep: alpha(plateDeepBase, glassAlpha)

    // §86 Menüfläche. Bewusst NICHT am Regler für die Durchsichtigkeit:
    // Milchglas ist ein Zustand, in dem man sich aufhält — ein Menü ist eine
    // Frage, die sofort beantwortet wird. Was man in einer Sekunde lesen
    // muss, darf nicht mit dem konkurrieren, was dahinter steht. 0.96 statt
    // deckend, damit es dennoch zur Sprache gehört und nicht wie ein
    // aufgeklebter Kasten wirkt.
    readonly property color popover:   alpha(plateDeepBase, 0.96)

    // Karten. Deckend — sie liegen auf der schon gefüllten Platte.
    readonly property color card:      light ? "#ffffff" : "#1a1a1e"
    readonly property color cardAlt:   light ? "#f7f7f9" : "#212126"
    readonly property color tile:      light ? "#f2f2f5" : "#26262c"
    readonly property color tileAlt:   light ? "#e9e9ee" : "#2e2e35"

    // Eingabefelder und Listenzeilen liegen tiefer als ihre Karte, nicht
    // höher — eine Mulde, in die man etwas hineinschreibt.
    readonly property color well:      light ? "#f0f0f3" : "#141418"

    // ==================================================================
    //  SCHRIFT-FARBEN
    //  Vier Stufen. Mehr braucht es nicht, weniger reicht nicht: Titel,
    //  Fließtext, Etikett, Deko.
    // ==================================================================
    readonly property color ink:   light ? "#0a0a0c" : "#f6f6f8"
    readonly property color ink2:  light ? "#55555e" : "#b4b4be"
    readonly property color ink3:  light ? "#8b8b95" : "#7d7d88"
    readonly property color ink4:  light ? "#b8b8c0" : "#55555e"

    // ==================================================================
    //  LINIEN UND FÜLLUNGEN
    // ==================================================================
    readonly property color inkBase: light ? "#000000" : "#ffffff"

    readonly property color hairline:    alpha(inkBase, light ? 0.07 : 0.09)
    readonly property color hairlineUp:  alpha(inkBase, light ? 0.12 : 0.16)
    // Die Lichtkante auf Glas: oben innen ein Hauch Weiß. Sie ersetzt den
    // Rahmen und ist der Grund, warum eine Karte auf dunklem Hintergrundbild
    // nicht verschwimmt.
    readonly property color lightEdge:   light ? Qt.rgba(1, 1, 1, 0.80) : Qt.rgba(1, 1, 1, 0.07)

    readonly property color fill1: alpha(inkBase, light ? 0.04  : 0.06)
    readonly property color fill2: alpha(inkBase, light ? 0.07  : 0.10)
    readonly property color fill3: alpha(inkBase, light ? 0.11  : 0.15)
    readonly property color hover: alpha(inkBase, light ? 0.045 : 0.065)
    readonly property color press: alpha(inkBase, light ? 0.09  : 0.12)

    // ==================================================================
    //  STATUS
    // ==================================================================
    readonly property color success: light ? "#0f9d58" : "#2fd47a"
    readonly property color warning: light ? "#e08a00" : "#ffb020"
    readonly property color danger:  light ? "#e02424" : "#ff5a4d"
    readonly property color info:    accent

    // ==================================================================
    //  VERLÄUFE — die Ereignisflächen (Regel 6)
    //
    //  Jeder Verlauf hat drei Stützpunkte und ist so gebaut, dass weiße
    //  Schrift über der GANZEN Fläche lesbar bleibt; deshalb wird nach unten
    //  hin nicht aufgehellt, sondern entsättigt.
    // ==================================================================
    readonly property var skyDay:   ["#1f6fd6", "#3f9ae0", "#9ecfe8"]   // Wetter, klar
    readonly property var skyNight: ["#101a3a", "#1f3369", "#4a5fa0"]   // Wetter, nachts
    readonly property var dusk:     ["#3a2f9e", "#6a4fc0", "#c79bd0"]   // Schlaf, Fokus
    readonly property var ember:    ["#4a2116", "#8a4526", "#c47a4a"]   // Konto, Speicher
    readonly property var mintGrad: ["#0a5c4c", "#128a6e", "#4cc9a0"]   // Netz, Erfolg
    readonly property var slate:    ["#16181d", "#22262e", "#39404d"]   // Flug, Technik

    // Der Sonnenschein auf der Wetterkarte: ein radialer Fleck, kein
    // Kreis mit Rand. Ohne ihn ist der Verlauf nur ein blaues Rechteck.
    readonly property color sunGlow:  "#ffd36e"
    readonly property color moonGlow: "#e8edff"

    // Datenfarben. Reihenfolge ist Absicht — die ersten beiden tragen fast
    // alles, der Rest kommt erst bei vielen Serien dazu.
    readonly property var series: ["#3b82f6", "#8b5cf6", "#22d3ee",
                                   "#34d399", "#fbbf24", "#fb7185"]
    function seriesAt(i) { return series[i % series.length] }

    // ==================================================================
    //  SCHATTEN — derzeit ungenutzt (§83)
    //
    //  Die Marken stehen noch hier, gezeichnet wird mit ihnen nichts mehr.
    //  Der Grund steht ausführlich in LSurface.qml: ein Schatten über
    //  `layer.effect` wird auf die Item-Grenzen beschnitten, und in dieser
    //  Sprache füllt jede Fläche ihren Container aus. Ergebnis war ein
    //  hartkantiger grauer Streifen statt eines Schattens.
    //
    //  Wer ihn zurückholen will, braucht ein Elternteil mit Rand, in den der
    //  Schatten hineinragen darf — dann sind diese Werte die richtigen.
    // ==================================================================
    readonly property color shadow:     Qt.rgba(0, 0, 0, light ? 0.10 : 0.42)
    readonly property real  shadowBlur: 1.0
    readonly property int   shadowY:    u(light ? 10 : 14)
    // Zweite, engere Lage für Elemente, die nah über ihrer Fläche liegen
    // (Pillen, Kacheln beim Überfahren).
    readonly property color shadowNear: Qt.rgba(0, 0, 0, light ? 0.08 : 0.34)
    readonly property int   shadowNearY: u(light ? 4 : 6)

    // ==================================================================
    //  FORM
    // ==================================================================
    readonly property int rCard:  u(30 * uiRadius)
    readonly property int rInner: u(22 * uiRadius)
    readonly property int rTile:  u(18 * uiRadius)
    readonly property int rCtl:   u(14 * uiRadius)
    readonly property int rMini:  u(10 * uiRadius)
    readonly property int rPill:  999

    // ==================================================================
    //  ABSTÄNDE — eine Leiter, keine freien Zahlen. Wer zwischen zwei
    //  Stufen etwas braucht, hat meistens ein Layoutproblem, kein
    //  Abstandsproblem.
    // ==================================================================
    readonly property int sp1: u(4)
    readonly property int sp2: u(8)
    readonly property int sp3: u(12)
    readonly property int sp4: u(16)
    readonly property int sp5: u(20)
    readonly property int sp6: u(24)
    readonly property int sp7: u(32)
    readonly property int sp8: u(40)
    readonly property int sp9: u(56)

    // Polsterung innen: außen großzügig, innen eine Stufe weniger.
    readonly property int padCard:  u(28)
    readonly property int padInner: u(20)
    readonly property int padTile:  u(16)

    // §99 Der Rand einer SEITE, die schon in einer Fläche liegt.
    //
    // Regel 1 verlangt 28–32 px Polsterung — die gelten für die Fläche, an
    // deren Rand man tatsächlich steht. Eine Seite in einem Fenster mit
    // Seitenleiste steht dort nicht: zwischen ihr und dem Fensterrand liegt
    // schon der Abstand der Inhaltsfläche. Rechnet man dort noch einmal
    // padCard, kommt man auf 42 px und die Seite wirkt zusammengeschoben.
    //
    // Noctis Weather und Noctis Files setzen an dieser Stelle 14 + 18 — in
    // der Summe genau die 32 aus Regel 1, nur auf zwei Stufen verteilt. Das
    // ist der Wert für die zweite Stufe.
    readonly property int padPage:  u(18)

    // ==================================================================
    //  SCHRIFT
    //
    //  Outfit ist die geometrische Grotesk der Vorlagen: runde Ziffern,
    //  doppelstöckiges „a", im schweren Schnitt eng laufend. Eine einzige
    //  variable Datei deckt Thin bis Black ab. Sie liegt unter
    //  ~/.local/share/fonts/noctis (SIL Open Font License).
    //
    //  Fehlt sie auf einem Rechner, greift die Ersatzkette: Adwaita Sans
    //  (der Inter-Schnitt, auf jedem GNOME-Grundsystem vorhanden). Deshalb
    //  stehen hier Listen und keine einzelnen Namen — Qt nimmt den ersten
    //  Eintrag, den es findet, statt auf eine Standardschrift zu fallen.
    //
    //  `fontDisplay` und `fontUi` sind absichtlich getrennt, auch wenn hier
    //  dasselbe steht: sollte sich der kleine Fließtext in Outfit je als zu
    //  luftig erweisen, wird NUR `fontUi` auf Adwaita Sans zurückgesetzt und
    //  die Überschriften bleiben geometrisch.
    // ==================================================================
    readonly property string fontDisplay: "Outfit, Adwaita Sans"
    readonly property string fontUi:      "Outfit, Adwaita Sans"
    readonly property string fontIcon:    "Iosevka Nerd Font"

    // Zahlen, die sich im Sekundentakt ändern (Uhr, Timer, Prozentwerte),
    // dürfen ihre Nachbarn nicht verschieben. Bisher hieß die Antwort darauf
    // „dann eben eine Monospace-Schrift" — das kostet aber die Handschrift
    // an genau der Stelle, an der die Vorlagen ihre größte Zahl zeigen.
    //
    // Outfit bringt tabellarische Ziffern mit (OpenType-Merkmal `tnum`).
    // Gemessen bei 62 px, DemiBold:
    //
    //     ohne tnum   "00:00" = 181,05 px   "11:11" = 108,42 px
    //     mit  tnum   "00:00" = 163,73 px   "11:11" = 163,73 px
    //
    // Also: dieselbe Schrift wie überall, und trotzdem steht die Uhr still.
    // Wer eine Zahl setzt, die sich ändert, schreibt dazu
    //     font.family: Noctis.fontNum
    //     font.features: Noctis.tabular
    readonly property string fontNum: fontDisplay
    readonly property var    tabular: ({ "tnum": 1 })

    // Echte Monospace bleibt für das, was WIRKLICH Zeichenraster braucht:
    // Tastenkappen, Pfade, Ausgaben von Befehlen.
    readonly property string fontMono: "JetBrains Mono"

    // Größen bei 1920 px Breite.
    readonly property int tDisplay: u(62)   // die eine riesige Zahl/Uhrzeit
    readonly property int tH1:      u(38)   // Überschrift einer Fläche
    readonly property int tH2:      u(26)
    readonly property int tH3:      u(19)
    readonly property int tBodyL:   u(16)
    readonly property int tBody:    u(14)
    readonly property int tLabel:   u(12)
    readonly property int tMicro:   u(10)   // Versalien, gesperrt

    // Gewichte. Display läuft schwarz, Fließtext normal — dazwischen gibt es
    // in dieser Sprache fast nichts.
    readonly property int wDisplay: Font.Black
    readonly property int wTitle:   Font.Bold
    readonly property int wMed:     Font.Medium
    readonly property int wBody:    Font.Normal

    // Laufweite. Große Schrift läuft eng, winzige läuft weit — sonst wirkt
    // die Überschrift zerfasert und das Etikett wie ein Knoten.
    readonly property real lsDisplay: -1.6
    readonly property real lsTitle:   -0.5
    readonly property real lsMicro:    1.1

    // ==================================================================
    //  BEWEGUNG
    // ==================================================================
    readonly property int mFast: 140
    readonly property int mBase: 260
    readonly property int mSlow: 420
    readonly property int mIntro: 520
    readonly property int easeOut: Easing.OutExpo
    readonly property int easeSoft: Easing.OutCubic
    readonly property int easeBack: Easing.OutBack
    readonly property real backOvershoot: 0.45

    // ==================================================================
    //  LADEN — eigener FileView, unabhängig von Theme.qml. Beide hängen an
    //  derselben Datei; wer von beiden zuerst lädt, ist egal.
    // ==================================================================
    function applyJson(txt) {
        if (!txt || txt.trim() === "") return
        try {
            var c = JSON.parse(txt)
            // §99 „lumen" war der alte Name dieser Sprache. Eine
            // theme.json, die noch so heißt, darf nicht dazu führen, dass
            // das ganze System beim nächsten Start auf „modern"
            // zurückfällt — das sähe nach einem kaputten Update aus, und
            // die Datei liegt auf JEDEM Rechner, der das hier schon
            // benutzt hat. Der Altwert wird angenommen und still auf den
            // neuen übersetzt; geschrieben wird nur noch „noctis".
            if (c.skin === "lumen") root.skin = "noctis"
            else if (c.skin === "noctis" || c.skin === "modern" || c.skin === "classic")
                root.skin = c.skin
            if (c.mode === "light" || c.mode === "dark") root.mode = c.mode
            if (typeof c.accent === "string" && c.accent !== "") root.accentName = c.accent
            if (typeof c.accent_custom === "string") root.accentCustom = c.accent_custom
            // Derselbe Regler wie im bisherigen Look, aber auf den
            // Bereich dieser Sprache abgebildet: dort 0.35…1.0, hier 0.55…1.0. Unterhalb
            // von 0.55 wird aus Milchglas eine Folie, durch die man den
            // Schreibtisch liest — das hält diese Sprache nicht aus.
            if (typeof c.translucency === "number")
                root.glassAlpha = Math.max(0.55, Math.min(1.0, 0.55 + (c.translucency - 0.35) * 0.69))
            if (typeof c.radius === "number")
                root.uiRadius = Math.max(0.4, Math.min(1.6, c.radius))
        } catch (e) {
            // Kaputte Datei: beim letzten gültigen Stand bleiben.
        }
    }

    property FileView cfgFile: FileView {
        id: cfgFile
        path: Host.home + "/.config/noctis/theme.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.applyJson(cfgFile.text())
        onFileChanged: { cfgFile.reload(); root.applyJson(cfgFile.text()) }
    }

    property FileView matFile: FileView {
        id: matFile
        path: Host.home + "/.config/hypr/scripts/quickshell/qs_colors.json"
        watchChanges: true
        printErrors: false
        function pull() {
            var txt = matFile.text()
            if (!txt || txt.trim() === "") return
            try {
                var c = JSON.parse(txt)
                var next = {}
                for (var k in root.mat)
                    next[k] = (typeof c[k] === "string" && c[k] !== "") ? c[k] : root.mat[k]
                root.mat = next
            } catch (e) {}
        }
        onLoaded: pull()
        onFileChanged: { matFile.reload(); pull() }
    }
}
