#include "inireader.h"
#include "logger.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QCoreApplication>
#include <QSettings>
#include <QTextStream>
#include <QRegExp>

IniReader::IniReader(QObject *parent)
    : QObject(parent)
    , m_isValid(false)
{
}

bool IniReader::readINIFile()
{
    QString filePath = findINIFile();
    if (filePath.isEmpty()) {
        QString errorMsg = "INI file not found in any of the checked locations";
        emit errorOccurred(errorMsg);
        m_isValid = false;
        emit pathsChanged();
        return false;
    }
    
    if (parseINIFile(filePath)) {
        m_isValid = true;
        emit pathsChanged();
        return true;
    } else {
        m_isValid = false;
        emit pathsChanged();
        return false;
    }
}

QString IniReader::findINIFile() const
{
    QStringList possiblePaths;
    QString appDir = QCoreApplication::applicationDirPath();
    
    // PRIMARY locations (for deployment - checked first)
    // Look for renderCompare.ini (used by renderCompare)
    possiblePaths << appDir + "/renderCompare.ini";
    possiblePaths << appDir + "/../renderCompare.ini";
    possiblePaths << appDir + "/../../renderCompare.ini";
    possiblePaths << appDir + "/../../../renderCompare.ini";
    possiblePaths << appDir + "/../../../../renderCompare.ini";
    
    // Also try current working directory
    QDir currentDir = QDir::current();
    possiblePaths << currentDir.absoluteFilePath("renderCompare.ini");
    
    // Try going up from current directory to find project root
    QDir checkDir = currentDir;
    for (int i = 0; i < 10; i++) {
        QString testPath = checkDir.absoluteFilePath("renderCompare.ini");
        possiblePaths << testPath;
        
        // Also check in "renderCompare" subdirectory if it exists
        QDir renderCompareDir = checkDir;
        if (renderCompareDir.cd("renderCompare")) {
            possiblePaths << renderCompareDir.absoluteFilePath("renderCompare.ini");
        }
        
        // Check if we're in the project root (has renderCompare.pro file)
        if (QFileInfo(checkDir.absoluteFilePath("renderCompare.pro")).exists()) {
            possiblePaths << checkDir.absoluteFilePath("renderCompare.ini");
        }
        
        if (!checkDir.cdUp()) {
            break;
        }
    }
    
    // Also try to find the project root by looking for the source file location
    // This helps when running from build directories
    QString sourceFile = __FILE__;
    QFileInfo sourceInfo(sourceFile);
    QDir sourceDir = sourceInfo.absoluteDir();
    // Go up from src/ to project root
    if (sourceDir.cdUp()) {
        possiblePaths << sourceDir.absoluteFilePath("renderCompare.ini");
    }
    
    // Remove duplicates
    possiblePaths.removeDuplicates();
    
    for (const QString &path : possiblePaths) {
        QFileInfo info(path);
        if (info.exists() && info.isFile()) {
            return info.absoluteFilePath();
        }
    }
    
    return QString();
}

