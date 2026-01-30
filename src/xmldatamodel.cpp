#include "xmldatamodel.h"
#include "xmldataloader.h"
#include "logger.h"
#include <QDirIterator>
#include <QStandardItem>
#include <QFileInfo>
#include <QDir>
#include <QDomDocument>
#include <QFile>
#include <QTextStream>
#include <QRegExp>
#include <QSet>
#include <QHash>
#include <QMutexLocker>

// Role names for QML access
enum {
    IdRole = Qt::UserRole + 1,
    EventNameRole,
    SportTypeRole,
    StadiumNameRole,
    CategoryNameRole,
    NumberOfFramesRole,
    MinValueRole,
    NotesRole,
    StatusRole,
    ThumbnailPathRole,
    TestKeyRole,
    RenderVersionsRole
};

/**
 * @brief Constructor - Initializes the model and background loading thread
 * 
 * Sets up column structure and creates a worker thread for non-blocking XML loading.
 * The worker thread prevents UI freezing when loading many XML files.
 */
XmlDataModel::XmlDataModel(QObject *parent)
    : QStandardItemModel(parent)
    , m_loaderThread(nullptr)
    , m_loader(nullptr)
{
    // Define table structure: 11 columns with headers (added testKey)
    setColumnCount(11);
    setHorizontalHeaderLabels(QStringList()
        << "ID"
        << "Event Name"
        << "Sport Type"
        << "Stadium Name"
        << "Category Name"
        << "Number Of Frames"
        << "Min Value"
        << "Notes"
        << "Status"
        << "Thumbnail"
        << "Test Key");
    
    // Create worker thread for background XML parsing
    // This prevents UI freezing when loading many files
    m_loaderThread = new QThread(this);
    m_loader = new XmlDataLoader();
    m_loader->moveToThread(m_loaderThread);  // Move loader to background thread
    
    // Connect signals from loader to model using queued connections
    // QueuedConnection ensures thread-safe communication between threads:
    // - Background thread emits signals
    // - Main thread receives them and updates the model
    // This is required because QStandardItemModel must be accessed from main thread only
    connect(m_loader, &XmlDataLoader::loadingStarted, this, &XmlDataModel::loadingStarted, Qt::QueuedConnection);
    connect(m_loader, &XmlDataLoader::rowLoaded, this, &XmlDataModel::onRowLoaded, Qt::QueuedConnection);
    connect(m_loader, &XmlDataLoader::loadingFinished, this, &XmlDataModel::loadingFinished, Qt::QueuedConnection);
    connect(m_loader, &XmlDataLoader::errorOccurred, this, &XmlDataModel::errorOccurred, Qt::QueuedConnection);
    connect(m_loader, &XmlDataLoader::renderVersionsLoaded, this, &XmlDataModel::onRenderVersionsLoaded, Qt::QueuedConnection);

    // Start the background thread (it will wait for loadData() to be called)
    m_loaderThread->start();
}

/**
 * @brief Destructor - Safely shuts down background thread
 * 
 * Ensures proper cleanup of the worker thread and loader object.
 * Moves loader back to main thread before deletion (Qt requirement).
 */
XmlDataModel::~XmlDataModel()
{
    if (m_loaderThread) {
        // Signal thread to stop processing
        m_loaderThread->quit();
        if (!m_loaderThread->wait(3000)) {
            // Thread didn't finish within timeout - force termination
            ERROR_LOG("XmlDataModel destructor: Thread did not finish within timeout, terminating");
            m_loaderThread->terminate();
            m_loaderThread->wait(1000);  // Wait additional second for termination
        }
        
        // IMPORTANT: Objects must be deleted in the thread they belong to
        // Move loader back to main thread before deleting
        if (m_loader) {
            m_loader->moveToThread(QThread::currentThread());
            delete m_loader;
            m_loader = nullptr;
        }
        delete m_loaderThread;
        m_loaderThread = nullptr;
    }
}

QHash<int, QByteArray> XmlDataModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[EventNameRole] = "eventName";
    roles[SportTypeRole] = "sportType";
    roles[StadiumNameRole] = "stadiumName";
    roles[CategoryNameRole] = "categoryName";
    roles[NumberOfFramesRole] = "numberOfFrames";
    roles[MinValueRole] = "minValue";
    roles[NotesRole] = "notes";
    roles[StatusRole] = "status";
    roles[ThumbnailPathRole] = "thumbnailPath";
    roles[TestKeyRole] = "testKey";
    roles[RenderVersionsRole] = "renderVersions";
    return roles;
}

QVariant XmlDataModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount() || index.column() >= columnCount()) {
        return QVariant();
    }

    // Map role names to columns
    int column = -1;
    if (role == IdRole) {
        column = 0;
    } else if (role == EventNameRole) {
        column = 1;
    } else if (role == SportTypeRole) {
        column = 2;
    } else if (role == StadiumNameRole) {
        column = 3;
    } else if (role == CategoryNameRole) {
        column = 4;
    } else if (role == NumberOfFramesRole) {
        column = 5;
    } else if (role == MinValueRole) {
        column = 6;
    } else if (role == NotesRole) {
        column = 7;
    } else if (role == StatusRole) {
        column = 8;
    } else if (role == ThumbnailPathRole) {
        // Thumbnail path is stored in column 9 (index 9)
        column = 9;
    } else if (role == TestKeyRole) {
        // Test key is stored in column 10 (index 10)
        column = 10;
    } else if (role == RenderVersionsRole) {
        // Render versions is stored in column 11 (index 11)
        column = 11;
    } else if (role == Qt::DisplayRole) {
        // Default display role - return data from the column
        return QStandardItemModel::data(index, role);
    } else {
        return QStandardItemModel::data(index, role);
    }

    if (column >= 0) {
        QModelIndex columnIndex = this->index(index.row(), column);
        return QStandardItemModel::data(columnIndex, Qt::DisplayRole);
    }

    return QVariant();
}

