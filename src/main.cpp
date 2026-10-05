// ============================================================================
//  Noctis Files — das eigenständige Programm.
//
//  Bis Oktober 2026 lief Noctis Files als Quickshell-Konfiguration: eine
//  QML-Datei, die `quickshell -p` gestartet hat. Das ging nur auf einem
//  System, auf dem die ganze Noctis-Oberfläche liegt. Diese Datei ersetzt
//  Quickshell durch einen eigenen, kleinen Wirt — die Oberfläche selbst ist
//  dieselbe, Baustein für Baustein.
//
//  Aufruf:
//      noctis-files [ORDNER|DATEI|file://…]
//
//  Läuft schon ein Fenster, bekommt es den Ordner als neuen Reiter und wird
//  nach vorn geholt; dieser Aufruf endet dann sofort.
// ============================================================================
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QKeyEvent>
#include <QKeySequence>
#include <QQuickItem>
#include <QTimer>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QUrl>

#include <cstdio>

#include "fileview.h"
#include "host.h"
#include "process.h"

#ifndef NOCTIS_FILES_VERSION
#define NOCTIS_FILES_VERSION "dev"
#endif

static QString resolveTarget(const QString &arg)
{
    if (arg.isEmpty()) return {};
    QString p = arg;
    if (p.startsWith(QLatin1String("file:"))) p = QUrl(p).toLocalFile();
    else if (p == QLatin1String("~")) p = QDir::homePath();
    else if (p.startsWith(QLatin1String("~/"))) p = QDir::homePath() + p.mid(1);
    QFileInfo fi(p);
    if (!fi.exists()) return {};
    // Eine Datei öffnet ihren Ordner — so taugt das Programm auch als Ziel
    // von „Im Ordner zeigen".
    if (!fi.isDir()) fi = QFileInfo(fi.absolutePath());
    return fi.canonicalFilePath();
}