bool IniReader::parseINIFile(const QString &filePath)
{
    QSettings settings(filePath, QSettings::IniFormat);
    
    // Set UTF-8 encoding for INI file reading (QSettings uses system default)
    settings.setIniCodec("UTF-8");
    
    // Get INI file directory for resolving relative paths
    QFileInfo iniFileInfo(filePath);
    QDir iniFileDir = iniFileInfo.absoluteDir();
    
    // Remember the INI location
    m_iniFilePath = QFileInfo(filePath).absoluteFilePath();

    // Read setTestPath and freeDViewTesterPath from [freeDView_tester] section
    // Read directly from file to avoid QSettings backslash escaping issues
    QString setTestPathValue;
    QString testerPathValue;
    QFile iniFile(filePath);
    if (iniFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&iniFile);
        bool inSection = false;
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.startsWith("[freeDView_tester]")) {
                inSection = true;
                continue;
            }
            if (inSection && line.startsWith("[")) {
                break; // Next section
            }
            if (inSection && line.startsWith("setTestPath", Qt::CaseInsensitive)) {
                // Extract value after = sign
                int eqPos = line.indexOf('=');
                if (eqPos != -1) {
                    setTestPathValue = line.mid(eqPos + 1).trimmed();
                    // Remove trailing comments (everything after # or ;)
                    int commentPos = setTestPathValue.indexOf('#');
                    if (commentPos == -1) commentPos = setTestPathValue.indexOf(';');
                    if (commentPos != -1) setTestPathValue = setTestPathValue.left(commentPos).trimmed();
                    continue;
                }
            }
            if (inSection && line.startsWith("freeDViewTesterPath", Qt::CaseInsensitive)) {
                int eqPos = line.indexOf('=');
                if (eqPos != -1) {
                    testerPathValue = line.mid(eqPos + 1).trimmed();
                    int commentPos = testerPathValue.indexOf('#');
                    if (commentPos == -1) commentPos = testerPathValue.indexOf(';');
                    if (commentPos != -1) testerPathValue = testerPathValue.left(commentPos).trimmed();
                    continue;
                }
            }
        }
        iniFile.close();
    }
    
    if (setTestPathValue.isEmpty()) {
        QString errorMsg = "No 'setTestPath' key found in INI file";
        emit errorOccurred(errorMsg);
        return false;
    }
    
    // setTestPath in INI now points to testSets_results (where uiData.xml and all test data is)
    // Convert relative paths to absolute paths (relative to INI file location)
    QString absoluteResultsPath;
    if (QDir::isRelativePath(setTestPathValue)) {
        // Path is relative - make it absolute relative to INI file location
        absoluteResultsPath = iniFileDir.absoluteFilePath(setTestPathValue);
    } else {
        // Path is already absolute - use as is
        absoluteResultsPath = setTestPathValue;
    }
    
    // Convert to absolute path and normalize
    QDir mainResultsDir(absoluteResultsPath);
    m_setTestResultsPath = mainResultsDir.absolutePath();
    // Normalize path separators for Windows
    m_setTestResultsPath = QDir::toNativeSeparators(m_setTestResultsPath);
    
    // Derive testSets from testSets_results (for fallback thumbnail paths)
    m_setTestPath = QString(m_setTestResultsPath).replace("testSets_results", "testSets");
    QDir mainTestDir(m_setTestPath);
    m_setTestPath = mainTestDir.absolutePath();
    m_setTestPath = QDir::toNativeSeparators(m_setTestPath);
    
    // Debug output
    DEBUG_LOG("IniReader") << "setTestPath (testSets_results from INI):" << m_setTestResultsPath;
    DEBUG_LOG("IniReader") << "setTestPath (testSets derived):" << m_setTestPath;
    
    // Get freedviewVer if specified (using QSettings for this since it doesn't contain backslashes)
    settings.beginGroup("freeDView_tester");
    m_freedviewVer = settings.value("freedviewVer", "").toString();
    settings.endGroup();

        // Resolve freeDViewTesterPath (allow relative paths)
        if (!testerPathValue.isEmpty()) {
            if (QDir::isRelativePath(testerPathValue)) {
                m_freeDViewTesterPath = iniFileDir.absoluteFilePath(testerPathValue);
            } else {
                m_freeDViewTesterPath = testerPathValue;
            }
            QDir testerDir(m_freeDViewTesterPath);
            m_freeDViewTesterPath = QDir::toNativeSeparators(testerDir.absolutePath());
        } else {
            // If not explicitly set, infer from setTestResultsPath
            // If setTestResultsPath is ".../testSets_results", then freeDViewTesterPath should be ".../freeDView_tester"
            if (!m_setTestResultsPath.isEmpty()) {
                QDir testSetsResultsDir(m_setTestResultsPath);
                if (testSetsResultsDir.cdUp()) {
                    // Check if parent directory is named "freeDView_tester" or contains it
                    QString parentPath = testSetsResultsDir.absolutePath();
                    if (parentPath.contains("freeDView_tester", Qt::CaseInsensitive)) {
                        // Find the freeDView_tester root directory
                        QDir searchDir(parentPath);
                        while (!searchDir.isRoot()) {
                            if (searchDir.dirName().contains("freeDView_tester", Qt::CaseInsensitive)) {
                                m_freeDViewTesterPath = QDir::toNativeSeparators(searchDir.absolutePath());
                                break;
                            }
                            if (!searchDir.cdUp()) break;
                        }
                        // If not found, use the parent of testSets_results
                        if (m_freeDViewTesterPath.isEmpty()) {
                            m_freeDViewTesterPath = QDir::toNativeSeparators(testSetsResultsDir.absolutePath());
                        }
                    } else {
                        m_freeDViewTesterPath = QDir::toNativeSeparators(testSetsResultsDir.absolutePath());
                    }
                } else {
                    m_freeDViewTesterPath.clear();
                }
            } else {
                m_freeDViewTesterPath.clear();
            }
        }
    
    return true;
}

QStringList IniReader::findAllXMLFiles() const
{
    QStringList xmlFiles;
    
    if (m_setTestResultsPath.isEmpty()) {
        return xmlFiles;
    }
    
    QDir dir(m_setTestResultsPath);
    if (!dir.exists()) {
        return xmlFiles;
    }
    
    // Recursively find all compareResult.xml files
    QDirIterator it(m_setTestResultsPath, QStringList() << "compareResult.xml", 
                    QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        QString filePath = it.next();
        // Convert to file:// URL for QML
        filePath = QDir::toNativeSeparators(filePath);
        xmlFiles.append(filePath);
    }
    
    return xmlFiles;
}

