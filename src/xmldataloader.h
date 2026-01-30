#ifndef XMLDATALOADER_H
#define XMLDATALOADER_H

#include <QObject>
#include <QThread>
#include <QString>
#include <QStringList>
#include <QVariantList>

/**
 * @brief XmlDataLoader - Worker class for loading XML files in background thread
 * 
 * This class runs in a separate thread to parse XML files without blocking the UI.
 * It emits signals with parsed data that can be safely connected to the main thread.
 */
class XmlDataLoader : public QObject
{
    Q_OBJECT

public:
    explicit XmlDataLoader(QObject *parent = nullptr);
    
    /**
     * @brief Start loading data from uiData.xml file
     * @param resultsPath - Path to the testSets_results directory (uiData.xml is in the root)
     * @param testSetsPath - Path to the testSets directory (for fallback thumbnail lookup)
     */
    Q_INVOKABLE void loadData(const QString &resultsPath, const QString &testSetsPath = QString());

signals:
    /**
     * @brief Emitted when loading starts
     */
    void loadingStarted();
    
    /**
     * @brief Emitted when a single XML file has been parsed
     * @param rowData - List of column values for one row
     * @param xmlPath - Path to the XML file that was parsed
     */
    void rowLoaded(const QVariantList &rowData, const QString &xmlPath);
    
    /**
     * @brief Emitted when loading finishes
     * @param success - Whether loading was successful
     * @param count - Number of rows loaded
     */
    void loadingFinished(bool success, int count);
    
    /**
     * @brief Emitted when an error occurs
     * @param message - Error message
     */
    void errorOccurred(const QString &message);
    
    /**
     * @brief Emitted when render versions are loaded from uiData.xml
     * @param versionList - List of render version folder names
     */
    void renderVersionsLoaded(const QStringList &versionList);

private slots:
    /**
     * @brief Internal slot to perform the actual loading work
     */
    void doLoad();

private:
    int readUIDataXML(const QString &uiDataXmlPath, const QString &resultsPathRoot);
    QString resolveThumbnailPath(const QString &relativeThumbnailPath, const QString &resultsPathRoot) const;
    QString deriveTestKeyFromThumbnailPath(const QString &thumbnailPath) const;
    
    QString m_resultsPath;
    QString m_testSetsPath;  // Path to testSets directory (for fallback lookup)
};

#endif // XMLDATALOADER_H

