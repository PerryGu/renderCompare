#ifndef FREEDVIEW_TESTER_RUNNER_H
#define FREEDVIEW_TESTER_RUNNER_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QMap>
#include <QQueue>

/**
 * @brief TesterRunner - launches freeDView_tester CLI commands
 *
 * Provides simple methods to run the Python-based tester for:
 *  - All phases
 *  - Compare only (Phase 3) followed by Phase 4 to refresh uiData.xml
 */
class TesterRunner : public QObject
{
    Q_OBJECT
public:
    explicit TesterRunner(QObject *parent = nullptr);
    ~TesterRunner();

    Q_INVOKABLE void runAll(const QString &testerPath, const QString &iniPath);
    Q_INVOKABLE void runCompareAndPrepare(const QString &testerPath, const QString &iniPath);
    Q_INVOKABLE void runPrepareUI(const QString &testerPath, const QString &iniPath);  // Run only Phase 4 (prepare-ui)
    Q_INVOKABLE void stop();  // Stop/cancel the currently running process

signals:
    void runStarted(const QString &mode);
    void runFinished(bool success, const QString &mode, int exitCode, const QString &stdOut, const QString &stdErr);
    void progressUpdated(int percentage, const QString &message);
    void testProgressUpdated(const QString &testKey, int percentage, const QString &message);  // Per-test progress
    void outputLine(const QString &line, bool isError);  // Emit each line of output in real-time

private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onPrepareUIProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    enum class Mode { None, All, CompareThenPrepare };
    void startProcess(const QString &program, const QStringList &args, const QString &workingDir);
    void runNextStep(); // for CompareThenPrepare chain
    QString extractTestKeyFromPath(const QString &folderPath);  // Extract test key from folder path
    QString findTestKeyByFrameCount(int frameCount);  // Find test key matching a frame count

    QProcess m_process;
    QProcess m_prepareUIProcess;  // Separate process for Phase 4 (can run in parallel)
    Mode m_mode;
    QString m_testerPath;
    QString m_iniPath;
    bool m_step2Queued;
    QString m_currentTestKey;  // Track current test being processed
    QMap<QString, int> m_activeTests;  // Map testKey -> total frame count
    QQueue<QString> m_testKeyQueue;  // Queue to track order of test starts
};

#endif // FREEDVIEW_TESTER_RUNNER_H