QString XmlDataModel::getThumbnailPath(int rowIndex) const
{
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        return QString();
    }
    // Thumbnail path is stored in column 9
    QModelIndex thumbnailIndex = index(rowIndex, 9);
    return data(thumbnailIndex, Qt::DisplayRole).toString();
}

QString XmlDataModel::getTestKey(int rowIndex) const
{
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        return QString();
    }
    
    // Test key is already stored in column 10 (index 10) - just read it directly
    QModelIndex testKeyIndex = index(rowIndex, 10);
    QString testKey = data(testKeyIndex, Qt::DisplayRole).toString();
    
    // If testKey is absolute path (starts with drive letter or contains "testSets_results"), extract relative part
    if (!testKey.isEmpty()) {
        QStringList parts = testKey.split(QRegExp("[\\\\/]"), QString::SkipEmptyParts);
        
        // Check if path is absolute (contains drive letter or full path)
        bool isAbsolute = false;
        int startIndex = 0;
        
        // Check for Windows drive letter (e.g., "F:", "C:")
        if (parts.size() > 0 && parts[0].length() == 2 && parts[0].endsWith(':')) {
            isAbsolute = true;
            startIndex = 1; // Skip drive letter
        }
        
        // Check if path contains "testSets_results" - skip everything up to and including it
        for (int i = 0; i < parts.size(); ++i) {
            if (parts[i].compare("testSets_results", Qt::CaseInsensitive) == 0) {
                isAbsolute = true;
                startIndex = i + 1; // Skip testSets_results and everything before it
                break;
            }
        }
        
        // If absolute, extract the relative part (from testSets_results onward)
        if (isAbsolute && startIndex > 0 && startIndex < parts.size()) {
            // Find the frame folder (F####) in the remaining parts
            int frameFolderIndex = -1;
            for (int i = startIndex; i < parts.size(); ++i) {
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
                // Take everything from startIndex up to and including the frame folder
                QStringList testKeyParts = parts.mid(startIndex, frameFolderIndex - startIndex + 1);
                // Join with forward slashes (normalized format)
                testKey = testKeyParts.join("/");
            } else {
                // No frame folder found, use everything from startIndex
                QStringList testKeyParts = parts.mid(startIndex);
                testKey = testKeyParts.join("/");
            }
        }
    }
    
    // If testKey is still empty, fallback to deriving from thumbnailPath (backward compatibility)
    if (testKey.isEmpty()) {
        QString thumbnailPath = getThumbnailPath(rowIndex);
        if (!thumbnailPath.isEmpty()) {
            // Extract testKey from thumbnailPath by finding frame folder (F####)
            QStringList parts = thumbnailPath.split(QRegExp("[\\\\/]"), QString::SkipEmptyParts);
            
            // Check if absolute path - find testSets_results and start from there
            int startIndex = 0;
            for (int i = 0; i < parts.size(); ++i) {
                if (parts[i].compare("testSets_results", Qt::CaseInsensitive) == 0) {
                    startIndex = i + 1;
                    break;
                }
            }
            
            // Find the frame folder (F followed by digits)
            int frameFolderIndex = -1;
            for (int i = startIndex; i < parts.size(); ++i) {
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
                // Take everything from startIndex up to and including the frame folder
                QStringList testKeyParts = parts.mid(startIndex, frameFolderIndex - startIndex + 1);
                // Join with forward slashes (normalized format)
                return testKeyParts.join("/");
            }
        }
    }
    
    return testKey;
}

/**
 * @brief Get column width ratio (0.0 to 1.0) for a given column index
 * 
 * Returns the proportional width ratio for each column. These ratios are multiplied
 * by the table viewport width in QML to calculate actual pixel widths.
 * 
 * To adjust column widths:
 * 1. Modify the values in the widths[] array below
 * 2. Ensure values sum to approximately 1.0 (100% of available width)
 * 3. Rebuild the project
 * 
 * @param columnIndex - The column index (0-based)
 * @return Width ratio as a double (e.g., 0.175 = 17.5% of viewport width)
 */