QString IniReader::findThumbnailForPath(const QString &xmlPath) const
{
    if (xmlPath.isEmpty()) {
        return QString();
    }

    // Extract the directory containing the XML file
    QFileInfo xmlFileInfo(xmlPath);
    QDir xmlDir = xmlFileInfo.absoluteDir();
    
    // Go up from "results" directory to get the event set directory
    // Path structure: .../eventSet/results/compareResult.xml
    if (xmlDir.dirName().toLower() == "results") {
        xmlDir.cdUp(); // Go to eventSet directory
    }

    // Look for frame directories (similar to renderCompare logic)
    // Structure: eventSet/FRAME/freedviewVersion/origFreeDView or testFreeDView
    QDir eventSetDir(xmlDir.absolutePath());
    eventSetDir.setFilter(QDir::AllDirs | QDir::NoDotAndDotDot | QDir::NoSymLinks);
    QFileInfoList frameList = eventSetDir.entryInfoList();

    // Look through frame directories
    for (const QFileInfo &frameInfo : frameList) {
        QDir frameDir = frameInfo.absoluteFilePath();

        // Look for freedview version directories
        frameDir.setFilter(QDir::AllDirs | QDir::NoDotAndDotDot | QDir::NoSymLinks);
        QFileInfoList versionList = frameDir.entryInfoList();

        for (const QFileInfo &versionInfo : versionList) {
            QDir versionDir = versionInfo.absoluteFilePath();

            // Look for orig directories (for thumbnails, we use "orig" output type)
            versionDir.setFilter(QDir::AllDirs | QDir::NoDotAndDotDot | QDir::NoSymLinks);
            QFileInfoList outputList = versionDir.entryInfoList();

            for (const QFileInfo &outputInfo : outputList) {
                QString outputDirName = outputInfo.fileName().toLower();
                // Look for origFreeDView directories
                if (outputDirName.contains("orig")) {
                    QDir outputDir = outputInfo.absoluteFilePath();

                    // Look for image files in this directory (prefer 0001.jpg)
                    QStringList imageExtensions = QStringList() << "*.png" << "*.jpg" << "*.jpeg" << "*.bmp" << "*.gif";
                    outputDir.setNameFilters(imageExtensions);
                    outputDir.setFilter(QDir::Files | QDir::NoSymLinks);
                    QFileInfoList imageList = outputDir.entryInfoList();

                    // Prefer 0001.jpg if it exists
                    for (const QFileInfo &imgInfo : imageList) {
                        if (imgInfo.baseName() == "0001" || imgInfo.baseName() == "00001") {
                            return imgInfo.absoluteFilePath();
                        }
                    }

                    // Otherwise return the first image found
                    if (!imageList.isEmpty()) {
                        return imageList.first().absoluteFilePath();
                    }
                }
            }
        }
    }

    // Fallback: try to find any image file in the eventSet directory or subdirectories
    QStringList imageExtensions = QStringList() << "*.png" << "*.jpg" << "*.jpeg" << "*.bmp" << "*.gif";
    QDirIterator it(xmlDir.absolutePath(), imageExtensions, QDir::Files, QDirIterator::Subdirectories);
    if (it.hasNext()) {
        return it.next();
    }

    // If no image found, return empty string
    return QString();
}

bool IniReader::updateRunOnTestList(const QString &testKey)
{
    QString filePath = findINIFile();
    if (filePath.isEmpty()) {
        emit errorOccurred("INI file not found - cannot update run_on_test_list");
        return false;
    }
    
    // Read the entire INI file
    QFile file(filePath);
    if (!file.open(QIODevice::ReadWrite | QIODevice::Text)) {
        emit errorOccurred("Cannot open INI file for writing: " + filePath);
        return false;
    }
    
    QTextStream in(&file);
    QStringList lines;
    bool inSection = false;
    bool runOnTestListFound = false;
    
    // Read all lines
    while (!in.atEnd()) {
        QString line = in.readLine();
        QString trimmedLine = line.trimmed();
        
        if (trimmedLine.startsWith("[freeDView_tester]")) {
            inSection = true;
            lines << line;
            continue;
        }
        
        if (inSection && trimmedLine.startsWith("[")) {
            inSection = false;
        }
        
        if (inSection && trimmedLine.startsWith("run_on_test_list", Qt::CaseInsensitive)) {
            // Replace existing run_on_test_list line
            if (testKey.isEmpty()) {
                // Set to empty array format (with spaces as per user preference)
                lines << "run_on_test_list = []";
            } else {
                lines << "run_on_test_list = " + testKey;
            }
            runOnTestListFound = true;
        } else {
            lines << line;
        }
    }
    
    // If run_on_test_list wasn't found, always add it (either with value or empty)
    if (!runOnTestListFound) {
        // Find where to insert (after [freeDView_tester] section, before next section or end)
        bool inserted = false;
        for (int i = 0; i < lines.size(); ++i) {
            if (lines[i].trimmed().startsWith("[freeDView_tester]")) {
                // Insert after the section header, before next section or at end of file
                int insertPos = i + 1;
                while (insertPos < lines.size() && 
                       !lines[insertPos].trimmed().startsWith("[") &&
                       !lines[insertPos].trimmed().isEmpty()) {
                    insertPos++;
                }
                if (testKey.isEmpty()) {
                    lines.insert(insertPos, "run_on_test_list = []");
                } else {
                    lines.insert(insertPos, "run_on_test_list = " + testKey);
                }
                inserted = true;
                break;
            }
        }
        if (!inserted) {
            // Section not found, append at end
            lines << "[freeDView_tester]";
            if (testKey.isEmpty()) {
                lines << "run_on_test_list = []";
            } else {
                lines << "run_on_test_list = " + testKey;
            }
        }
    }
    
    // Write back to file
    file.resize(0); // Clear file
    file.seek(0);
    QTextStream out(&file);
    for (const QString &line : lines) {
        out << line << "\n";
    }
    
    file.close();
    DEBUG_LOG("IniReader") << "Updated run_on_test_list in INI file:" << (testKey.isEmpty() ? "(cleared)" : testKey);
    return true;
}

