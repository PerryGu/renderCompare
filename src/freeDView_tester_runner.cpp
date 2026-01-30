#include "freeDView_tester_runner.h"
#include "logger.h"
#include <QDir>
#include <QFileInfo>
#include <QTextStream>
#include <QStandardPaths>

TesterRunner::TesterRunner(QObject *parent)
    : QObject(parent),
      m_mode(Mode::None),
      m_step2Queued(false),
      m_currentTestKey("")
{
    connect(&m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &TesterRunner::onProcessFinished);
    connect(&m_prepareUIProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &TesterRunner::onPrepareUIProcessFinished);
}

void TesterRunner::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    // Read any remaining output
    const QString stdOut = QString::fromLocal8Bit(m_process.readAllStandardOutput());
    const QString stdErr = QString::fromLocal8Bit(m_process.readAllStandardError());
    
    // Ensure process is properly closed
    if (m_process.state() != QProcess::NotRunning) {
        DEBUG_LOG("TesterRunner") << "Process not fully stopped, waiting...";
        m_process.waitForFinished(1000);  // Wait up to 1 second
    }
    
    // Don't auto-complete all tests - only complete tests that actually finished
    // Individual test completions are handled by "Successfully completed comparison for:" messages
    // Just clear the tracking data here
    m_activeTests.clear();
    m_testKeyQueue.clear();
    m_currentTestKey.clear();
    
    // Emit final progress update
    emit progressUpdated(100, "Processing completed");

    if (m_mode == Mode::CompareThenPrepare && !m_step2Queued) {
        // Step 1 finished (compare) - queue step 2 (prepare-ui)
        m_step2Queued = true;
        runNextStep();
        return;
    }

    const bool success = (exitStatus == QProcess::NormalExit && exitCode == 0);
    const QString modeStr = (m_mode == Mode::All) ? "all" :
                            (m_mode == Mode::CompareThenPrepare ? "compare+prepare" : "unknown");
    emit runFinished(success, modeStr, exitCode, stdOut, stdErr);
    m_mode = Mode::None;
    m_step2Queued = false;
}

TesterRunner::~TesterRunner() {}

void TesterRunner::stop()
{
    // Stop main test process
    if (m_process.state() == QProcess::Running || m_process.state() == QProcess::Starting) {
        DEBUG_LOG("TesterRunner") << "Stopping test process...";
        // Kill the process immediately
        m_process.kill();
        // Wait for it to terminate (with timeout)
        if (!m_process.waitForFinished(2000)) {
            DEBUG_LOG("TesterRunner") << "Process did not terminate, forcing kill";
            m_process.kill();  // Force kill if it didn't terminate
        }
        
        // Clear active tests tracking
        for (auto it = m_activeTests.begin(); it != m_activeTests.end(); ++it) {
            emit testProgressUpdated(it.key(), -1, "Cancelled");
        }
        m_activeTests.clear();
        m_testKeyQueue.clear();
        m_currentTestKey.clear();
        
        // Emit finished signal with cancelled status
        const QString modeStr = (m_mode == Mode::All) ? "all" :
                                (m_mode == Mode::CompareThenPrepare ? "compare+prepare" : "unknown");
        emit runFinished(false, modeStr, -1, "", "Operation cancelled by user");
        
        // Reset mode
        m_mode = Mode::None;
        m_step2Queued = false;
        
        DEBUG_LOG("TesterRunner") << "Process stopped";
    }
    
    // Stop Phase 4 process if running
    if (m_prepareUIProcess.state() == QProcess::Running || m_prepareUIProcess.state() == QProcess::Starting) {
        DEBUG_LOG("TesterRunner") << "Stopping Phase 4 (prepare-ui) process...";
        m_prepareUIProcess.kill();
        if (!m_prepareUIProcess.waitForFinished(2000)) {
            DEBUG_LOG("TesterRunner") << "Phase 4 process did not terminate, forcing kill";
            m_prepareUIProcess.kill();
        }
        emit runFinished(false, "prepare-ui", -1, "", "Phase 4 cancelled by user");
        DEBUG_LOG("TesterRunner") << "Phase 4 process stopped";
    }
    
    if (m_process.state() != QProcess::Running && m_process.state() != QProcess::Starting &&
        m_prepareUIProcess.state() != QProcess::Running && m_prepareUIProcess.state() != QProcess::Starting) {
        DEBUG_LOG("TesterRunner") << "No process running to stop";
    }
}

