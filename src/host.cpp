#include "host.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocalSocket>
#include <QMimeData>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

#include <unistd.h>

#ifndef NOCTIS_FILES_VERSION
#define NOCTIS_FILES_VERSION "dev"
#endif

Host::Host(QObject *parent) : QObject(parent)
{
    // Wo das Rückgrat liegt. Reihenfolge: ausdrücklich gesetzt, neben dem
    // Programm installiert, am Einbauort, im Quellbaum (beim Entwickeln).
    QStringList tries;
    const QString forced = qEnvironmentVariable("NOCTIS_FILES_CTL");
    if (!forced.isEmpty()) tries << forced;
    tries << QCoreApplication::applicationDirPath() + "/../lib/noctis-files/fm_ctl.py";
#ifdef NOCTIS_FILES_LIBDIR
    tries << QStringLiteral(NOCTIS_FILES_LIBDIR "/fm_ctl.py");
#endif
#ifdef NOCTIS_FILES_SRCDIR
    tries << QStringLiteral(NOCTIS_FILES_SRCDIR "/backend/fm_ctl.py");
#endif
    for (const QString &t : std::as_const(tries)) {
        if (QFileInfo::exists(t)) { m_ctl = QFileInfo(t).canonicalFilePath(); break; }
    }
    if (m_ctl.isEmpty()) qWarning("Noctis Files: fm_ctl.py nicht gefunden — gesucht in %s",
                                  qPrintable(tries.join(", ")));

    m_python = QStandardPaths::findExecutable(QStringLiteral("python3"));
    if (m_python.isEmpty()) m_python = QStringLiteral("python3");
}

QString Host::home() const { return QDir::homePath(); }

QString Host::version() const { return QStringLiteral(NOCTIS_FILES_VERSION); }

QString Host::env(const QString &name) const { return qEnvironmentVariable(qPrintable(name)); }

// Milchglas braucht einen Compositor, der hinter durchsichtigen Fenstern
// weichzeichnet. Hyprland tut das von sich aus; anderswo sähe man durch die
// Scheibe nur den Schreibtisch, scharf — und das liest sich schlechter als
// eine deckende Fläche.
bool Host::compositorBlur() const
{
    return !qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE").isEmpty();
}

// ---------------------------------------------------------------------------
//  Einzelinstanz
// ---------------------------------------------------------------------------
QString Host::socketPath()
{
    QString dir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (dir.isEmpty()) dir = QDir::tempPath();
    return dir + QStringLiteral("/noctis-files-%1.sock").arg(getuid());
}

bool Host::claim(const QString &path)
{
    const QString name = socketPath();
    {
        QLocalSocket s;
        s.connectToServer(name);
        if (s.waitForConnected(400)) {
            s.write((path + "\n").toUtf8());
            s.flush();
            s.waitForBytesWritten(400);
            s.disconnectFromServer();
            return false;
        }
    }
    // Niemand hört zu: eine liegengebliebene Steckdose von einem
    // abgestürzten Lauf darf den Start nicht blockieren.
    QLocalServer::removeServer(name);
    m_server = new QLocalServer(this);
    m_server->setSocketOptions(QLocalServer::UserAccessOption);
    if (!m_server->listen(name))
        qWarning("Noctis Files: %s lässt sich nicht öffnen (%s)", qPrintable(name),
                 qPrintable(m_server->errorString()));
    connect(m_server, &QLocalServer::newConnection, this, &Host::onConnection);
    return true;
}

void Host::onConnection()
{
    while (QLocalSocket *c = m_server->nextPendingConnection()) {
        connect(c, &QLocalSocket::disconnected, c, &QObject::deleteLater);
        connect(c, &QLocalSocket::readyRead, this, [this, c] {
            while (c->canReadLine()) {
                const QString p = QString::fromUtf8(c->readLine()).trimmed();
                emit openRequested(p);
                raiseWindow();
            }
        });
    }
}

