// ============================================================================
//  FmKind.js — von der Art einer Datei zu ihrem Zeichen und ihrem Ton.
//
//  Das Skript liefert die ART („image", „code", „archive"), diese Datei
//  entscheidet, wie sie AUSSIEHT. Die Trennung ist Absicht: welche Endung
//  ein Bild ist, ist eine Tatsache und gehört ins Skript; welches Zeichen
//  ein Bild bekommt, ist Gestaltung und gehört hierher.
//
//  ZEICHEN STEHEN ALS ZAHL, NICHT ALS ZEICHEN. Die Nerd-Font-Symbole liegen
//  im privaten Bereich von Unicode. Kopiert man eine solche Datei durch ein
//  Werkzeug, das davon nichts weiß, kommen sie als Fragezeichen wieder an —
//  und dann steht in jeder Zeile des Dateimanagers ein leeres Kästchen. Als
//  Zahl geschrieben kann das nicht passieren, und nebenbei steht neben jeder
//  Zahl der Name des Symbols.
//
//  Zu den Farben: LIconTile tönt seine Fläche immer mit der Symbolfarbe bei
//  sehr wenig Deckkraft. Deshalb dürfen hier zwanzig Töne stehen, ohne dass
//  ein Ordner bunt wird — nebeneinander sind es zwanzig sehr blasse Flächen,
//  und nur das Symbol selbst trägt die Farbe. Wer einmal einen Ordner voller
//  Bilder, Filme und Archive gesehen hat, weiß, dass die Farbe dort schneller
//  liest als der Name.
// ============================================================================
.pragma library

function g(cp) { return String.fromCodePoint(cp) }

// --- die Zeichen der Oberfläche ------------------------------------------
var UI = {
    back:      g(0xF0141),   // chevron-left
    fwd:       g(0xF0142),   // chevron-right
    up:        g(0xF005D),   // arrow-up
    down:      g(0xF0140),   // chevron-down
    upSmall:   g(0xF0143),   // chevron-up
    home:      g(0xF02DC),
    refresh:   g(0xF0450),
    search:    g(0xF0349),
    close:     g(0xF0156),
    cog:       g(0xF0493),
    grid:      g(0xF0570),
    list:      g(0xF0572),
    sort:      g(0xF04BA),
    plus:      g(0xF0415),
    copy:      g(0xF018F),
    cut:       g(0xF0190),
    paste:     g(0xF0191),
    pencil:    g(0xF03EB),
    info:      g(0xF02FC),
    openNew:   g(0xF03CC),
    link:      g(0xF0337),
    eye:       g(0xF0208),
    eyeOff:    g(0xF0209),
    trash:     g(0xF0A79),
    burn:      g(0xF01B4),   // endgültig löschen
    star:      g(0xF04CE),
    starOff:   g(0xF04D2),
    disk:      g(0xF02CA),
    folder:    g(0xF024B),
    folderOpen:g(0xF0770),
    folderNew: g(0xF0257),
    fileNew:   g(0xF0752),
    term:      g(0xF018D),
    dots:      g(0xF01D8),
    check:     g(0xF012C),
    alert:     g(0xF0028),
    expand:    g(0xF0293),
    collapse:  g(0xF0294),
    pane:      g(0xF0C99),   // Auskunftsspalte ein/aus
    tree:      g(0xF0645),
    clock:     g(0xF0996),
    eject:     g(0xF0552),
    zip:       g(0xF05C4),
    restore:   g(0xF0453),   // im Kreis zurück
    palette:   g(0xF0E0C),
    image:     g(0xF02E9),
    share:     g(0xF0A1F),
    duplicate: g(0xF0222)   // Blatt auf Blatt
}

// --- die Zeichen der Dateiarten ------------------------------------------
var ICONS = {
    folder:   g(0xF024B),
    image:    g(0xF021F),   // file-image
    video:    g(0xF022B),   // file-video
    audio:    g(0xF0387),   // Note
    pdf:      g(0xF0226),
    doc:      g(0xF0219),
    sheet:    g(0xF021B),
    slides:   g(0xF0219),
    book:     g(0xF05DA),
    archive:  g(0xF05C4),
    package:  g(0xF01A6),   // Würfel
    disk:     g(0xF0025),   // Scheibe
    font:     g(0xF0B34),   // Aa
    code:     g(0xF022E),   // file-code
    markup:   g(0xF0169),   // { }
    text:     g(0xF0219),
    key:      g(0xF0306),
    torrent:  g(0xF01DA),
    exe:      g(0xF018D),
    broken:   g(0xF0028),
    other:    g(0xF0214)
}

var TONES = {
    folder:   "",           // leer heißt: nimm den Akzent des Systems
    image:    "#34d399",
    video:    "#fb7185",
    audio:    "#a970ff",
    pdf:      "#f0603a",
    doc:      "#3b82f6",
    sheet:    "#2fd47a",
    slides:   "#f0a33a",
    book:     "#c47a4a",
    archive:  "#fbbf24",
    package:  "#d98200",
    disk:     "#8aa0b8",
    font:     "#e8306f",
    code:     "#22d3ee",
    markup:   "#8b5cf6",
    text:     "#8b8b95",
    key:      "#ffb020",
    torrent:  "#4cc9a0",
    exe:      "#34d0e8",
    broken:   "#ff5a4d",
    other:    "#8b8b95"
}