void TesterRunner::runAll(const QString &testerPath, const QString &iniPath)
{
    // Validate input parameters
    if (testerPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runAll - Invalid testerPath (empty)";
        emit runFinished(false, "all", -1, "", "Invalid tester path");
        return;
    }
    if (iniPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runAll - Invalid iniPath (empty)";
        emit runFinished(false, "all", -1, "", "Invalid INI path");
        return;
    }
    
    m_testerPath = testerPath;
    m_iniPath = iniPath;
    m_mode = Mode::All;
    m_step2Queued = false;
    m_currentTestKey = "";  // Reset current test tracking
    m_activeTests.clear();  // Clear active tests map
    m_testKeyQueue.clear();  // Clear test key queue

    // Working directory should be the tester's src folder
    QDir wd(testerPath);
    if (wd.exists("src")) wd.cd("src");

    // Prefer python; if not found, the OS will error and the signal will carry details
    // Note: --ini must come BEFORE the subcommand in argparse
    // Try to use INI from freeDView_tester project first, fallback to provided INI
    QStringList args;
    args << "main.py";
    QString actualIniPath = iniPath;
    QDir testerDir(testerPath);
    QString testerIniPath = testerDir.absoluteFilePath("freeDView_tester.ini");
    if (QFileInfo::exists(testerIniPath)) {
        actualIniPath = testerIniPath;
        DEBUG_LOG("TesterRunner") << "Using INI from freeDView_tester project:" << actualIniPath;
    } else if (!iniPath.isEmpty()) {
        actualIniPath = iniPath;
        DEBUG_LOG("TesterRunner") << "Using provided INI:" << actualIniPath;
    }
    if (!actualIniPath.isEmpty()) {
        args << "--ini" << actualIniPath;
    }
    args << "all";
    emit runStarted("all");
    startProcess("python", args, wd.absolutePath());
}

void TesterRunner::runCompareAndPrepare(const QString &testerPath, const QString &iniPath)
{
    // Validate input parameters
    if (testerPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runCompareAndPrepare - Invalid testerPath (empty)";
        emit runFinished(false, "compare+prepare", -1, "", "Invalid tester path");
        return;
    }
    if (iniPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runCompareAndPrepare - Invalid iniPath (empty)";
        emit runFinished(false, "compare+prepare", -1, "", "Invalid INI path");
        return;
    }
    
    m_testerPath = testerPath;
    m_iniPath = iniPath;
    m_mode = Mode::CompareThenPrepare;
    m_step2Queued = false;
    m_currentTestKey = "";  // Reset current test tracking
    m_activeTests.clear();  // Clear active tests map
    m_testKeyQueue.clear();  // Clear test key queue

    QDir wd(testerPath);
    if (wd.exists("src")) wd.cd("src");

    // Note: --ini must come BEFORE the subcommand in argparse
    // Try to use INI from freeDView_tester project first, fallback to provided INI
    QStringList args;
    args << "main.py";
    QString actualIniPath = iniPath;
    QDir testerDir(testerPath);
    QString testerIniPath = testerDir.absoluteFilePath("freeDView_tester.ini");
    if (QFileInfo::exists(testerIniPath)) {
        actualIniPath = testerIniPath;
        DEBUG_LOG("TesterRunner") << "Using INI from freeDView_tester project:" << actualIniPath;
    } else if (!iniPath.isEmpty()) {
        actualIniPath = iniPath;
        DEBUG_LOG("TesterRunner") << "Using provided INI:" << actualIniPath;
    }
    if (!actualIniPath.isEmpty()) {
        args << "--ini" << actualIniPath;
    }
    args << "compare";
    emit runStarted("compare+prepare");
    startProcess("python", args, wd.absolutePath());
}

