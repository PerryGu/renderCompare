#ifndef XMLDATAMODEL_H
#define XMLDATAMODEL_H

#include <QStandardItemModel>
#include <QObject>
#include <QStringList>
#include <QVariant>
#include <QThread>
#include <QMutex>

// Forward declaration
class XmlDataLoader;

/**
 * @brief XmlDataModel - A QStandardItemModel that loads data from compareResult.xml files
 * 
 * This model reads XML files from the path specified in the INI file and populates
 * a table with the data. Loading is performed in a background thread to prevent UI freezing.
 */
class XmlDataModel : public QStandardItemModel
{
    Q_OBJECT
    Q_PROPERTY(int rowCount READ rowCount NOTIFY dataChanged)

public:
    explicit XmlDataModel(QObject *parent = nullptr);
    ~XmlDataModel();
    
    /**
     * @brief Load data from uiData.xml file
     * @param resultsPath - Path to the testSets_results directory (uiData.xml is in the root)
     * @param selectedVersion - Optional version filter (currently unused, for future use)
     * @param testSetsPath - Optional path to testSets directory (for fallback thumbnail lookup)
     * @return true if loading was started successfully (actual loading happens in background)
     */
    Q_INVOKABLE bool loadData(const QString &resultsPath, const QString &selectedVersion = QString(), const QString &testSetsPath = QString());
    
    /**
     * @brief Get row count (for QML property)
     */
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    
    /**
     * @brief Override roleNames to provide role names for QML
     */
    QHash<int, QByteArray> roleNames() const override;
    
    /**
     * @brief Override data to support role-based access
     */
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    
    /**
     * @brief Get thumbnail path for a specific row
     * @param rowIndex - The row index in the model
     * @return Thumbnail file path, or empty string if not found
     */
    Q_INVOKABLE QString getThumbnailPath(int rowIndex) const;
    
    /**
     * @brief Get testKey for a specific row
     * @param rowIndex - The row index in the model
     * @return Test key string, or empty string if not found
     */
    Q_INVOKABLE QString getTestKey(int rowIndex) const;
    
    /**
     * @brief Get column width ratio (0.0 to 1.0) for a given column index
     * @param columnIndex - The column index (0-based)
     * @return Width ratio as a double (e.g., 0.175 = 17.5% of viewport width)
     * 
     * This allows centralized control of column widths in C++ while QML handles
     * the actual width calculation based on viewport size.
     */
    Q_INVOKABLE double getColumnWidthRatio(int columnIndex) const;
    
    /**
     * @brief Update a cell value in the model
     * @param rowIndex - The row index (0-based)
     * @param columnIndex - The column index (0-based)
     * @param newValue - The new value to set
     * @return true if update was successful, false otherwise
     * 
     * This method updates the model data and emits dataChanged signal.
     * Note: This updates the in-memory model only. To persist changes,
     * call saveToXml() after making updates.
     */
    Q_INVOKABLE bool updateCell(int rowIndex, int columnIndex, const QString &newValue);
    
    /**
     * @brief Save the current model data back to uiData.xml
     * @param resultsPath - Path to the testSets_results directory (uiData.xml is in the root)
     * @return true if save was successful, false otherwise
     */
    Q_INVOKABLE bool saveToXml(const QString &resultsPath);
    
    /**
     * @brief Get list of all unique FreeDView versions from loaded data
     * @return QStringList of version strings (format: "origFreeDView_VS_testFreeDView")
     * 
     * This function scans the loaded XML data and extracts unique version combinations.
     * Used by TopLayout_zero to populate the version selection combo box.
     */
    Q_INVOKABLE QStringList getFreeDViewVerList() const;
    
    // Functions for accessing compareResult.xml data (required by TopLayout_zero.qml)
    /**
     * @brief Get start frame number for a specific row
     * @param rowIndex - The row index in the model
     * @return Start frame number, or -1 if not found
     */
    Q_INVOKABLE int getStartFrame(int rowIndex) const;
    
    /**
     * @brief Get end frame number for a specific row
     * @param rowIndex - The row index in the model
     * @return End frame number, or -1 if not found
     */
    Q_INVOKABLE int getEndFrame(int rowIndex) const;
    
    /**
     * @brief Get minimum value for a specific row
     * @param rowIndex - The row index in the model
     * @return Minimum value, or -1 if not found
     */
    Q_INVOKABLE double getMinVal(int rowIndex) const;
    
    /**
     * @brief Get maximum value for a specific row
     * @param rowIndex - The row index in the model
     * @return Maximum value, or -1 if not found
     */
    Q_INVOKABLE double getMaxVal(int rowIndex) const;
    