double XmlDataModel::getColumnWidthRatio(int columnIndex) const
{
    // Proportional widths for columns - adjust these values to change column sizes
    // Values are ratios (0.0 to 1.0) that sum to 1.0 (fill all available width)
    // Column order: ID, Thumbnail, Event Name, Sport Type, Stadium Name, Category Name,
    //               Number Of Frames, Min Value, Notes, Status
    static const double widths[] = {
        0.030,  // ID (3.0%)
        0.130,  // Thumbnail (13.0%)
        0.151,  // Event Name (15.1%)
        0.065,  // Sport Type (6.5%)
        0.130,  // Stadium Name (13.0%)
        0.130,  // Category Name (13.0%)
        0.086,  // Number Of Frames (8.6%)
        0.086,  // Min Value (8.6%)
        0.126,  // Notes (12.6%)
        0.065   // Status (6.5%)
    };
    const int maxColumns = sizeof(widths) / sizeof(widths[0]);

    if (columnIndex >= 0 && columnIndex < maxColumns) {
        return widths[columnIndex];
    }
    // Default: equal width for any extra columns
    const int cols = columnCount();
    return cols > 0 ? 1.0 / cols : 1.0;
}

int XmlDataModel::rowCount(const QModelIndex &parent) const
{
    return QStandardItemModel::rowCount(parent);
}

bool XmlDataModel::loadData(const QString &resultsPath, const QString &selectedVersion, const QString &testSetsPath)
{
    Q_UNUSED(selectedVersion);
    
    if (resultsPath.isEmpty()) {
        emit errorOccurred("Results path is empty");
        return false;
    }

    // Store results path for accessing compareResult.xml files later
    m_resultsPath = resultsPath;

    // Clear existing data and render versions (will be reloaded from XML)
    clear();
    m_renderVersions.clear();
    clearXmlCache();  // Clear XML parsing cache when reloading
    setColumnCount(12);  // 12 columns including testKey and renderVersions
    setHorizontalHeaderLabels(QStringList()
        << "ID"
        << "Event Name"
        << "Sport Type"
        << "Stadium Name"
        << "Category Name"
        << "Number Of Frames"
        << "Min Value"
        << "Notes"
        << "Status"
        << "Thumbnail"
        << "Test Key"
        << "Render Versions");

    // Start loading in background thread
    if (m_loader) {
        QMetaObject::invokeMethod(m_loader, "loadData", Qt::QueuedConnection, 
                                  Q_ARG(QString, resultsPath), 
                                 Q_ARG(QString, testSetsPath));
    return true;
    }
    
    return false;
}

/**
 * @brief Slot called when a row has been loaded in background thread
 * 
 * This slot is invoked on the main thread via queued connection, making it
 * safe to update the QStandardItemModel (which must be accessed from main thread only).
 * 
 * @param rowData - List of column values: [id, eventName, sportType, stadiumName, 
 *                  categoryName, numberOfFrames, minValue, notes, status, thumbnailPath]
 * @param xmlPath - Path to the XML file that was parsed
 */
void XmlDataModel::onRowLoaded(const QVariantList &rowData, const QString &xmlPath)
{
    Q_UNUSED(xmlPath);  // Not used anymore since we load from uiData.xml instead of individual XML files
    // Validate data size (should have 12 elements: id placeholder + 11 data columns including testKey and renderVersions)
    if (rowData.size() < 12) {
        return; // Invalid data, skip this row
    }
    
    // Generate sequential ID based on current row count
    const int rowId = rowCount();
    
    // Create QStandardItem objects for each column
    // These will be owned by the model and automatically deleted
    QList<QStandardItem*> rowItems;
    rowItems.reserve(12);
    
    // Use ID from XML if provided, otherwise use row count
    QString idStr = rowData[0].toString();
    if (idStr.isEmpty()) {
        idStr = QString::number(rowId);
    }
    
    rowItems << new QStandardItem(idStr);                       // ID (from XML or sequential)
    rowItems << new QStandardItem(rowData[1].toString());        // eventName
    rowItems << new QStandardItem(rowData[2].toString());        // sportType
    rowItems << new QStandardItem(rowData[3].toString());        // stadiumName
    rowItems << new QStandardItem(rowData[4].toString());        // categoryName
    rowItems << new QStandardItem(rowData[5].toString());        // numberOfFrames
    rowItems << new QStandardItem(rowData[6].toString());        // minValue
    rowItems << new QStandardItem(rowData[7].toString());        // notes
    rowItems << new QStandardItem(rowData[8].toString());        // status
    rowItems << new QStandardItem(rowData[9].toString());       // thumbnailPath (already absolute path)
    rowItems << new QStandardItem(rowData[10].toString());      // testKey
    rowItems << new QStandardItem(rowData[11].toString());      // renderVersions (comma-separated list)

    // Add row to model (this triggers QML updates)
    appendRow(rowItems);
    
    // Notify QML that data has changed (updates table view)
    emit dataChanged();
}

/**
 * @brief Slot called when render versions are loaded from uiData.xml
 * 
 * This slot stores the render version list in the model so it can be retrieved
 * via getFreeDViewVerList() to populate the combo box in the UI.
 * 
 * @param versionList - List of render version folder names (e.g., "freedview_1.2.1.3_1.0.0.7_VS_freedView_1.3.0.0_1.0.0.1")
 */
void XmlDataModel::onRenderVersionsLoaded(const QStringList &versionList)
{
    m_renderVersions = versionList;
    DEBUG_LOG("XmlDataModel") << "onRenderVersionsLoaded - Stored" << versionList.size() << "render version(s)";
}