// Ein paar Endungen verdienen ein eigenes Zeichen, weil man sie im
// Vorbeigehen erkennt.
var BY_EXT = {
    "sh":   g(0xF018D),
    "bash": g(0xF018D),
    "zsh":  g(0xF018D),
    "fish": g(0xF018D),
    "json": g(0xF0169),
    "yaml": g(0xF0169),
    "yml":  g(0xF0169),
    "toml": g(0xF0169),
    "desktop": g(0xF0570),
    "iso":  g(0xF0025),
    "svg":  g(0xF02E9),
    "log":  g(0xF0219)
}

// --- die Orte der Seitenleiste -------------------------------------------
//
//  Eigene Zuordnung, weil ein Ort nicht dasselbe ist wie eine Dateiart:
//  „Bilder" ist ein Ordner und trägt trotzdem das Bildzeichen, „Downloads"
//  trägt den Pfeil nach unten. Das ist der ganze Trick an einer
//  Seitenleiste, die man nicht lesen muss.
var PLACE = {
    home:      UI.home,
    desktop:   g(0xF0379),   // Bildschirm
    download:  g(0xF01DA),   // Pfeil nach unten
    doc:       ICONS.doc,
    image:     ICONS.image,
    audio:     ICONS.audio,
    video:     ICONS.video
}

var PLACE_TONE = {
    home:     "",            // leer heißt: der Akzent des Systems
    desktop:  "#8aa0b8",
    download: "#4cc9a0",
    doc:      TONES.doc,
    image:    TONES.image,
    audio:    TONES.audio,
    video:    TONES.video
}

function placeIcon(k) {
    return PLACE[k] !== undefined ? PLACE[k] : ICONS.folder
}

function placeTone(k, accent) {
    var t = PLACE_TONE[k]
    if (t === undefined) return accent
    return t === "" ? accent : t
}

function icon(kind, ext) {
    if (ext && BY_EXT[ext] !== undefined) return BY_EXT[ext]
    return ICONS[kind] !== undefined ? ICONS[kind] : ICONS.other
}

function tone(kind, accent) {
    var t = TONES[kind]
    if (t === undefined) return TONES.other
    return t === "" ? accent : t
}

// Die deutschen Bezeichnungen. Sie stehen in der Fußzeile und in der
// Auskunftsspalte — „code" wäre dort keine Auskunft.
var LABELS = {
    folder: "Ordner", image: "Bild", video: "Film", audio: "Ton",
    pdf: "PDF", doc: "Dokument", sheet: "Tabelle", slides: "Präsentation",
    book: "Buch", archive: "Archiv", package: "Paket", disk: "Abbild",
    font: "Schrift", code: "Quelltext", markup: "Auszeichnung",
    text: "Text", key: "Schlüssel", torrent: "Torrent",
    exe: "Programm", broken: "Kaputte Verknüpfung", other: "Datei"
}

function label(kind, ext) {
    var l = LABELS[kind] !== undefined ? LABELS[kind] : LABELS.other
    if (kind === "folder" || !ext) return l
    // „PDF · PDF" hat noch nie jemandem geholfen: sagt die Endung dasselbe
    // wie die Art, reicht eines von beiden.
    var e = ext.toUpperCase()
    return e === l.toUpperCase() ? l : l + " · " + e
}

// Größen in der Schreibweise des Systems: Komma als Dezimalzeichen.
function size(n) {
    if (n === null || n === undefined) return ""
    if (n < 1000) return n + " B"
    var u = ["kB", "MB", "GB", "TB", "PB"]
    var f = n / 1000.0, i = 0
    while (f >= 1000 && i < u.length - 1) { f /= 1000.0; i++ }
    return (f >= 100 ? Math.round(f).toString()
                     : f.toFixed(1)).replace(".", ",") + " " + u[i]
}

// „heute 14:20", „gestern 09:05", „12. Mär 2024" — ein Datum muss man lesen
// können, ohne zu rechnen.
var MON = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
           "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

function when(unix, longForm) {
    if (!unix) return ""
    var d = new Date(unix * 1000)
    var now = new Date()
    var hm = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2)
    var t0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    var dd = d.getTime()
    if (dd >= t0) return longForm ? "Heute, " + hm : "heute " + hm
    if (dd >= t0 - 86400000) return longForm ? "Gestern, " + hm : "gestern " + hm
    var s = d.getDate() + ". " + MON[d.getMonth()]
    if (d.getFullYear() !== now.getFullYear()) s += " " + d.getFullYear()
    return longForm ? s + ", " + hm : s
}

function duration(sec) {
    if (!sec) return ""
    sec = Math.round(sec)
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
    if (h > 0) return h + ":" + ("0" + m).slice(-2) + ":" + ("0" + s).slice(-2)
    return m + ":" + ("0" + s).slice(-2)
}

// Pfad zu Adresse. encodeURI() allein reicht NICHT: es lässt „#" stehen, und
// eine Datei „Plan #3.pdf" käme beim Ziel als „Plan " an. Deshalb Stück für
// Stück, und die Schrägstriche bleiben, was sie sind.
function toUri(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
}

function fromUri(uri) {
    var u = uri.toString()
    if (u.indexOf("file://") === 0) u = u.substring(7)
    return decodeURIComponent(u)
}