bool IniReader::updateRunOnTestListInFile(const QString &iniFilePath, const QString &testKey)
{
    if (iniFilePath.isEmpty()) {
        emit errorOccurred("INI file path is empty - cannot update run_on_test_list");
        return false;
    }
    
    QFileInfo fileInfo(iniFilePath);
    if (!fileInfo.exists()) {
        emit errorOccurred("INI file does not exist: " + iniFilePath);
        return false;
    }
    
    // Read the entire INI file
    QFile file(iniFilePath);
    if (!file.open(QIODevice::ReadWrite | QIODevice::Text)) {
        emit errorOccurred("Cannot open INI file for writing: " + iniFilePath);
        return false;
    }
    
    QTextStream in(&file);
    QStringList lines;
    bool inSection = false;
    bool runOnTestListFound = false;
    
    // Read all lines
    while (!in.atEnd()) {
        QString line = in.readLine();
        QString trimmedLine = line.trimmed();
        
        if (trimmedLine.startsWith("[freeDView_tester]")) {
            inSection = true;
            lines << line;
            continue;
        }
        
        if (inSection && trimmedLine.startsWith("[")) {
            inSection = false;
        }
        
        if (inSection && trimmedLine.startsWith("run_on_test_list", Qt::CaseInsensitive)) {
            // Replace existing run_on_test_list line
            if (testKey.isEmpty()) {
                // Set to empty array format
                lines << "run_on_test_list = []";
            } else {
                // Write in bracket format: [testKey] for single test, supports [test1, test2, ...] for multiple
                lines << "run_on_test_list = [" + testKey + "]";
            }
            runOnTestListFound = true;
        } else {
            lines << line;
        }
    }
    
    // If run_on_test_list wasn't found, always add it (either with value or empty)
    if (!runOnTestListFound) {
        // Find where to insert (after [freeDView_tester] section, before next section or end)
        bool inserted = false;
        for (int i = 0; i < lines.size(); ++i) {
            if (lines[i].trimmed().startsWith("[freeDView_tester]")) {
                // Insert after the section header, before next section or at end of file
                int insertPos = i + 1;
                while (insertPos < lines.size() && 
                       !lines[insertPos].trimmed().startsWith("[") &&
                       !lines[insertPos].trimmed().isEmpty()) {
                    insertPos++;
                }
                if (testKey.isEmpty()) {
                    lines.insert(insertPos, "run_on_test_list = []");
                } else {
                    // Write in bracket format: [testKey] for single test, supports [test1, test2, ...] for multiple
                    lines.insert(insertPos, "run_on_test_list = [" + testKey + "]");
                }
                inserted = true;
                break;
            }
        }
        if (!inserted) {
            // Section not found, append at end
            lines << "[freeDView_tester]";
            if (testKey.isEmpty()) {
                lines << "run_on_test_list = []";
            } else {
                // Write in bracket format: [testKey] for single test, supports [test1, test2, ...] for multiple
                lines << "run_on_test_list = [" + testKey + "]";
            }
        }
    }
    
    // Write back to file
    file.resize(0); // Clear file
    file.seek(0);
    QTextStream out(&file);
    for (const QString &line : lines) {
        out << line << "\n";
    }
    
    file.close();
    DEBUG_LOG("IniReader") << "Updated run_on_test_list in renderCompare.ini:" << (testKey.isEmpty() ? "(cleared)" : testKey) << "at:" << iniFilePath;
    return true;
}