bool XmlDataModel::updateCell(int rowIndex, int columnIndex, const QString &newValue)
{
    if (rowIndex < 0 || rowIndex >= rowCount() || columnIndex < 0 || columnIndex >= columnCount()) {
        DEBUG_LOG("XmlDataModel") << "updateCell - Invalid row or column index";
        return false;
    }

    // Get the model index
    QModelIndex index = this->index(rowIndex, columnIndex);
    if (!index.isValid()) {
        DEBUG_LOG("XmlDataModel") << "updateCell - Invalid model index";
        return false;
    }
    
    // Update the data
    // Note: setData() automatically emits QStandardItemModel::dataChanged() signal
    // which notifies views of the change
    bool success = setData(index, newValue, Qt::EditRole);
    
    if (success) {
        // Emit custom dataChanged signal for QML property binding
        emit dataChanged();
        DEBUG_LOG("XmlDataModel") << "updateCell - Successfully updated row" << rowIndex << "column" << columnIndex << "to" << newValue;
    } else {
        DEBUG_LOG("XmlDataModel") << "updateCell - Failed to set data";
    }
    
    return success;
}

bool XmlDataModel::saveToXml(const QString &resultsPath)
{
    if (resultsPath.isEmpty()) {
        ERROR_LOG("XmlDataModel::saveToXml - Results path is empty");
        return false;
    }
    
    // Construct path to uiData.xml
    QDir resultsDir(resultsPath);
    QString uiDataXmlPath = resultsDir.absoluteFilePath("uiData.xml");
    
    // Read existing XML file completely to preserve all data
    QDomDocument doc;
    QFile existingFile(uiDataXmlPath);
    bool fileExists = existingFile.exists();
    
    if (fileExists && existingFile.open(QIODevice::ReadOnly)) {
        QString errorMsg;
        int errorLine, errorColumn;
        if (!doc.setContent(&existingFile, &errorMsg, &errorLine, &errorColumn)) {
            existingFile.close();
            ERROR_LOG("XmlDataModel::saveToXml - Failed to parse existing XML file:" + errorMsg + " at line " + QString::number(errorLine));
            return false;
        }
        existingFile.close();
        DEBUG_LOG("XmlDataModel") << "saveToXml - Loaded existing XML file";
    } else {
        // File doesn't exist, create new document
        QDomProcessingInstruction pi = doc.createProcessingInstruction("xml", "version=\"1.0\" encoding=\"UTF-8\"");
        doc.appendChild(pi);
        QDomElement rootElement = doc.createElement("uiData");
        doc.appendChild(rootElement);
        QDomElement entriesElement = doc.createElement("entries");
        rootElement.appendChild(entriesElement);
        DEBUG_LOG("XmlDataModel") << "saveToXml - Creating new XML file";
    }
    
    // Find or create root element
    QDomNodeList uiDataNodes = doc.elementsByTagName("uiData");
    QDomElement rootElement;
    if (uiDataNodes.isEmpty()) {
        rootElement = doc.createElement("uiData");
        doc.appendChild(rootElement);
    } else {
        rootElement = uiDataNodes.item(0).toElement();
    }
    
    // Find or create entries element
    QDomElement entriesElement = rootElement.firstChildElement("entries");
    if (entriesElement.isNull()) {
        entriesElement = doc.createElement("entries");
        rootElement.appendChild(entriesElement);
    }
    
    // Build a map of model row IDs to row indices for quick lookup
    QHash<QString, int> idToRowMap;
    for (int row = 0; row < rowCount(); ++row) {
        QString id = data(index(row, 0), Qt::DisplayRole).toString();
        if (!id.isEmpty()) {
            idToRowMap[id] = row;
        }
    }
    
    // Update existing entries or create new ones
    QDomNodeList entryNodes = entriesElement.elementsByTagName("entry");
    QSet<QString> processedIds;
    
    // Process existing entries
    for (int i = 0; i < entryNodes.size(); ++i) {
        QDomElement entryElement = entryNodes.item(i).toElement();
        if (entryElement.isNull()) continue;
        
        QDomElement idElement = entryElement.firstChildElement("id");
        if (idElement.isNull()) continue;
        
        QString entryId = idElement.text().trimmed();
        processedIds.insert(entryId);
        
        // Check if this entry exists in the model
        if (idToRowMap.contains(entryId)) {
            int row = idToRowMap[entryId];
            
            // Update editable fields from model, preserve everything else
            // Map: model column -> XML element name
            struct FieldMapping {
                int modelColumn;
                QString xmlElementName;
            };
            
            FieldMapping mappings[] = {
                {1, "eventName"},
                {2, "sportType"},
                {3, "stadiumName"},
                {4, "categoryName"},
                {5, "numberOfFrames"},
                {6, "minValue"},
                {7, "notes"},
                {8, "status"}
            };
            
            for (const FieldMapping &mapping : mappings) {
                QString newValue = data(index(row, mapping.modelColumn), Qt::DisplayRole).toString();
                QDomElement fieldElement = entryElement.firstChildElement(mapping.xmlElementName);
                if (fieldElement.isNull()) {
                    // Create element if it doesn't exist
                    fieldElement = doc.createElement(mapping.xmlElementName);
                    entryElement.appendChild(fieldElement);
                }
                // Update text content
                QDomNode textNode = fieldElement.firstChild();
                if (textNode.isNull() || !textNode.isText()) {
                    fieldElement.appendChild(doc.createTextNode(newValue));
                } else {
                    textNode.toText().setData(newValue);
                }
            }
            
            DEBUG_LOG("XmlDataModel") << "saveToXml - Updated entry ID:" << entryId;
        }
        // If entry doesn't exist in model, keep it as-is (preserve all fields)
    }
    
    // Add new entries from model that don't exist in XML
    for (int row = 0; row < rowCount(); ++row) {
        QString id = data(index(row, 0), Qt::DisplayRole).toString();
        if (id.isEmpty() || processedIds.contains(id)) {
            continue; // Skip if already processed or no ID
        }
        
        // Create new entry element
        QDomElement entryElement = doc.createElement("entry");
        
        // Get data from model
        QString eventName = data(index(row, 1), Qt::DisplayRole).toString();
        QString sportType = data(index(row, 2), Qt::DisplayRole).toString();
        QString stadiumName = data(index(row, 3), Qt::DisplayRole).toString();
        QString categoryName = data(index(row, 4), Qt::DisplayRole).toString();
        QString numberOfFrames = data(index(row, 5), Qt::DisplayRole).toString();
        QString minValue = data(index(row, 6), Qt::DisplayRole).toString();
        QString notes = data(index(row, 7), Qt::DisplayRole).toString();
        QString status = data(index(row, 8), Qt::DisplayRole).toString();
        QString thumbnailPath = data(index(row, 9), Qt::DisplayRole).toString();
        QString renderVersions = data(index(row, 11), Qt::DisplayRole).toString();
        
        // Create child elements
        auto createElement = [&](const QString &name, const QString &value) {
            QDomElement elem = doc.createElement(name);
            elem.appendChild(doc.createTextNode(value));
            entryElement.appendChild(elem);
        };
        
        createElement("id", id);
        createElement("eventName", eventName);
        createElement("sportType", sportType);
        createElement("stadiumName", stadiumName);
        createElement("categoryName", categoryName);
        createElement("numberOfFrames", numberOfFrames);
        createElement("minValue", minValue);
        createElement("numFramesUnderMin", "0");
        createElement("thumbnailPath", thumbnailPath);
        createElement("status", status);
        createElement("notes", notes);
        if (!renderVersions.isEmpty()) {
            createElement("renderVersions", renderVersions);
        }
        
        entriesElement.appendChild(entryElement);
        DEBUG_LOG("XmlDataModel") << "saveToXml - Added new entry ID:" << id;
    }
    
    // Write to file
    QFile file(uiDataXmlPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        ERROR_LOG("XmlDataModel::saveToXml - Failed to open file for writing:" + uiDataXmlPath);
        return false;
    }
    
    QTextStream out(&file);
    out.setCodec("UTF-8");
    doc.save(out, 4); // Indent with 4 spaces
    file.close();
    
    DEBUG_LOG("XmlDataModel") << "saveToXml - Successfully saved" << rowCount() << "entries to" << uiDataXmlPath;
    return true;
}