void TesterRunner::runPrepareUI(const QString &testerPath, const QString &iniPath)
{
    // Validate input parameters
    if (testerPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runPrepareUI - Invalid testerPath (empty)";
        emit runFinished(false, "prepare-ui", -1, "", "Invalid tester path");
        return;
    }
    if (iniPath.isEmpty()) {
        DEBUG_LOG("TesterRunner") << "runPrepareUI - Invalid iniPath (empty)";
        emit runFinished(false, "prepare-ui", -1, "", "Invalid INI path");
        return;
    }
    
    // Phase 4 can run in parallel with test processes using a separate QProcess
    // Check if Phase 4 is already running
    if (m_prepareUIProcess.state() == QProcess::Running || m_prepareUIProcess.state() == QProcess::Starting) {
        DEBUG_LOG("TesterRunner") << "Phase 4 (prepare-ui) is already running, skipping duplicate request";
        return;
    }
    
    // Debug: Check test process status
    DEBUG_LOG("TesterRunner") << "Starting Phase 4 - Test process state:" << m_process.state() << "(Running=" << QProcess::Running << ", NotRunning=" << QProcess::NotRunning << ")";
    
    QDir wd(testerPath);
    if (wd.exists("src")) wd.cd("src");

    // Note: --ini must come BEFORE the subcommand in argparse
    // Try to use INI from freeDView_tester project first, fallback to provided INI
    QStringList args;
    args << "main.py";
    QString actualIniPath = iniPath;
    QDir testerDir(testerPath);
    QString testerIniPath = testerDir.absoluteFilePath("freeDView_tester.ini");
    if (QFileInfo::exists(testerIniPath)) {
        actualIniPath = testerIniPath;
        DEBUG_LOG("TesterRunner") << "Using INI from freeDView_tester project:" << actualIniPath;
    } else if (!iniPath.isEmpty()) {
        actualIniPath = iniPath;
        DEBUG_LOG("TesterRunner") << "Using provided INI:" << actualIniPath;
    }
    if (!actualIniPath.isEmpty()) {
        args << "--ini" << actualIniPath;
    }
    args << "prepare-ui";
    
    DEBUG_LOG("TesterRunner") << "Starting Phase 4 (prepare-ui) in parallel (separate process)";
    DEBUG_LOG("TesterRunner") << "  Program: python";
    DEBUG_LOG("TesterRunner") << "  Arguments:" << args;
    DEBUG_LOG("TesterRunner") << "  Working Directory:" << wd.absolutePath();
    
    // Disconnect any existing readyRead connections to avoid duplicates
    disconnect(&m_prepareUIProcess, &QProcess::readyReadStandardOutput, nullptr, nullptr);
    disconnect(&m_prepareUIProcess, &QProcess::readyReadStandardError, nullptr, nullptr);
    
    m_prepareUIProcess.setWorkingDirectory(wd.absolutePath());
    m_prepareUIProcess.setProgram("python");
    m_prepareUIProcess.setArguments(args);
    
    // Ensure process doesn't wait for stdin input
    m_prepareUIProcess.setProcessChannelMode(QProcess::MergedChannels);
    m_prepareUIProcess.setInputChannelMode(QProcess::ManagedInputChannel);
    
    // Connect to readyRead signals to capture output (optional, for debugging)
    connect(&m_prepareUIProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        QByteArray data = m_prepareUIProcess.readAllStandardOutput();
        QString output = QString::fromLocal8Bit(data);
        DEBUG_LOG("TesterRunner") << "(Phase 4) stdout:" << output;
        
        // Emit raw output lines for logging
        QStringList allLines = output.split('\n');
        for (const QString &rawLine : allLines) {
            QString trimmedLine = rawLine.trimmed();
            if (!trimmedLine.isEmpty()) {
                emit outputLine("[Phase 4] " + trimmedLine, false);  // false = stdout
            }
        }
    });
    
    connect(&m_prepareUIProcess, &QProcess::readyReadStandardError, this, [this]() {
        QByteArray data = m_prepareUIProcess.readAllStandardError();
        QString output = QString::fromLocal8Bit(data);
        DEBUG_LOG("TesterRunner") << "(Phase 4) stderr:" << output;
        
        // Emit raw error output lines for logging
        QStringList allLines = output.split('\n');
        for (const QString &rawLine : allLines) {
            QString trimmedLine = rawLine.trimmed();
            if (!trimmedLine.isEmpty()) {
                emit outputLine("[Phase 4] " + trimmedLine, true);  // true = stderr
            }
        }
    });
    
    emit runStarted("prepare-ui");
    m_prepareUIProcess.start();
}