    /**
     * @brief Get frame list (frame numbers) for a specific row
     * @param rowIndex - The row index in the model
     * @return QVariantList of frame numbers, or empty list if not found
     */
    Q_INVOKABLE QVariantList getFrameList_frame(int rowIndex) const;
    
    /**
     * @brief Get frame list (values) for a specific row
     * @param rowIndex - The row index in the model
     * @return QVariantList of frame values, or empty list if not found
     */
    Q_INVOKABLE QVariantList getFrameList_val(int rowIndex) const;
    
    /**
     * @brief Get output path list for a specific row
     * @param rowIndex - The row index in the model
     * @return QStringList of output paths [orig, test, diff, alpha], or empty list if not found
     */
    Q_INVOKABLE QStringList getOutputPathList(int rowIndex) const;
    
    /**
     * @brief Get original FreeDView name for a specific row
     * @param rowIndex - The row index in the model
     * @return Original FreeDView name, or empty string if not found
     */
    Q_INVOKABLE QString getOrigFreeDViewName(int rowIndex) const;
    
    /**
     * @brief Get test FreeDView name for a specific row
     * @param rowIndex - The row index in the model
     * @return Test FreeDView name, or empty string if not found
     */
    Q_INVOKABLE QString getTestFreeDViewName(int rowIndex) const;

signals:
    void dataChanged();
    void loadingStarted();
    void loadingFinished(bool success, int count);
    void errorOccurred(const QString &message);

private:
    
    // Background loading thread and worker
    QThread *m_loaderThread;
    XmlDataLoader *m_loader;
    
    // Store results path for accessing compareResult.xml files
    mutable QString m_resultsPath;
    
    // Store render version names from uiData.xml
    QStringList m_renderVersions;
    
    // Cache structure for parsed compareResult.xml data per row index
    struct ParsedXmlData {
        int startFrame;
        int endFrame;
        double minVal;
        double maxVal;
        QVariantList frameList_frame;
        QVariantList frameList_val;
        QStringList outputPathList;
        QString origFreeDViewName;
        QString testFreeDViewName;
        QString xmlPath;  // Store the path to verify cache validity
        
        ParsedXmlData() : startFrame(-1), endFrame(-1), minVal(-1.0), maxVal(-1.0) {}
    };
    
    // Cache of parsed XML data, keyed by row index
    mutable QHash<int, ParsedXmlData> m_parsedXmlCache;
    
    // Mutex for thread-safe cache access
    // Cache can be accessed from main thread (QML getters) while background thread loads data
    mutable QMutex m_cacheMutex;
    
    /**
     * @brief Get parsed XML data for a row (uses cache if available)
     * @param rowIndex - The row index in the model
     * @param parsedData - Output parameter for parsed data
     * @return true if data was successfully retrieved (from cache or by parsing)
     */
    bool getParsedXmlData(int rowIndex, ParsedXmlData &parsedData) const;
    
    /**
     * @brief Clear the XML parsing cache (call when data is reloaded)
     */
    void clearXmlCache() const;
    
    /**
     * @brief Find and parse compareResult.xml for a given row
     * @param rowIndex - The row index in the model
     * @return Path to compareResult.xml, or empty string if not found
     */
    QString findCompareResultXml(int rowIndex) const;
    
    /**
     * @brief Parse compareResult.xml and extract frame data
     * @param xmlPath - Path to compareResult.xml file
     * @param startFrame - Output parameter for start frame
     * @param endFrame - Output parameter for end frame
     * @param minVal - Output parameter for minimum value
     * @param maxVal - Output parameter for maximum value
     * @param frameList_frame - Output parameter for frame numbers list
     * @param frameList_val - Output parameter for frame values list
     * @param outputPathList - Output parameter for output paths [orig, test, diff, alpha]
     * @param origFreeDViewName - Output parameter for original FreeDView name
     * @param testFreeDViewName - Output parameter for test FreeDView name
     * @return true if parsing was successful, false otherwise
     */
    bool parseCompareResultXml(const QString &xmlPath, int &startFrame, int &endFrame,
                               double &minVal, double &maxVal,
                               QVariantList &frameList_frame, QVariantList &frameList_val,
                               QStringList &outputPathList,
                               QString &origFreeDViewName, QString &testFreeDViewName) const;
    
private slots:
    /**
     * @brief Slot called when a row has been loaded in background thread
     * @param rowData - List of column values for the row
     * @param xmlPath - Path to the XML file
     */
    void onRowLoaded(const QVariantList &rowData, const QString &xmlPath);
    
    /**
     * @brief Slot called when render versions are loaded from uiData.xml
     * @param versionList - List of render version folder names
     */
    void onRenderVersionsLoaded(const QStringList &versionList);
};

#endif // XMLDATAMODEL_H