QStringList XmlDataModel::getFreeDViewVerList() const
{
    // First, try to use render versions from uiData.xml (if loaded)
    if (!m_renderVersions.isEmpty()) {
        DEBUG_LOG("XmlDataModel") << "getFreeDViewVerList - Returning" << m_renderVersions.size() << "render version(s) from uiData.xml";
        return m_renderVersions;
    }
    
    // Fallback: Scan all rows to extract unique version combinations from testKey paths
    // This is a fallback for backward compatibility when renderVersions section is not in XML
    DEBUG_LOG("XmlDataModel") << "getFreeDViewVerList - No render versions in memory, falling back to path extraction";
    QStringList versionList;
    QSet<QString> uniqueVersions;
    
    // Path format: .../eventSet/FRAME/freedviewVersion/...
    // Version format in path: "origFreeDView_VS_testFreeDView" or similar
    for (int row = 0; row < rowCount(); ++row) {
        QString testKey = getTestKey(row);
        if (testKey.isEmpty()) {
            continue;
        }
        
        // Extract version from path
        // Look for patterns like ".../FRAME/freedviewVersion/..." in the path
        QRegExp versionPattern("/([^/]+_VS_[^/]+)/");
        if (versionPattern.indexIn(testKey) >= 0) {
            QString version = versionPattern.cap(1);
            if (!version.isEmpty() && !uniqueVersions.contains(version)) {
                uniqueVersions.insert(version);
                versionList.append(version);
            }
        }
    }
    
    // If no versions found in paths, return empty list
    // TopLayout_zero will handle empty list gracefully
    return versionList;
}

// Implementation of functions for accessing compareResult.xml data

void XmlDataModel::clearXmlCache() const
{
    QMutexLocker locker(&m_cacheMutex);
    m_parsedXmlCache.clear();
    DEBUG_LOG("XmlDataModel") << "clearXmlCache - Cleared XML parsing cache";
}