void TesterRunner::runNextStep()
{
    if (m_mode != Mode::CompareThenPrepare) return;

    QDir wd(m_testerPath);
    if (wd.exists("src")) wd.cd("src");

    // Note: --ini must come BEFORE the subcommand in argparse
    // Try to use INI from freeDView_tester project first, fallback to provided INI
    QStringList args;
    args << "main.py";
    QString actualIniPath = m_iniPath;
    QDir testerDir(m_testerPath);
    QString testerIniPath = testerDir.absoluteFilePath("freeDView_tester.ini");
    if (QFileInfo::exists(testerIniPath)) {
        actualIniPath = testerIniPath;
        DEBUG_LOG("TesterRunner") << "Using INI from freeDView_tester project:" << actualIniPath;
    } else if (!m_iniPath.isEmpty()) {
        actualIniPath = m_iniPath;
        DEBUG_LOG("TesterRunner") << "Using provided INI:" << actualIniPath;
    }
    if (!actualIniPath.isEmpty()) {
        args << "--ini" << actualIniPath;
    }
    args << "prepare-ui";
    startProcess("python", args, wd.absolutePath());
}

void TesterRunner::startProcess(const QString &program, const QStringList &args, const QString &workingDir)
{
    DEBUG_LOG("TesterRunner") << "Starting process";
    DEBUG_LOG("TesterRunner") << "  Program:" << program;
    DEBUG_LOG("TesterRunner") << "  Arguments:" << args;
    DEBUG_LOG("TesterRunner") << "  Working Directory:" << workingDir;
    
    // Disconnect any existing readyRead connections to avoid duplicates
    disconnect(&m_process, &QProcess::readyReadStandardOutput, nullptr, nullptr);
    disconnect(&m_process, &QProcess::readyReadStandardError, nullptr, nullptr);
    
    m_process.setWorkingDirectory(workingDir);
    m_process.setProgram(program);
    m_process.setArguments(args);
    
    // Ensure process doesn't wait for stdin input
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    m_process.setInputChannelMode(QProcess::ManagedInputChannel);
    
    // Connect to readyRead signals to capture output in real-time
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        QByteArray data = m_process.readAllStandardOutput();
        QString output = QString::fromLocal8Bit(data);
        DEBUG_LOG("TesterRunner") << "stdout:" << output;
        
        // Emit raw output lines for logging
        QStringList allLines = output.split('\n');
        for (const QString &rawLine : allLines) {
            QString trimmedLine = rawLine.trimmed();
            if (!trimmedLine.isEmpty()) {
                emit outputLine(trimmedLine, false);  // false = stdout
            }
        }
        
        // Parse progress from output line by line
        QStringList lines = output.split('\n', QString::SkipEmptyParts);
        for (const QString &line : lines) {
            // Look for "Starting comparison for:" to identify which test/folder is being processed
            QRegExp startingRegex("Starting comparison for:\\s*(.+)");
            if (startingRegex.indexIn(line) != -1) {
                QString folderPath = startingRegex.cap(1).trimmed();
                // Extract test key from folder path
                // Format: path/to/testSets_results/SportType/Event/Set/F####
                // We need to extract the relative path after testSets_results
                QString testKey = this->extractTestKeyFromPath(folderPath);
                if (!testKey.isEmpty()) {
                    this->m_currentTestKey = testKey;
                    // Add to active tests map (frame count unknown initially, will be set when we see Progress message)
                    this->m_activeTests[testKey] = 0;
                    this->m_testKeyQueue.enqueue(testKey);
                    DEBUG_LOG("TesterRunner") << "Starting comparison for test:" << testKey << "(current active test)";
                    // Emit start progress for this test
                    emit testProgressUpdated(testKey, 0, "Starting...");
                }
                continue;
            }
            
            // Look for per-folder "Progress:" pattern (this is per-test progress)
            QRegExp progressRegex("Progress:\\s*(\\d+)/(\\d+)\\s*frames\\s*\\((\\d+)%\\)");
            if (progressRegex.indexIn(line) != -1) {
                int current = progressRegex.cap(1).toInt();
                int total = progressRegex.cap(2).toInt();
                int percent = progressRegex.cap(3).toInt();
                QString message = QString("Processing: %1/%2 frames").arg(current).arg(total);
                
                // Find which test this progress belongs to
                // Strategy: ALWAYS try to match by frame count first (most reliable)
                // Only if no match found, assign to the OLDEST test with unknown frame count (FIFO)
                // This prevents swapping because we assign in the order tests were started
                QString matchedTestKey = this->findTestKeyByFrameCount(total);
                if (matchedTestKey.isEmpty()) {
                    // No match by frame count - assign to oldest test with unknown frame count (FIFO order)
                    for (int i = 0; i < this->m_testKeyQueue.size(); i++) {
                        QString queueKey = this->m_testKeyQueue[i];
                        if (this->m_activeTests.contains(queueKey) && this->m_activeTests[queueKey] == 0) {
                            matchedTestKey = queueKey;
                            this->m_activeTests[matchedTestKey] = total;
                            DEBUG_LOG("TesterRunner") << "Assigned progress" << current << "/" << total << "to oldest test with unknown frames:" << matchedTestKey;
                            break;
                        }
                    }
                } else {
                    DEBUG_LOG("TesterRunner") << "Matched progress" << current << "/" << total << "to test" << matchedTestKey << "by frame count";
                }
                
                if (!matchedTestKey.isEmpty()) {
                    emit testProgressUpdated(matchedTestKey, percent, message);
                }
                
                // Also emit overall progress for backward compatibility
                emit progressUpdated(percent, message);
                continue;
            }
            
            // Look for "Overall progress" pattern (overall across all tests)
            // Format: "Overall progress: X/Y frames (Z%) - Current folder: A/B frames"
            QRegExp overallProgressRegex("Overall progress:\\s*(\\d+)/(\\d+)\\s*frames\\s*\\((\\d+)%\\)");
            if (overallProgressRegex.indexIn(line) != -1) {
                int current = overallProgressRegex.cap(1).toInt();
                int total = overallProgressRegex.cap(2).toInt();
                int percent = overallProgressRegex.cap(3).toInt();
                
                // Try to extract "Current folder: A/B frames" to get per-folder progress
                QRegExp currentFolderRegex("Current folder:\\s*(\\d+)/(\\d+)\\s*frames");
                if (currentFolderRegex.indexIn(line) != -1) {
                    int folderCurrent = currentFolderRegex.cap(1).toInt();
                    int folderTotal = currentFolderRegex.cap(2).toInt();
                    int folderPercent = folderTotal > 0 ? (int)((folderCurrent * 100.0) / folderTotal) : 0;
                    QString message = QString("Processing: %1/%2 frames").arg(folderCurrent).arg(folderTotal);
                    
                    // Find which test this progress belongs to (same strategy as above)
                    QString matchedTestKey = this->findTestKeyByFrameCount(folderTotal);
                    if (matchedTestKey.isEmpty()) {
                        // No match by frame count - assign to oldest test with unknown frame count (FIFO order)
                        for (int i = 0; i < this->m_testKeyQueue.size(); i++) {
                            QString queueKey = this->m_testKeyQueue[i];
                            if (this->m_activeTests.contains(queueKey) && this->m_activeTests[queueKey] == 0) {
                                matchedTestKey = queueKey;
                                this->m_activeTests[matchedTestKey] = folderTotal;
                                DEBUG_LOG("TesterRunner") << "Assigned 'Current folder' progress" << folderCurrent << "/" << folderTotal << "to oldest test with unknown frames:" << matchedTestKey;
                                break;
                            }
                        }
                    } else {
                        DEBUG_LOG("TesterRunner") << "Matched 'Current folder' progress" << folderCurrent << "/" << folderTotal << "to test" << matchedTestKey << "by frame count";
                    }
                    
                    if (!matchedTestKey.isEmpty()) {
                        emit testProgressUpdated(matchedTestKey, folderPercent, message);
                    }
                }
                
                QString overallMessage = QString("Processing: %1/%2 frames").arg(current).arg(total);
                emit progressUpdated(percent, overallMessage);
                continue;
            }
            
            // Look for "Successfully completed comparison for:" - includes folder path
            QRegExp completedRegex("Successfully completed comparison for:\\s*(.+)");
            if (completedRegex.indexIn(line) != -1) {
                QString folderPath = completedRegex.cap(1).trimmed();
                QString testKey = this->extractTestKeyFromPath(folderPath);
                if (!testKey.isEmpty()) {
                    emit testProgressUpdated(testKey, 100, "Completed");
                    // Remove from active tests map
                    this->m_activeTests.remove(testKey);
                    // Remove from queue if present
                    for (int i = 0; i < this->m_testKeyQueue.size(); i++) {
                        if (this->m_testKeyQueue[i] == testKey) {
                            this->m_testKeyQueue.removeAt(i);
                            break;
                        }
                    }
                    // Clear m_currentTestKey if it matches
                    if (this->m_currentTestKey == testKey) {
                        this->m_currentTestKey.clear();
                    }
                } else if (!this->m_currentTestKey.isEmpty()) {
                    // Fallback: use current test key
                    emit testProgressUpdated(this->m_currentTestKey, 100, "Completed");
                    this->m_activeTests.remove(this->m_currentTestKey);
                    this->m_currentTestKey.clear();
                }
                continue;
            }
            
            // Look for "Frame comparison completed" - test finished (older format)
            if (line.contains("Frame comparison completed", Qt::CaseInsensitive)) {
                if (!this->m_currentTestKey.isEmpty()) {
                    emit testProgressUpdated(this->m_currentTestKey, 100, "Completed");
                    this->m_activeTests.remove(this->m_currentTestKey);
                    // Don't clear m_currentTestKey here - it might be used by subsequent messages
                    // Clear it when we see a new "Starting" message or "Successfully completed"
                }
            }
            
            // Also look for phase completion messages
            if (line.contains("Phase", Qt::CaseInsensitive) && line.contains("completed", Qt::CaseInsensitive)) {
                // Extract phase number if possible
                QRegExp phaseRegex("Phase\\s*(\\d+)");
                if (phaseRegex.indexIn(line) != -1) {
                    QString phaseNum = phaseRegex.cap(1);
                    emit progressUpdated(-1, QString("Phase %1 completed").arg(phaseNum));
                }
            }
            
            // Look for "All phases completed" or similar
            if (line.contains("All phases completed", Qt::CaseInsensitive) || 
                line.contains("completed successfully", Qt::CaseInsensitive)) {
                emit progressUpdated(100, "Processing completed");
            }
        }
    });
    
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        QByteArray data = m_process.readAllStandardError();
        DEBUG_LOG("TesterRunner") << "stderr:" << data;
        
        // Emit raw error output lines for logging
        QString output = QString::fromLocal8Bit(data);
        QStringList allLines = output.split('\n');
        for (const QString &rawLine : allLines) {
            QString trimmedLine = rawLine.trimmed();
            if (!trimmedLine.isEmpty()) {
                emit outputLine(trimmedLine, true);  // true = stderr
            }
        }
    });
    
    // Check if program exists
    QFileInfo programInfo(program);
    if (!programInfo.exists() && !programInfo.isExecutable()) {
        // Try to find python in PATH
        QString foundPython = QStandardPaths::findExecutable(program);
        if (foundPython.isEmpty()) {
            ERROR_LOG("TesterRunner: ERROR - Program not found:" + program);
            emit runFinished(false, "unknown", -1, "", "Program not found: " + program);
            return;
        }
        DEBUG_LOG("TesterRunner") << "Found program at:" << foundPython;
    }
    
    DEBUG_LOG("TesterRunner") << "Starting process...";
    m_process.start();
    
    if (!m_process.waitForStarted(5000)) {
        ERROR_LOG("TesterRunner: ERROR - Failed to start process");
        QString errorMsg = "Failed to start process: " + m_process.errorString();
        emit runFinished(false, "unknown", -1, "", errorMsg);
        return;
    }
    
    DEBUG_LOG("TesterRunner") << "Process started successfully (PID:" << m_process.processId() << ")";
}

