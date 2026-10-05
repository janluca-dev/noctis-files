# Noctis Files

Der Dateimanager des Noctis-Systems, als **eigenständiges Programm** für Arch Linux.
Bis Oktober 2026 lief er nur als Quickshell-Konfiguration
(`~/.config/hypr/scripts/quickshell/NoctisFiles.qml`). Diese Fassung braucht weder
Quickshell noch die Noctis-Oberfläche: ein Paket bauen und installieren, dann läuft sie
auf jedem Arch-System, unter Wayland wie unter X11.

Raster und Liste, Detailspalte, Schnellansicht (Leertaste), Reiter, Favoriten, Papierkorb
mit Zurücklegen, Rückgängig, Suche, Packen und Entpacken, Laufwerke, Ziehen und Ablegen
nach draußen — und auf Wunsch die **Dateiauswahl des ganzen Systems** (XDG-Portal).

## Bauen und installieren

```bash
git clone https://github.com/janluca-dev/noctis-files.git
cd noctis-files/packaging/arch
makepkg -si
```

Danach liegt `noctis-files` im Starter. Aufruf von Hand:

```bash
noctis-files ~/Downloads
```

Läuft das Programm schon, öffnet ein zweiter Aufruf den Ordner als neuen Reiter im
vorhandenen Fenster.

## Als Standard-Dateimanager

```bash
xdg-mime default noctis-files.desktop inode/directory
```

## Als Dateidialog des Systems (optional, braucht `python-gobject`)

Das Paket bringt den Portal-Dienst mit, schaltet ihn aber **nicht** ein. Wer die
Dateiauswahl übernehmen soll, steht in `~/.config/xdg-desktop-portal/portals.conf`:

```ini
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=noctis
```

Danach `systemctl --user restart xdg-desktop-portal`. Zurück: die Zeile entfernen und
den Dienst neu starten.

## Aufbau

| Teil | Wo | Aufgabe |
|---|---|---|
| Wirt | `src/` (C++, Qt 6) | Fenster, Einzelinstanz, Zwischenablage; stellt `Process`, `FileView`, `StdioCollector`, `SplitParser` bereit — dieselben Bausteine wie Quickshell |
| Oberfläche | `qml/` | `Main.qml` (= `NoctisFiles.qml`), `filesapp/Fm*.qml`, `noctis/L*.qml`, `Noctis.qml` — ins Programm eingebacken |
| Rückgrat | `backend/fm_ctl.py` | rechnet alles: Listen, Arbeiten an Dateien, Vorschaubilder, Papierkorb |
| Portal | `backend/portal.py` + `data/portal/` | Dateidialog über das XDG-Portal |

Einstellungen: `~/.config/noctis/files.json` (dieselbe Datei wie die Quickshell-Fassung).
Erscheinungsbild: `~/.config/noctis/theme.json`, falls vorhanden; sonst folgt der Modus
dem Schreibtisch, und Milchglas gibt es nur unter Hyprland.

## Entwickeln

```bash
cmake -S . -B build -G Ninja -DNF_DEV_SOURCE_FALLBACK=ON && cmake --build build
NOCTIS_FILES_QML_DIR=$PWD/qml ./build/noctis-files     # QML direkt aus dem Quellbaum
```

Prüfen ohne Bildschirm:

```bash
QT_QPA_PLATFORM=offscreen NOCTIS_FILES_GRAB=/tmp/bild.png \
NOCTIS_FILES_GRAB_KEYS="ctrl+2,down" ./build/noctis-files ~/Dokumente
```

## Mit der Quickshell-Fassung abgleichen

Die Oberfläche ist eine Kopie. Ändert sich dort etwas, wird es hierher übernommen; die
Abweichungen sind im Quelltext mit `[eigenständig]` markiert (Fenster, Umgebung, Ruf von
außen, Zwischenablage, verzögerte Masken-Ebenen in `FmView.qml` und `LScroll.qml`).