bool XmlDataModel::getParsedXmlData(int rowIndex, ParsedXmlData &parsedData) const
{
    // Thread safety: Protect cache access with mutex
    // Cache can be accessed from main thread (QML getters) while background thread loads data
    QMutexLocker locker(&m_cacheMutex);
    
    // Check cache first
    if (m_parsedXmlCache.contains(rowIndex)) {
        parsedData = m_parsedXmlCache[rowIndex];
        // Verify the cached XML path still exists
        if (!parsedData.xmlPath.isEmpty() && QFile::exists(parsedData.xmlPath)) {
            DEBUG_LOG("XmlDataModel") << "getParsedXmlData - Cache hit for rowIndex:" << rowIndex;
            return true;
        } else {
            // Cache entry is stale, remove it
            m_parsedXmlCache.remove(rowIndex);
            DEBUG_LOG("XmlDataModel") << "getParsedXmlData - Cache entry stale, removed for rowIndex:" << rowIndex;
        }
    }
    
    // Release mutex before parsing XML (parsing can take time and doesn't need lock)
    locker.unlock();
    
    // Cache miss or stale - parse XML
    QString xmlPath = findCompareResultXml(rowIndex);
    if (xmlPath.isEmpty()) {
        return false;
    }
    
    // Parse XML
    int startFrame = -1;
    int endFrame = -1;
    double minVal = -1.0, maxVal = -1.0;
    QVariantList frameList_frame, frameList_val;
    QStringList outputPathList;
    QString origFreeDViewName, testFreeDViewName;
    
    if (!parseCompareResultXml(xmlPath, startFrame, endFrame, minVal, maxVal,
                               frameList_frame, frameList_val, outputPathList,
                               origFreeDViewName, testFreeDViewName)) {
        return false;
    }
    
    // Re-acquire mutex before writing to cache
    locker.relock();
    
    // Store in cache
    parsedData.startFrame = startFrame;
    parsedData.endFrame = endFrame;
    parsedData.minVal = minVal;
    parsedData.maxVal = maxVal;
    parsedData.frameList_frame = frameList_frame;
    parsedData.frameList_val = frameList_val;
    parsedData.outputPathList = outputPathList;
    parsedData.origFreeDViewName = origFreeDViewName;
    parsedData.testFreeDViewName = testFreeDViewName;
    parsedData.xmlPath = xmlPath;
    
    m_parsedXmlCache[rowIndex] = parsedData;
    DEBUG_LOG("XmlDataModel") << "getParsedXmlData - Parsed and cached for rowIndex:" << rowIndex;
    
    return true;
}

QString XmlDataModel::findCompareResultXml(int rowIndex) const
{
    if (rowIndex < 0 || rowIndex >= rowCount() || m_resultsPath.isEmpty()) {
        DEBUG_LOG("XmlDataModel") << "findCompareResultXml - Invalid rowIndex or empty resultsPath. rowIndex:" << rowIndex << "rowCount:" << rowCount() << "resultsPath:" << m_resultsPath;
        return QString();
    }
    
    // Get eventName from the model (column 1)
    QModelIndex eventNameIndex = index(rowIndex, 1);
    QString eventName = data(eventNameIndex, Qt::DisplayRole).toString();
    DEBUG_LOG("XmlDataModel") << "findCompareResultXml - rowIndex:" << rowIndex << "eventName:" << eventName;
    
    // Get testKey for this row
    QString testKey = getTestKey(rowIndex);
    DEBUG_LOG("XmlDataModel") << "findCompareResultXml - testKey:" << testKey;
    
    // Try multiple strategies to find compareResult.xml:
    // 1. Use eventName as eventSet folder name
    // 2. Use first part of testKey
    // 3. Search recursively from testKey path
    
    QStringList searchPaths;
    
    // Strategy 1: Use eventName directly
    if (!eventName.isEmpty()) {
        QDir resultsDir(m_resultsPath);
        QString path1 = resultsDir.absoluteFilePath(eventName + "/results/compareResult.xml");
        searchPaths.append(QDir::toNativeSeparators(path1));
    }
    
    // Strategy 2: Use testKey parts
    if (!testKey.isEmpty()) {
        QStringList parts = testKey.split("/", QString::SkipEmptyParts);
        if (!parts.isEmpty()) {
            // Try first part as eventSet
            QDir resultsDir(m_resultsPath);
            QString path2 = resultsDir.absoluteFilePath(parts[0] + "/results/compareResult.xml");
            searchPaths.append(QDir::toNativeSeparators(path2));
            
            // Try building path from testKey: testKey/results/compareResult.xml
            QString path3 = resultsDir.absoluteFilePath(testKey + "/results/compareResult.xml");
            searchPaths.append(QDir::toNativeSeparators(path3));
        }
    }
    
    // Strategy 3: Search recursively for compareResult.xml files
    // This is more expensive but more reliable
    QDirIterator it(m_resultsPath, QStringList() << "compareResult.xml", 
                    QDir::Files, QDirIterator::Subdirectories);
    QStringList foundFiles;
    while (it.hasNext()) {
        QString foundPath = it.next();
        QFileInfo fileInfo(foundPath);
        QString dirName = fileInfo.dir().dirName();
        
        // Check if the directory name matches eventName or testKey parts
        if (!eventName.isEmpty() && dirName.contains(eventName, Qt::CaseInsensitive)) {
            foundFiles.append(foundPath);
        } else if (!testKey.isEmpty()) {
            QStringList parts = testKey.split("/", QString::SkipEmptyParts);
            for (const QString &part : parts) {
                if (foundPath.contains(part, Qt::CaseInsensitive)) {
                    foundFiles.append(foundPath);
                    break;
                }
            }
        }
    }
    
    // Add found files to search paths (prioritize them)
    searchPaths = foundFiles + searchPaths;
    
    // Try each path
    for (const QString &compareResultPath : searchPaths) {
        DEBUG_LOG("XmlDataModel") << "findCompareResultXml - Trying:" << compareResultPath;
        QFileInfo fileInfo(compareResultPath);
        if (fileInfo.exists() && fileInfo.isFile()) {
            DEBUG_LOG("XmlDataModel") << "findCompareResultXml - Found file:" << compareResultPath;
            return compareResultPath;
        }
    }
    
    DEBUG_LOG("XmlDataModel") << "findCompareResultXml - File not found after trying" << searchPaths.size() << "paths";
    return QString();
}

