#include "xmldataloader.h"
#include "logger.h"
#include <QFile>
#include <QDirIterator>
#include <QFileInfo>
#include <QDir>
#include <QtXml/QDomDocument>

XmlDataLoader::XmlDataLoader(QObject *parent)
    : QObject(parent)
{
}

/**
 * @brief Start loading XML files from the specified directory
 * 
 * This method is called from the main thread but schedules the actual
 * loading work to run in the background thread via doLoad() slot.
 * 
 * @param resultsPath - Path to the testSets_results directory containing XML files
 */
void XmlDataLoader::loadData(const QString &resultsPath, const QString &testSetsPath)
{
    m_resultsPath = resultsPath;
    m_testSetsPath = testSetsPath;
    // Debug output
    DEBUG_LOG("XmlDataLoader") << "loadData - received resultsPath:" << resultsPath;
    // Use QMetaObject::invokeMethod to ensure doLoad() runs in the worker thread
    // QueuedConnection ensures thread-safe method invocation
    QMetaObject::invokeMethod(this, "doLoad", Qt::QueuedConnection);
}

/**
 * @brief Performs the actual XML loading work in background thread
 * 
 * This method runs in the worker thread, parsing uiData.xml file without blocking the UI.
 * For each entry in the XML, it emits rowLoaded() signal which is received
 * by the main thread and updates the model.
 * 
 * Thread Safety: This method runs in background thread, but emits signals that
 * are received on main thread via queued connections.
 */
void XmlDataLoader::doLoad()
{
    // Validate input path
    if (m_resultsPath.isEmpty()) {
        emit errorOccurred("Results path is empty");
        emit loadingFinished(false, 0);
        return;
    }

    // Notify UI that loading has started
    emit loadingStarted();

    // Construct path to uiData.xml (located in testSets_results root)
    // Debug output
    DEBUG_LOG("XmlDataLoader") << "doLoad - m_resultsPath:" << m_resultsPath;
    // Normalize the path first to ensure proper separators
    QString normalizedResultsPath = QDir::toNativeSeparators(m_resultsPath);
    DEBUG_LOG("XmlDataLoader") << "doLoad - normalizedResultsPath:" << normalizedResultsPath;
    QDir resultsDir(normalizedResultsPath);
    DEBUG_LOG("XmlDataLoader") << "doLoad - resultsDir.exists():" << resultsDir.exists();
    if (!resultsDir.exists()) {
        QString errorMsg = QString("Results directory does not exist: %1").arg(normalizedResultsPath);
        ERROR_LOG("XmlDataLoader::doLoad - ERROR:" + errorMsg);
        emit errorOccurred(errorMsg);
        emit loadingFinished(false, 0);
        return;
    }
    QString uiDataXmlPath = resultsDir.absoluteFilePath("uiData.xml");
    // Normalize path separators (ensure backslashes on Windows)
    uiDataXmlPath = QDir::toNativeSeparators(uiDataXmlPath);

    // Parse uiData.xml and emit row data for each entry
    int entryCount = readUIDataXML(uiDataXmlPath, normalizedResultsPath);

    // Notify UI that loading is complete
    emit loadingFinished(entryCount > 0, entryCount);
}

