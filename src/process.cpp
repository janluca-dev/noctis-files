#include "process.h"

#include <QFileInfo>
#include <csignal>

// ---------------------------------------------------------------------------
//  StdioCollector
// ---------------------------------------------------------------------------
void StdioCollector::begin()
{
    if (m_buf.isEmpty()) return;
    m_buf.clear();
    emit textChanged();
}

void StdioCollector::end()
{
    emit textChanged();
    emit streamFinished();
}

// ---------------------------------------------------------------------------
//  SplitParser
// ---------------------------------------------------------------------------
void SplitParser::setSplitMarker(const QString &m)
{
    if (m == m_marker) return;
    m_marker = m;
    emit splitMarkerChanged();
}

void SplitParser::feed(const QByteArray &data)
{
    m_buf.append(data);
    const QByteArray mark = m_marker.isEmpty() ? QByteArrayLiteral("\n") : m_marker.toUtf8();
    qsizetype at;
    // Jede Meldung kann eine neue Ausgabe auslösen, die wieder hier landet —
    // deshalb wird das Stück erst herausgeschnitten und dann gemeldet.
    while ((at = m_buf.indexOf(mark)) >= 0) {
        const QByteArray piece = m_buf.left(at);
        m_buf.remove(0, at + mark.size());
        emit read(QString::fromUtf8(piece));
    }
}

void SplitParser::end()
{
    // Was ohne Zeilenende übrig bleibt, ist trotzdem eine Zeile.
    if (!m_buf.isEmpty()) {
        const QByteArray rest = m_buf;
        m_buf.clear();
        emit read(QString::fromUtf8(rest));
    }
}

// ---------------------------------------------------------------------------
//  Process
// ---------------------------------------------------------------------------
Process::Process(QObject *parent) : QObject(parent) {}

Process::~Process()
{
    // Ein Kind, das sein Fenster überlebt, ist genau die Leiche, die der
    // Starter der Quickshell-Fassung erst finden und abschießen musste.
    if (m_proc) {
        m_proc->disconnect(this);
        m_proc->kill();
        m_proc->waitForFinished(300);
        delete m_proc;
        m_proc = nullptr;
    }
}

void Process::setCommand(const QVariantList &c)
{
    if (c == m_command) return;
    m_command = c;
    emit commandChanged();
}

void Process::setRunning(bool r)
{
    if (r == m_running) return;
    if (r) start();
    else stop();
}

void Process::setStdinEnabled(bool s)
{
    if (s == m_stdin) return;
    m_stdin = s;
    if (!s && m_proc) m_proc->closeWriteChannel();
    emit stdinEnabledChanged();
}

void Process::setStdoutParser(DataStreamParser *p)
{
    if (p == m_stdout) return;
    m_stdout = p;
    emit stdoutChanged();
}

void Process::setWorkingDirectory(const QString &d)
{
    if (d == m_cwd) return;
    m_cwd = d;
    emit workingDirectoryChanged();
}

void Process::start()
{
    QStringList argv;
    for (const QVariant &v : std::as_const(m_command)) argv << v.toString();
    if (argv.isEmpty() || argv.first().isEmpty()) {
        qWarning("Process: leerer Befehl, nichts gestartet");
        return;
    }

    auto *p = new QProcess(this);
    m_proc = p;
    p->setProgram(argv.takeFirst());
    p->setArguments(argv);
    if (!m_cwd.isEmpty()) p->setWorkingDirectory(m_cwd);
    // Fehlermeldungen der Kinder landen im eigenen stderr: dort, wo man sie
    // beim Starten aus dem Terminal auch sucht.
    p->setProcessChannelMode(QProcess::ForwardedErrorChannel);

    if (m_stdout) m_stdout->begin();

    connect(p, &QProcess::readyReadStandardOutput, this, [this, p] {
        const QByteArray d = p->readAllStandardOutput();
        if (m_stdout && p == m_proc) m_stdout->feed(d);
    });
    connect(p, &QProcess::finished, this, [this, p](int code, QProcess::ExitStatus st) {
        onFinished(p, code, st);
    });
    connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {
            qWarning("Process: %s ließ sich nicht starten", qPrintable(p->program()));
            onFinished(p, -1, QProcess::CrashExit);
        }
    });

    m_running = true;
    p->start();
    if (m_proc != p) return;          // gar nicht erst angelaufen
    if (!m_stdin) p->closeWriteChannel();
    emit runningChanged();
    emit started();
}

void Process::stop()
{
    if (!m_proc) {
        m_running = false;
        emit runningChanged();
        return;
    }
    // Erst höflich, dann bestimmt.
    QProcess *p = m_proc;
    p->terminate();
    if (!p->waitForFinished(400)) {
        p->kill();
        p->waitForFinished(200);
    }
}

void Process::onFinished(QProcess *p, int code, QProcess::ExitStatus st)
{
    if (p != m_proc) return;
    // Was noch im Puffer liegt, gehört zu diesem Lauf.
    const QByteArray rest = p->readAllStandardOutput();
    if (m_stdout) {
        if (!rest.isEmpty()) m_stdout->feed(rest);
        m_stdout->end();
    }
    m_proc = nullptr;
    p->disconnect(this);
    p->deleteLater();

    m_running = false;
    emit runningChanged();
    emit exited(code, st == QProcess::NormalExit ? 0 : 1);
}

void Process::write(const QString &data)
{
    if (!m_proc || !m_stdin) return;
    m_proc->write(data.toUtf8());
}

void Process::signal(int sig)
{
    if (!m_proc) return;
    const qint64 pid = m_proc->processId();
    if (pid > 0) ::kill(static_cast<pid_t>(pid), sig);
}