bool XmlDataModel::parseCompareResultXml(const QString &xmlPath, int &startFrame, int &endFrame,
                                         double &minVal, double &maxVal,
                                         QVariantList &frameList_frame, QVariantList &frameList_val,
                                         QStringList &outputPathList,
                                         QString &origFreeDViewName, QString &testFreeDViewName) const
{
    // Initialize output parameters
    startFrame = -1;
    endFrame = -1;
    minVal = -1.0;
    maxVal = -1.0;
    frameList_frame.clear();
    frameList_val.clear();
    outputPathList.clear();
    origFreeDViewName.clear();
    testFreeDViewName.clear();
    
    if (xmlPath.isEmpty()) {
        return false;
    }
    
    QFile file(xmlPath);
    if (!file.open(QIODevice::ReadOnly)) {
        ERROR_LOG("XmlDataModel::parseCompareResultXml - Failed to open file:" + xmlPath);
        return false;
    }
    
    QDomDocument doc;
    QString errorMsg;
    int errorLine, errorColumn;
    if (!doc.setContent(&file, &errorMsg, &errorLine, &errorColumn)) {
        file.close();
        ERROR_LOG(QString("XmlDataModel::parseCompareResultXml - Failed to parse XML: %1 Error: %2 at line %3").arg(xmlPath).arg(errorMsg).arg(errorLine));
        return false;
    }
    file.close();
    
    // Find root element (usually "compareResult" or similar)
    QDomElement root = doc.documentElement();
    if (root.isNull()) {
        ERROR_LOG("XmlDataModel::parseCompareResultXml - No root element found");
        return false;
    }
    
    DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - Root element:" << root.tagName();
    
    // Extract frame data
    // The structure may vary, but typically contains:
    // - startFrame, endFrame
    // - minVal, maxVal
    // - frameList with frame numbers and values
    // - output paths
    // - FreeDView names
    
    QDomElement startFrameElem = root.firstChildElement("startFrame");
    if (!startFrameElem.isNull()) {
        startFrame = startFrameElem.text().toInt();
        DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - Found startFrame:" << startFrame;
    } else {
        DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - startFrame element not found";
    }
    
    QDomElement endFrameElem = root.firstChildElement("endFrame");
    if (!endFrameElem.isNull()) {
        endFrame = endFrameElem.text().toInt();
    }
    
    QDomElement minValElem = root.firstChildElement("minVal");
    if (!minValElem.isNull()) {
        minVal = minValElem.text().toDouble();
    }
    
    QDomElement maxValElem = root.firstChildElement("maxVal");
    if (!maxValElem.isNull()) {
        maxVal = maxValElem.text().toDouble();
    }
    
    // Parse frame list
    // XML structure: <frames><frame><frameIndex>...</frameIndex><value>...</value></frame></frames>
    QDomElement framesElem = root.firstChildElement("frames");
    if (!framesElem.isNull()) {
        QDomNodeList frameNodes = framesElem.elementsByTagName("frame");
        DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - Found" << frameNodes.size() << "frame elements";
        for (int i = 0; i < frameNodes.size(); ++i) {
            QDomElement frameElem = frameNodes.at(i).toElement();
            if (!frameElem.isNull()) {
                QDomElement frameIndexElem = frameElem.firstChildElement("frameIndex");
                QDomElement frameValElem = frameElem.firstChildElement("value");
                if (!frameIndexElem.isNull() && !frameValElem.isNull()) {
                    frameList_frame.append(frameIndexElem.text().toInt());
                    frameList_val.append(frameValElem.text().toDouble());
                }
            }
        }
        DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - Parsed" << frameList_frame.size() << "frames";
        } else {
        DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - frames element not found";
    }
    
    // Extract output paths
    // XML structure: <sourcePath>...</sourcePath><testPath>...</testPath><diffPath>...</diffPath><alphaPath>...</alphaPath>
    // These are direct children of root, not under an outputPaths element
    QDomElement sourcePathElem = root.firstChildElement("sourcePath");
    QDomElement testPathElem = root.firstChildElement("testPath");
    QDomElement diffPathElem = root.firstChildElement("diffPath");
    QDomElement alphaPathElem = root.firstChildElement("alphaPath");
    
    if (!sourcePathElem.isNull()) {
        QString sourcePath = sourcePathElem.text();
        // Convert relative path to absolute if needed
        if (!sourcePath.isEmpty() && !QDir::isAbsolutePath(sourcePath)) {
            QDir resultsDir(m_resultsPath);
            sourcePath = resultsDir.absoluteFilePath(sourcePath);
        }
        outputPathList.append(QDir::toNativeSeparators(sourcePath));
    }
    if (!testPathElem.isNull()) {
        QString testPath = testPathElem.text();
        if (!testPath.isEmpty() && !QDir::isAbsolutePath(testPath)) {
            QDir resultsDir(m_resultsPath);
            testPath = resultsDir.absoluteFilePath(testPath);
        }
        outputPathList.append(QDir::toNativeSeparators(testPath));
    }
    if (!diffPathElem.isNull()) {
        QString diffPath = diffPathElem.text();
        if (!diffPath.isEmpty() && !QDir::isAbsolutePath(diffPath)) {
            QDir resultsDir(m_resultsPath);
            diffPath = resultsDir.absoluteFilePath(diffPath);
        }
        outputPathList.append(QDir::toNativeSeparators(diffPath));
    }
    if (!alphaPathElem.isNull()) {
        QString alphaPath = alphaPathElem.text();
        if (!alphaPath.isEmpty() && !QDir::isAbsolutePath(alphaPath)) {
            QDir resultsDir(m_resultsPath);
            alphaPath = resultsDir.absoluteFilePath(alphaPath);
        }
        outputPathList.append(QDir::toNativeSeparators(alphaPath));
    }
    
    DEBUG_LOG("XmlDataModel") << "parseCompareResultXml - Found" << outputPathList.size() << "output paths";
    
    // Extract FreeDView names
    QDomElement origFreeDViewElem = root.firstChildElement("origFreeDView");
    if (!origFreeDViewElem.isNull()) {
        origFreeDViewName = origFreeDViewElem.text();
    }
    
    QDomElement testFreedviewElem = root.firstChildElement("testFreedview");
    if (!testFreedviewElem.isNull()) {
        testFreeDViewName = testFreedviewElem.text();
    }
    
    return true;
}