int XmlDataLoader::readUIDataXML(const QString &uiDataXmlPath, const QString &resultsPathRoot)
{
    // Ensure path uses native separators
    QString normalizedPath = QDir::toNativeSeparators(uiDataXmlPath);
    QFileInfo fileInfo(normalizedPath);
    
    if (!fileInfo.exists()) {
        emit errorOccurred("uiData.xml file does not exist at: " + normalizedPath);
        return 0;
    }
    
    QFile file(normalizedPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred("Failed to open uiData.xml file: " + normalizedPath + " (Error: " + file.errorString() + ")");
        return 0;
    }

    QDomDocument doc;
    QString errorMsg;
    int errorLine, errorColumn;
    if (!doc.setContent(&file, &errorMsg, &errorLine, &errorColumn)) {
        file.close();
        emit errorOccurred(QString("Failed to parse uiData.xml file: %1 (Line: %2)").arg(uiDataXmlPath).arg(errorLine));
        return 0;
    }
    file.close();

    // Find uiData root element
    const QDomNodeList uiDataNodes = doc.elementsByTagName("uiData");
    if (uiDataNodes.isEmpty()) {
        emit errorOccurred("No 'uiData' element found in: " + uiDataXmlPath);
        return 0;
    }

    const QDomElement uiDataElement = uiDataNodes.item(0).toElement();
    
    // Find and parse renderVersions section (if present)
    const QDomElement renderVersionsElement = uiDataElement.firstChildElement("renderVersions");
    if (!renderVersionsElement.isNull()) {
        QStringList renderVersionList;
        const QDomNodeList versionNodes = renderVersionsElement.elementsByTagName("version");
        for (int i = 0; i < versionNodes.size(); ++i) {
            const QDomElement versionElement = versionNodes.item(i).toElement();
            if (!versionElement.isNull()) {
                QString versionName = versionElement.text().trimmed();
                if (!versionName.isEmpty()) {
                    renderVersionList.append(versionName);
                }
            }
        }
        // Emit signal with render versions list
        if (!renderVersionList.isEmpty()) {
            emit renderVersionsLoaded(renderVersionList);
            DEBUG_LOG("XmlDataLoader") << "Found" << renderVersionList.size() << "render version(s) in uiData.xml";
        }
    }
    
    // Find entries element
    const QDomElement entriesElement = uiDataElement.firstChildElement("entries");
    if (entriesElement.isNull()) {
        emit errorOccurred("No 'entries' element found in: " + uiDataXmlPath);
        return 0;
    }

    // Process each entry
    const QDomNodeList entryNodes = entriesElement.elementsByTagName("entry");
    int entryCount = 0;
    
    for (int i = 0; i < entryNodes.size(); ++i) {
        const QDomElement entryElement = entryNodes.item(i).toElement();
        
        // Extract data from entry
        QString id = entryElement.firstChildElement("id").text();
        QString eventName = entryElement.firstChildElement("eventName").text();
        QString sportType = entryElement.firstChildElement("sportType").text();
        QString stadiumName = entryElement.firstChildElement("stadiumName").text();
        QString categoryName = entryElement.firstChildElement("categoryName").text();
        QString numberOfFramesStr = entryElement.firstChildElement("numberOfFrames").text();
        QString minValueStr = entryElement.firstChildElement("minValue").text();
        QString numFramesUnderMinStr = entryElement.firstChildElement("numFramesUnderMin").text();
        QString thumbnailPathRelative = entryElement.firstChildElement("thumbnailPath").text();
        QString status = entryElement.firstChildElement("status").text();
        QString notes = entryElement.firstChildElement("notes").text();
        QString renderVersions = entryElement.firstChildElement("renderVersions").text();  // Comma-separated list
        DEBUG_LOG("XmlDataLoader") << "Entry" << id << "- renderVersions:" << renderVersions;

        // Convert thumbnail path from relative to absolute (relative to resultsPathRoot)
        QString thumbnailPath = resolveThumbnailPath(thumbnailPathRelative, resultsPathRoot);
        
        // Derive testKey from thumbnailPath (testKey is no longer stored in XML)
        // Use relative path for derivation to get consistent testKey format
        // Make sure we use the relative path, not the absolute one
        QString testKey = deriveTestKeyFromThumbnailPath(thumbnailPathRelative);
        
        // Debug: Log testKey for verification
        DEBUG_LOG("XmlDataLoader") << "Derived testKey from thumbnailPathRelative:" << thumbnailPathRelative;
        DEBUG_LOG("XmlDataLoader") << "Resulting testKey:" << testKey;

        // Build row data: [id, eventName, sportType, stadiumName, categoryName, numberOfFrames, minValue, notes, status, thumbnailPath, testKey, renderVersions]
        QVariantList rowData;
        rowData << id;  // ID from XML (will be used by model)
        rowData << eventName;
        rowData << sportType;
        rowData << stadiumName;
        rowData << categoryName;
        rowData << numberOfFramesStr;
        rowData << minValueStr;  // Already a string in XML
        rowData << notes;
        rowData << status;
        rowData << thumbnailPath;
        rowData << testKey;  // Add testKey for filtering support
        rowData << renderVersions;  // Add renderVersions for filtering by render version

        // Emit signal - will be received on main thread via queued connection
        // Use empty string for xmlPath since we're not tracking individual XML files anymore
        emit rowLoaded(rowData, QString());
        entryCount++;
    }

    return entryCount;
}