QString TesterRunner::extractTestKeyFromPath(const QString &folderPath)
{
    // Extract test key from folder path
    // Input format: "path/to/testSets_results/SportType/Event/Set/F####" or absolute path
    // Output format: "SportType/Event/Set/F####" (relative path, normalized separators)
    
    QString normalizedPath = folderPath;
    // Normalize path separators to forward slashes
    normalizedPath = normalizedPath.replace("\\", "/");
    
    // Find "testSets_results" in the path (case-insensitive search)
    QString lowerPath = normalizedPath.toLower();
    int testSetsResultsIndex = lowerPath.indexOf("testsets_results");
    
    if (testSetsResultsIndex >= 0) {
        // Extract everything after "testSets_results/"
        // Find the actual position in the original case-normalized path
        // Use indexOf with case-insensitive search to get the position
        int actualStartIndex = normalizedPath.indexOf(QString("testSets_results"), 0, Qt::CaseInsensitive);
        int startIndex;
        if (actualStartIndex >= 0) {
            startIndex = actualStartIndex + QString("testSets_results").length();
        } else {
            // Fallback: use the lowercase index position
            startIndex = testSetsResultsIndex + QString("testSets_results").length();
        }
        
        // Skip any slashes
        while (startIndex < normalizedPath.length() && normalizedPath[startIndex] == '/') {
            startIndex++;
        }
        QString testKey = normalizedPath.mid(startIndex);
        
        // Remove any trailing slashes
        while (testKey.endsWith("/")) {
            testKey.chop(1);
        }
        
        // Normalize to forward slashes (already done, but ensure consistency)
        testKey = testKey.replace("\\", "/");
        
        DEBUG_LOG("TesterRunner") << "Extracted test key:" << testKey << "from path:" << folderPath;
        return testKey;
    }
    
    // Fallback: try to extract from path structure
    // Look for pattern like "SportType/EventName/SetName/F####"
    QRegExp testKeyRegex("([A-Za-z0-9_\\s/]+/[A-Z0-9_]+/[A-Z0-9]+/F\\d+)");
    if (testKeyRegex.indexIn(normalizedPath) >= 0) {
        QString testKey = testKeyRegex.cap(1);
        // Extract just the relative part (SportType/Event/Set/F####)
        QStringList parts = testKey.split("/");
        // Look for the pattern: SportType/Event/Set/F#### (4 parts)
        if (parts.length() >= 4) {
            // Take the last 4 parts
            QStringList relevantParts = parts.mid(parts.length() - 4);
            testKey = relevantParts.join("/");
        }
        DEBUG_LOG("TesterRunner") << "Extracted test key (fallback):" << testKey << "from path:" << folderPath;
        return testKey;
    }
    
    DEBUG_LOG("TesterRunner") << "Could not extract test key from path:" << folderPath;
    return "";
}