int XmlDataModel::getStartFrame(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getStartFrame - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return -1;
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.startFrame;
    }
    
    return -1;
}

int XmlDataModel::getEndFrame(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getEndFrame - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return -1;
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.endFrame;
    }
    
    return -1;
}

double XmlDataModel::getMinVal(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getMinVal - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return -1.0;
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.minVal;
    }
    
    return -1.0;
}

double XmlDataModel::getMaxVal(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getMaxVal - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return -1.0;
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.maxVal;
    }
    
    return -1.0;
}

QVariantList XmlDataModel::getFrameList_frame(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getFrameList_frame - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return QVariantList();
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.frameList_frame;
    }
    
    return QVariantList();
}

QVariantList XmlDataModel::getFrameList_val(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getFrameList_val - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return QVariantList();
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.frameList_val;
    }
    
    return QVariantList();
}

QStringList XmlDataModel::getOutputPathList(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getOutputPathList - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return QStringList();
    }
    
    ParsedXmlData parsedData;
    if (getParsedXmlData(rowIndex, parsedData)) {
        return parsedData.outputPathList;
    }
    
    return QStringList();
}

QString XmlDataModel::getOrigFreeDViewName(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getOrigFreeDViewName - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return QString();
    }
    
    // Read renderVersions from column 11 (uiData.xml)
    QString renderVersions = data(index(rowIndex, 11), Qt::DisplayRole).toString();
    
    if (renderVersions.isEmpty()) {
        DEBUG_LOG("XmlDataModel") << "getOrigFreeDViewName - renderVersions is empty for row:" << rowIndex;
        return QString();
    }
    
    // Split by "_VS_" to get the two version names
    // Format: "freedview_1.3.2.0_1.0.0.3_VS_freedview_1.3.5.0_1.0.0.0"
    QStringList versions = renderVersions.split("_VS_", QString::SkipEmptyParts);
    
    if (versions.size() >= 1) {
        return versions[0].trimmed();  // First version name (original)
    }
    
    DEBUG_LOG("XmlDataModel") << "getOrigFreeDViewName - Could not parse renderVersions:" << renderVersions;
    return QString();
}

QString XmlDataModel::getTestFreeDViewName(int rowIndex) const
{
    // Validate rowIndex bounds
    if (rowIndex < 0 || rowIndex >= rowCount()) {
        DEBUG_LOG("XmlDataModel") << "getTestFreeDViewName - Invalid rowIndex:" << rowIndex << "rowCount:" << rowCount();
        return QString();
    }
    
    // Read renderVersions from column 11 (uiData.xml)
    QString renderVersions = data(index(rowIndex, 11), Qt::DisplayRole).toString();
    
    if (renderVersions.isEmpty()) {
        DEBUG_LOG("XmlDataModel") << "getTestFreeDViewName - renderVersions is empty for row:" << rowIndex;
        return QString();
    }
    
    // Split by "_VS_" to get the two version names
    // Format: "freedview_1.3.2.0_1.0.0.3_VS_freedview_1.3.5.0_1.0.0.0"
    QStringList versions = renderVersions.split("_VS_", QString::SkipEmptyParts);
    
    if (versions.size() >= 2) {
        return versions[1].trimmed();  // Second version name (test)
    }
    
    DEBUG_LOG("XmlDataModel") << "getTestFreeDViewName - Could not parse renderVersions:" << renderVersions;
    return QString();
}