static void loadFonts()
{
    QStringList dirs;
    const QString forced = qEnvironmentVariable("NOCTIS_FILES_DATADIR");
    if (!forced.isEmpty()) dirs << forced + "/fonts";
    dirs << QCoreApplication::applicationDirPath() + "/../share/noctis-files/fonts";
#ifdef NOCTIS_FILES_DATADIR
    dirs << QStringLiteral(NOCTIS_FILES_DATADIR "/fonts");
#endif
#ifdef NOCTIS_FILES_SRCDIR
    dirs << QStringLiteral(NOCTIS_FILES_SRCDIR "/data/fonts");
#endif
    // Outfit trägt die Handschrift von Noctis. Ist sie systemweit schon da
    // (wie auf Jans Rechner), schadet die zweite Anmeldung nicht.
    for (const QString &d : std::as_const(dirs)) {
        const QString f = d + "/Outfit.ttf";
        if (QFileInfo::exists(f)) {
            if (QFontDatabase::addApplicationFont(f) < 0)
                qWarning("Noctis Files: %s ließ sich nicht laden", qPrintable(f));
            return;
        }
    }
    qWarning("Noctis Files: Outfit.ttf nicht gefunden, es greift die Ersatzschrift");
}

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; i++) {
        const QByteArray a(argv[i]);
        if (a == "--version" || a == "-v") {
            std::printf("noctis-files %s\n", NOCTIS_FILES_VERSION);
            return 0;
        }
        if (a == "--help" || a == "-h") {
            std::printf("Aufruf: noctis-files [ORDNER|DATEI|file://…]\n\n"
                        "Öffnet Noctis Files. Läuft es schon, öffnet das vorhandene\n"
                        "Fenster den Ordner in einem neuen Reiter.\n");
            return 0;
        }
    }

    // Milchglas: das Fenster muss durchsichtig sein dürfen, sonst malt der
    // Compositor unter die halbdeckende Scheibe Schwarz.
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("noctis-files"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Noctis Files"));
    QGuiApplication::setApplicationVersion(QStringLiteral(NOCTIS_FILES_VERSION));
    // Ergibt unter Wayland die app_id und damit das Symbol in Leisten und
    // Docks — es muss zum Namen der .desktop-Datei passen.
    QGuiApplication::setDesktopFileName(QStringLiteral("noctis-files"));

    QString target;
    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); i++) {
        if (args[i].startsWith('-')) continue;
        target = resolveTarget(args[i]);
        if (!target.isEmpty()) break;
    }

    auto *host = new Host(&app);
    host->setStartPath(target);

    // Der Dateidialog (siehe portal.py) ist jedes Mal ein eigenes Fenster
    // mit eigener Frage — der darf sich nicht an ein offenes Hauptfenster
    // hängen, sonst bekäme das fragende Programm nie eine Antwort.
    const bool pickMode = !qEnvironmentVariable("NOCTIS_PICK_REQUEST").isEmpty();
    if (!pickMode && !host->claim(target)) return 0;

    loadFonts();

    qmlRegisterUncreatableType<DataStreamParser>("NoctisHost", 1, 0, "DataStreamParser",
                                                 QStringLiteral("abstrakt"));
    qmlRegisterType<Process>("NoctisHost", 1, 0, "Process");
    qmlRegisterType<StdioCollector>("NoctisHost", 1, 0, "StdioCollector");
    qmlRegisterType<SplitParser>("NoctisHost", 1, 0, "SplitParser");
    qmlRegisterType<FileView>("NoctisHost", 1, 0, "FileView");
    qmlRegisterSingletonInstance("NoctisHost", 1, 0, "Host", host);

    QQmlApplicationEngine engine;
    // Beim Entwickeln die Oberfläche direkt aus dem Quellbaum laden — dann
    // reicht ein Neustart, kein Neubau.
    const QString qmlDir = qEnvironmentVariable("NOCTIS_FILES_QML_DIR");
    const QUrl main = qmlDir.isEmpty()
        ? QUrl(QStringLiteral("qrc:/qml/Main.qml"))
        : QUrl::fromLocalFile(qmlDir + "/Main.qml");

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(main);
    if (engine.rootObjects().isEmpty()) return 1;
    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!win) return 1;
    host->setWindow(win);
    // Die Inhaltsfläche bekommt ihre Größe sonst erst beim Anzeigen, mitten
    // in der Antwort des Compositors. Bis dahin ist sie 0×0, und beim
    // Aufziehen schalten Masken-Ebenen (layer.enabled hängt am Rollen) um,
    // während Qt noch die Beobachter derselben Größenänderung abarbeitet —
    // Absturz in QQuickShaderEffectSource. Quickshell setzt die Größe vor dem
    // ersten Bild; hier passiert dasselbe von Hand.
    win->contentItem()->setSize(win->size());
    win->show();

    // Zum Prüfen ohne Bildschirm (QT_QPA_PLATFORM=offscreen): nach einer
    // Weile ein Bild des Fensters ablegen und beenden. Optional vorher eine
    // Tastenfolge in die Fläche schicken, z. B. "ctrl+i,down,down,space".
    const QString grab = qEnvironmentVariable("NOCTIS_FILES_GRAB");
    if (!grab.isEmpty()) {
        const int wait = qEnvironmentVariableIntValue("NOCTIS_FILES_GRAB_MS");
        const QStringList keys = qEnvironmentVariable("NOCTIS_FILES_GRAB_KEYS")
                                     .split(',', Qt::SkipEmptyParts);
        int t = 1500;
        for (const QString &k : keys) {
            QTimer::singleShot(t, win, [win, k] {
                const QKeySequence seq(k, QKeySequence::PortableText);
                if (seq.isEmpty()) return;
                const QKeyCombination c = seq[0];
                QString txt;
                if (c.keyboardModifiers() == Qt::NoModifier && c.key() >= Qt::Key_Space
                        && c.key() <= Qt::Key_AsciiTilde)
                    txt = QString(QChar(int(c.key()))).toLower();
                if (c.key() == Qt::Key_Space) txt = QStringLiteral(" ");
                QKeyEvent press(QEvent::KeyPress, c.key(), c.keyboardModifiers(), txt);
                QKeyEvent release(QEvent::KeyRelease, c.key(), c.keyboardModifiers(), txt);
                QCoreApplication::sendEvent(win, &press);
                QCoreApplication::sendEvent(win, &release);
            });
            t += 450;
        }
        QTimer::singleShot(t + (wait > 0 ? wait : 1500), win, [win, grab] {
            win->grabWindow().save(grab);
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
