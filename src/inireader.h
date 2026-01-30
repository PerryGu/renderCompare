#ifndef INIREADER_H
#define INIREADER_H

#include <QObject>
#include <QString>
#include <QStringList>

/**
 * @brief IniReader - A simple class to read renderCompare.ini file
 * 
 * This class reads the INI file and extracts the main paths and configuration.
 */
class IniReader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString setTestPath READ setTestPath NOTIFY pathsChanged)
    Q_PROPERTY(QString setTestResultsPath READ setTestResultsPath NOTIFY pathsChanged)
    Q_PROPERTY(QString freedviewVer READ freedviewVer NOTIFY pathsChanged)
    Q_PROPERTY(QString freeDViewTesterPath READ freeDViewTesterPath NOTIFY pathsChanged)
    Q_PROPERTY(QString iniFilePath READ iniFilePath NOTIFY pathsChanged)
    Q_PROPERTY(bool isValid READ isValid NOTIFY pathsChanged)

public:
    explicit IniReader(QObject *parent = nullptr);

    /**
     * @brief Read the INI file from various possible locations
     * @return true if INI file was found and parsed successfully
     */
    Q_INVOKABLE bool readINIFile();

    /**
     * @brief Get the setTestPath (derived from testSets_results)
     * @return Path to testSets directory (derived from testSets_results)
     */
    QString setTestPath() const { return m_setTestPath; }

    /**
     * @brief Get the setTestResultsPath (from INI file - setTestPath now points to testSets_results)
     * @return Path to testSets_results directory (where uiData.xml and all test data is)
     */
    QString setTestResultsPath() const { return m_setTestResultsPath; }

    /**
     * @brief Get the freedviewVer from INI file
     */
    QString freedviewVer() const { return m_freedviewVer; }

    /**
     * @brief Path to the freeDView_tester project (root directory)
     */
    QString freeDViewTesterPath() const { return m_freeDViewTesterPath; }

    /**
     * @brief Absolute path to the INI file used
     */
    QString iniFilePath() const { return m_iniFilePath; }

    /**
     * @brief Check if INI file was successfully read
     */
    bool isValid() const { return m_isValid; }

    /**
     * @brief Find all compareResult.xml files in the results path
     * @return List of XML file paths
     */
    Q_INVOKABLE QStringList findAllXMLFiles() const;
    
    /**
     * @brief Update run_on_test_list in the INI file
     * @param testKey The testKey to set (empty string to clear)
     * @return true if successful, false otherwise
     */
    Q_INVOKABLE bool updateRunOnTestList(const QString &testKey);
    
    /**
     * @brief Update run_on_test_list in a specific INI file
     * @param iniFilePath Path to the INI file to update
     * @param testKey The testKey to set (empty string to clear)
     * @return true if successful, false otherwise
     */
    Q_INVOKABLE bool updateRunOnTestListInFile(const QString &iniFilePath, const QString &testKey);

    /**
     * @brief Find thumbnail image path for a given XML file path
     * @param xmlPath Path to the compareResult.xml file
     * @return Full path to thumbnail image, or empty string if not found
     * 
     * Searches for thumbnail images in the directory structure:
     * eventSet/FRAME/freedviewVersion/origFreeDView
     */
    Q_INVOKABLE QString findThumbnailForPath(const QString &xmlPath) const;

signals:
    void pathsChanged();
    void errorOccurred(const QString &errorMessage);

private:
    QString findINIFile() const;
    bool parseINIFile(const QString &filePath);

    QString m_setTestPath;
    QString m_setTestResultsPath;
    QString m_freedviewVer;
    QString m_freeDViewTesterPath;
    QString m_iniFilePath;
    bool m_isValid;
};

#endif // INIREADER_H