void Host::raiseWindow()
{
    if (!m_window) return;
    // Nur zeigen, was nicht zu sehen ist. show() an einem sichtbaren Fenster
    // setzt den Zustand neu — und Hyprland meldet ein gekacheltes Fenster
    // als „maximiert", das Fenster fragte daraufhin selbst nach Vollbild.
    if (!m_window->isVisible()) m_window->show();
    else if (m_window->windowState() & Qt::WindowMinimized) m_window->showNormal();
    m_window->raise();
    m_window->requestActivate();
    // Unter Wayland darf ein Programm sich nicht selbst nach vorn holen —
    // das entscheidet der Compositor. Hyprland lässt sich fragen.
    if (!qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE").isEmpty()
            && !QStandardPaths::findExecutable(QStringLiteral("hyprctl")).isEmpty()) {
        QProcess::startDetached(QStringLiteral("hyprctl"),
            { QStringLiteral("dispatch"), QStringLiteral("focuswindow"),
              QStringLiteral("pid:%1").arg(QCoreApplication::applicationPid()) });
    }
}

// ---------------------------------------------------------------------------
//  Zwischenablage
// ---------------------------------------------------------------------------
bool Host::hasWlCopy() const
{
    return QGuiApplication::platformName().startsWith(QLatin1String("wayland"))
        && !QStandardPaths::findExecutable(QStringLiteral("wl-copy")).isEmpty();
}

// Dateien werden in drei Formen angeboten, damit jedes Gegenüber seine
// findet: die GNOME-Form (Verb + Adressen, liest fast jeder Dateimanager),
// die KDE-Markierung für „ausgeschnitten" und die schlichte Adressliste.
void Host::copyFiles(const QString &mode, const QStringList &paths)
{
    QList<QUrl> urls;
    QStringList lines;
    for (const QString &p : paths) {
        const QUrl u = QUrl::fromLocalFile(QFileInfo(p).absoluteFilePath());
        urls << u;
        lines << QString::fromUtf8(u.toEncoded());
    }
    auto *md = new QMimeData;
    md->setUrls(urls);
    md->setText(paths.join('\n'));
    const QString verb = mode == QLatin1String("cut") ? QStringLiteral("cut") : QStringLiteral("copy");
    md->setData(QStringLiteral("x-special/gnome-copied-files"), (verb + "\n" + lines.join('\n')).toUtf8());
    md->setData(QStringLiteral("application/x-kde-cutselection"), verb == QLatin1String("cut") ? "1" : "0");
    QGuiApplication::clipboard()->setMimeData(md);
}

// Ein Pfad als Text soll das Fenster überleben — man merkt ihn sich, um ihn
// gleich im Terminal einzufügen, und das Fenster ist dann oft schon zu. Qt
// gibt die Ablage beim Beenden zurück; wl-copy hält sie fest.
void Host::copyText(const QStringList &lines)
{
    const QString t = lines.join('\n');
    if (hasWlCopy()) {
        auto *p = new QProcess(this);
        connect(p, &QProcess::finished, p, &QObject::deleteLater);
        connect(p, &QProcess::errorOccurred, p, &QObject::deleteLater);
        p->start(QStringLiteral("wl-copy"), {});
        p->write(t.toUtf8());
        p->closeWriteChannel();
        return;
    }
    QGuiApplication::clipboard()->setText(t);
}

QVariantMap Host::pasteFiles()
{
    QVariantMap r;
    QString mode;
    QStringList paths;
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    if (md) {
        const QByteArray g = md->data(QStringLiteral("x-special/gnome-copied-files"));
        if (!g.isEmpty()) {
            const QList<QByteArray> ls = g.split('\n');
            mode = QString::fromUtf8(ls.value(0)).trimmed();
            for (int i = 1; i < ls.size(); i++) {
                const QUrl u = QUrl::fromEncoded(ls[i].trimmed());
                if (u.isLocalFile()) paths << u.toLocalFile();
            }
        } else if (md->hasUrls()) {
            const QByteArray kde = md->data(QStringLiteral("application/x-kde-cutselection"));
            mode = kde.trimmed() == "1" ? QStringLiteral("cut") : QStringLiteral("copy");
            for (const QUrl &u : md->urls())
                if (u.isLocalFile()) paths << u.toLocalFile();
        }
    }
    r.insert(QStringLiteral("mode"), mode);
    r.insert(QStringLiteral("paths"), paths);
    return r;
}