QString XmlDataLoader::resolveThumbnailPath(const QString &relativeThumbnailPath, const QString &resultsPathRoot) const
{
    if (relativeThumbnailPath.isEmpty()) {
        return QString();
    }

    // Thumbnail paths in uiData.xml are relative to testSets_results root
    // Paths now use Windows-style backslashes (e.g., MLB\Dodgers\...\image.jpg)
    // QDir::absoluteFilePath() handles both forward slashes and backslashes on Windows
    QDir resultsDir(resultsPathRoot);
    
    // Normalize the relative path first (convert forward slashes to backslashes on Windows if needed)
    QString normalizedRelative = QDir::toNativeSeparators(relativeThumbnailPath);
    QString absolutePath = resultsDir.absoluteFilePath(normalizedRelative);
    
    // Normalize path separators (QFileInfo will normalize to native separators)
    QFileInfo pathInfo(absolutePath);
    if (pathInfo.exists()) {
        // Return normalized absolute path with native separators (backslashes on Windows)
        return pathInfo.absoluteFilePath();
    }

    // Fallback: If the exact path doesn't exist, try to find an image in the parent directory structure
    // This handles cases where the comparison folder structure might be different
    QFileInfo originalPathInfo(absolutePath);
    QDir parentDir = originalPathInfo.absoluteDir();
    
    // Go up to the frame folder (F####) level and search for images in any subdirectory
    // Look for common image extensions
    QStringList imageExtensions = QStringList() << "*.jpg" << "*.jpeg" << "*.png" << "*.bmp";
    
    // Try searching in the parent directory and its subdirectories
    for (int level = 0; level < 3 && parentDir.exists(); ++level) {
        QDirIterator it(parentDir.absolutePath(), imageExtensions, QDir::Files, QDirIterator::Subdirectories);
        if (it.hasNext()) {
            QString foundPath = it.next();
            DEBUG_LOG("XmlDataLoader") << "Found fallback thumbnail:" << foundPath << "for original path:" << absolutePath;
            return QFileInfo(foundPath).absoluteFilePath();
        }
        // Go up one level
        if (!parentDir.cdUp()) {
            break;
        }
    }

    // Final fallback: If thumbnail not found in testSets_results and path looks like a folder path (Not Ready status),
    // try to find it in testSets directory instead
    // Check if the path ends with a frame folder pattern (F####) - indicates it's a folder path, not an image file
    // Reuse normalizedRelative that was already declared above
    QStringList parts = normalizedRelative.split(QRegExp("[\\\\/]"), QString::SkipEmptyParts);
    bool isFolderPath = false;
    if (!parts.isEmpty()) {
        QString lastPart = parts.last();
        // Check if last part is a frame folder (F followed by digits) or if it doesn't have an image extension
        if (lastPart.length() >= 2 && lastPart[0] == 'F') {
            bool isFrameFolder = true;
            for (int i = 1; i < lastPart.length(); ++i) {
                if (!lastPart[i].isDigit()) {
                    isFrameFolder = false;
                    break;
                }
            }
            if (isFrameFolder) {
                isFolderPath = true;
            }
        } else {
            // Check if it doesn't have an image extension
            QString lowerLastPart = lastPart.toLower();
            if (!lowerLastPart.endsWith(".jpg") && !lowerLastPart.endsWith(".jpeg") && 
                !lowerLastPart.endsWith(".png") && !lowerLastPart.endsWith(".bmp")) {
                isFolderPath = true;
            }
        }
    }
    
    if (isFolderPath && !m_testSetsPath.isEmpty()) {
        // This is a folder path (Not Ready status) - try to find it in testSets
        QDir testSetsDir(m_testSetsPath);
        QString testSetsAbsolutePath = testSetsDir.absoluteFilePath(normalizedRelative);
        QFileInfo testSetsPathInfo(testSetsAbsolutePath);
        
        if (testSetsPathInfo.exists() && testSetsPathInfo.isDir()) {
            // The folder exists in testSets - return the path to testSets
            DEBUG_LOG("XmlDataLoader") << "Thumbnail path points to testSets (Not Ready status):" << testSetsAbsolutePath;
            return testSetsPathInfo.absoluteFilePath();
        }
    }

    // Debug: log missing thumbnail
    DEBUG_LOG("XmlDataLoader") << "Thumbnail file not found:" << absolutePath;
    DEBUG_LOG("XmlDataLoader") << "  Relative path:" << relativeThumbnailPath;
    DEBUG_LOG("XmlDataLoader") << "  Results root:" << resultsPathRoot;
    if (isFolderPath) {
        DEBUG_LOG("XmlDataLoader") << "  Detected as folder path (Not Ready status), checked testSets:" << m_testSetsPath;
    }

    return QString(); // Return empty if file doesn't exist
}

QString XmlDataLoader::deriveTestKeyFromThumbnailPath(const QString &thumbnailPath) const
{
    if (thumbnailPath.isEmpty()) {
        return QString();
    }
    
    // Thumbnail path can be:
    // 1. Image file: SportType\Stadium\Event\Set\F####\freedview_X_VS_Y\freedview_X\image.jpg
    // 2. Folder path (Not Ready): SportType\Stadium\Event\Set\F####
    // TestKey format: SportType/Stadium/Event/Set/F#### (up to and including frame folder)
    
    // Normalize path separators
    QString normalizedPath = QDir::toNativeSeparators(thumbnailPath);
    
    // Split by path separators
    QStringList parts = normalizedPath.split(QRegExp("[\\\\/]"), QString::SkipEmptyParts);
    
    // Find the frame folder (F followed by digits, e.g., F0388, F1234)
    int frameFolderIndex = -1;
    for (int i = 0; i < parts.size(); ++i) {
        const QString &part = parts[i];
        if (part.length() >= 2 && part[0] == 'F') {
            // Check if the rest are digits
            bool isFrameFolder = true;
            for (int j = 1; j < part.length(); ++j) {
                if (!part[j].isDigit()) {
                    isFrameFolder = false;
                    break;
                }
            }
            if (isFrameFolder) {
                frameFolderIndex = i;
                break;
            }
        }
    }
    
    if (frameFolderIndex >= 0) {
        // Take everything up to and including the frame folder
        QStringList testKeyParts = parts.mid(0, frameFolderIndex + 1);
        // Join with forward slashes (normalized format)
        return testKeyParts.join("/");
    }
    
    // Fallback: if frame folder not found, return empty
    return QString();
}
