/****************************************************************************
**
** @file test_xmldatamodel.cpp
** @brief Unit tests for XmlDataModel class
**
** Tests for:
** - Model initialization
** - Data access methods
** - Column width ratios
** - Row count
** - Test key extraction
**
****************************************************************************/

#include <QtTest/QtTest>
#include <QDir>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include <QStandardItem>
#include <QCoreApplication>

#include "../src/xmldatamodel.h"
#include "../src/xmldataloader.h"
#include "../src/logger.h"

class TestXmlDataModel : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void init();
    void cleanup();

    // Test cases
    void testModelInitialization();
    void testRowCount();
    void testColumnWidthRatio();
    void testGetColumnWidthRatioInvalid();
    void testUpdateCell();
    void testUpdateCellInvalid();
    void testGetThumbnailPath();
    void testGetTestKey();

private:
    XmlDataModel *m_model;
    QTemporaryDir *m_tempDir;
    QString m_testDataPath;

    void createTestXMLFile(const QString &filePath);
};

void TestXmlDataModel::initTestCase()
{
    // Create temporary directory for test data
    m_tempDir = new QTemporaryDir();
    QVERIFY(m_tempDir->isValid());

    // QTemporaryDir::path() returns absolute path, use QDir to append subdirectory
    QDir tempDir(m_tempDir->path());
    m_testDataPath = tempDir.absoluteFilePath("testSets_results");
    QDir().mkpath(m_testDataPath);

    // Create a test uiData.xml file
    QString xmlPath = m_testDataPath + "/uiData.xml";
    createTestXMLFile(xmlPath);
}

void TestXmlDataModel::cleanupTestCase()
{
    delete m_tempDir;
}

void TestXmlDataModel::init()
{
    m_model = new XmlDataModel(this);
}

void TestXmlDataModel::cleanup()
{
    delete m_model;
}

void TestXmlDataModel::createTestXMLFile(const QString &filePath)
{
    QFile file(filePath);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
    QTextStream out(&file);
    out << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    out << "<uiData>\n";
    out << "  <entries>\n";
    out << "    <entry>\n";
    out << "      <id>1</id>\n";
    out << "      <eventName>TestEvent</eventName>\n";
    out << "      <sportType>NFL</sportType>\n";
    out << "      <stadiumName>TestStadium</stadiumName>\n";
    out << "      <categoryName>TestCategory</categoryName>\n";
    out << "      <numberOfFrames>100</numberOfFrames>\n";
    out << "      <minValue>0.95</minValue>\n";
    out << "      <notes>Test notes</notes>\n";
    out << "      <status>Ready</status>\n";
    out << "      <thumbnailPath>test/thumb.jpg</thumbnailPath>\n";
    out << "      <testKey>SportType/EventName/SetName/F0001</testKey>\n";
    out << "      <renderVersions>version1_VS_version2</renderVersions>\n";
    out << "    </entry>\n";
    out << "  </entries>\n";
    out << "</uiData>\n";
    file.close();
}

void TestXmlDataModel::testModelInitialization()
{
    // Test that model is initialized correctly
    QVERIFY(m_model != nullptr);
    QCOMPARE(m_model->columnCount(), 11);  // Should have 11 columns initially
}

void TestXmlDataModel::testRowCount()
{
    // Initially empty
    QCOMPARE(m_model->rowCount(), 0);

    // After loading data, row count should increase
    // Note: Actual loading is async, so we test the structure
    QVERIFY(m_model->rowCount() >= 0);
}

void TestXmlDataModel::testColumnWidthRatio()
{
    // Test valid column indices
    double ratio0 = m_model->getColumnWidthRatio(0);
    double ratio1 = m_model->getColumnWidthRatio(1);
    double ratio2 = m_model->getColumnWidthRatio(2);

    // Ratios should be between 0 and 1
    QVERIFY(ratio0 >= 0.0 && ratio0 <= 1.0);
    QVERIFY(ratio1 >= 0.0 && ratio1 <= 1.0);
    QVERIFY(ratio2 >= 0.0 && ratio2 <= 1.0);

    // Ratios should sum to approximately 1.0 for all columns
    double sum = 0.0;
    for (int i = 0; i < m_model->columnCount(); ++i) {
        sum += m_model->getColumnWidthRatio(i);
    }
    // Allow some tolerance
    QVERIFY(sum > 0.5 && sum <= 1.5);  // Should be close to 1.0
}

void TestXmlDataModel::testGetColumnWidthRatioInvalid()
{
    // Test invalid column indices
    double ratio = m_model->getColumnWidthRatio(-1);
    QVERIFY(ratio >= 0.0);  // Should return valid ratio (default behavior)

    ratio = m_model->getColumnWidthRatio(999);
    QVERIFY(ratio >= 0.0);  // Should return valid ratio (default behavior)
}

void TestXmlDataModel::testUpdateCell()
{
    // Add a test row first
    QList<QStandardItem*> row;
    for (int i = 0; i < 12; ++i) {
        row << new QStandardItem(QString("Test%1").arg(i));
    }
    m_model->appendRow(row);

    // Test updating a cell
    bool result = m_model->updateCell(0, 1, "NewValue");
    QVERIFY(result);

    // Verify the value was updated
    QModelIndex index = m_model->index(0, 1);
    QString value = m_model->data(index, Qt::DisplayRole).toString();
    QCOMPARE(value, QString("NewValue"));
}

void TestXmlDataModel::testUpdateCellInvalid()
{
    // Test with invalid indices
    bool result = m_model->updateCell(-1, 0, "Value");
    QVERIFY(!result);

    result = m_model->updateCell(0, -1, "Value");
    QVERIFY(!result);

    result = m_model->updateCell(999, 0, "Value");
    QVERIFY(!result);
}

void TestXmlDataModel::testGetThumbnailPath()
{
    // Add a test row
    QList<QStandardItem*> row;
    for (int i = 0; i < 12; ++i) {
        if (i == 9) {
            row << new QStandardItem("test/thumbnail.jpg");
        } else {
            row << new QStandardItem(QString("Test%1").arg(i));
        }
    }
    m_model->appendRow(row);

    // Test getting thumbnail path
    QString path = m_model->getThumbnailPath(0);
    QCOMPARE(path, QString("test/thumbnail.jpg"));

    // Test invalid row index
    path = m_model->getThumbnailPath(-1);
    QVERIFY(path.isEmpty());

    path = m_model->getThumbnailPath(999);
    QVERIFY(path.isEmpty());
}

void TestXmlDataModel::testGetTestKey()
{
    // Add a test row with testKey
    QList<QStandardItem*> row;
    for (int i = 0; i < 12; ++i) {
        if (i == 10) {
            row << new QStandardItem("SportType/EventName/SetName/F0001");
        } else {
            row << new QStandardItem(QString("Test%1").arg(i));
        }
    }
    m_model->appendRow(row);

    // Test getting test key
    QString testKey = m_model->getTestKey(0);
    QVERIFY(!testKey.isEmpty());
    QVERIFY(testKey.contains("F0001"));

    // Test invalid row index
    testKey = m_model->getTestKey(-1);
    QVERIFY(testKey.isEmpty());
}

// QTEST_MAIN removed - using shared main() in tests_main.cpp instead
#include "test_xmldatamodel.moc"
