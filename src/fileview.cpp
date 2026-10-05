#include "fileview.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>

FileView::FileView(QObject *parent) : QObject(parent)
{
    // Ein Speichern besteht oft aus mehreren Schritten (anlegen, schreiben,
    // umbenennen). Gemeldet wird einmal, wenn es vorbei ist.
    m_settle.setSingleShot(true);
    m_settle.setInterval(60);
    connect(&m_settle, &QTimer::timeout, this, [this] {
        rewatch();
        emit fileChanged();
    });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_settle.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
        // Der Ordner meldet jede Änderung irgendeiner Datei darin. Interessant
        // ist nur, ob UNSERE Datei dabei neu entstanden oder ersetzt worden ist.
        if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path)) m_settle.start();
    });
}

void FileView::componentComplete()
{
    m_complete = true;
    rewatch();
    load();
}

void FileView::setPath(const QString &p)
{
    if (p == m_path) return;
    m_path = p;
    emit pathChanged();
    if (!m_complete) return;
    rewatch();
    load();
}

void FileView::setWatchChanges(bool w)
{
    if (w == m_watch) return;
    m_watch = w;
    emit watchChangesChanged();
    if (m_complete) rewatch();
}

bool FileView::read()
{
    if (m_path.isEmpty()) { m_data.clear(); return false; }
    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly)) {
        m_data.clear();
        return false;
    }
    m_data = f.readAll();
    return true;
}

void FileView::load()
{
    if (m_path.isEmpty()) return;
    if (read()) {
        emit loaded();
    } else {
        if (m_printErrors) qWarning("FileView: %s lässt sich nicht lesen", qPrintable(m_path));
        emit loadFailed(QStringLiteral("unreadable"));
    }
}

void FileView::reload()
{
    read();
}

void FileView::setText(const QString &t)
{
    if (m_path.isEmpty()) return;
    const QByteArray bytes = t.toUtf8();
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    bool ok = false;
    if (m_atomicWrites) {
        QSaveFile f(m_path);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(bytes);
            ok = f.commit();
        }
    } else {
        QFile f(m_path);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            ok = f.write(bytes) == bytes.size();
            f.flush();
        }
    }
    if (ok) m_data = bytes;
    else if (m_printErrors) qWarning("FileView: %s lässt sich nicht schreiben", qPrintable(m_path));
}

void FileView::rewatch()
{
    const QStringList fs = m_watcher.files(), ds = m_watcher.directories();
    if (!fs.isEmpty()) m_watcher.removePaths(fs);
    if (!ds.isEmpty()) m_watcher.removePaths(ds);
    if (!m_watch || m_path.isEmpty()) return;
    const QString dir = QFileInfo(m_path).absolutePath();
    if (QFileInfo::exists(dir)) m_watcher.addPath(dir);
    if (QFileInfo::exists(m_path)) m_watcher.addPath(m_path);
}