QString TesterRunner::findTestKeyByFrameCount(int frameCount)
{
    // Find test key(s) that match the given frame count
    QStringList matchingKeys;
    for (auto it = this->m_activeTests.begin(); it != this->m_activeTests.end(); ++it) {
        if (it.value() == frameCount && it.value() > 0) {  // Only match if frame count is known (>0)
            matchingKeys.append(it.key());
        }
    }
    
    if (matchingKeys.isEmpty()) {
        // No match found - log available tests for debugging
        DEBUG_LOG("TesterRunner") << "No match for frame count" << frameCount << "Available tests:";
        for (auto it = this->m_activeTests.begin(); it != this->m_activeTests.end(); ++it) {
            DEBUG_LOG("TesterRunner") << "  -" << it.key() << ":" << it.value() << "frames";
        }
        return QString();
    }
    
    if (matchingKeys.size() == 1) {
        // Exact match - use it
        DEBUG_LOG("TesterRunner") << "Matched frame count" << frameCount << "to test" << matchingKeys[0];
        return matchingKeys[0];
    }
    
    // Multiple matches - use the one most recently started (last in queue)
    // Traverse queue from back to front to find the most recent match
    DEBUG_LOG("TesterRunner") << "Multiple matches for frame count" << frameCount << ":" << matchingKeys;
    for (int i = this->m_testKeyQueue.size() - 1; i >= 0; i--) {
        QString queueKey = this->m_testKeyQueue[i];
        if (matchingKeys.contains(queueKey)) {
            DEBUG_LOG("TesterRunner") << "Using most recent match:" << queueKey;
            return queueKey;
        }
    }
    
    // Fallback: return first match
    DEBUG_LOG("TesterRunner") << "Using first match:" << matchingKeys[0];
    return matchingKeys[0];
}

void TesterRunner::onPrepareUIProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    // Read any remaining output
    const QString stdOut = QString::fromLocal8Bit(m_prepareUIProcess.readAllStandardOutput());
    const QString stdErr = QString::fromLocal8Bit(m_prepareUIProcess.readAllStandardError());
    
    // Ensure process is properly closed
    if (m_prepareUIProcess.state() != QProcess::NotRunning) {
        DEBUG_LOG("TesterRunner") << "Phase 4 process not fully stopped, waiting...";
        m_prepareUIProcess.waitForFinished(1000);  // Wait up to 1 second
    }
    
    const bool success = (exitStatus == QProcess::NormalExit && exitCode == 0);
    DEBUG_LOG("TesterRunner") << "Phase 4 (prepare-ui) finished with exit code" << exitCode;
    
    // Debug: Check test process status after Phase 4 finishes
    DEBUG_LOG("TesterRunner") << "After Phase 4 finished - Test process state:" << m_process.state() << "(Running=" << QProcess::Running << ", NotRunning=" << QProcess::NotRunning << ")";
    
    // Emit finished signal for Phase 4 (mode is "prepare-ui")
    emit runFinished(success, "prepare-ui", exitCode, stdOut, stdErr);
}

