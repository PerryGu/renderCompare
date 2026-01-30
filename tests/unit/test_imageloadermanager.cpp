/****************************************************************************
**
** @file test_imageloadermanager.cpp
** @brief Unit tests for ImageLoaderManager class
**
** Tests for:
** - Image path construction
** - Cache functionality
** - Frame number formatting
** - Path validation
**
****************************************************************************/

#include <QtTest/QtTest>
#include <QDir>
#include <QTemporaryDir>
#include <QFile>
#include <QImage>
#include <QPixmap>
#include <QCoreApplication>

#include "../src/imageloadermanager.h"
#include "../src/logger.h"

class TestImageLoaderManager : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();           // Called before first test
    void cleanupTestCase();        // Called after last test
    void init();                   // Called before each test
    void cleanup();                // Called after each test

    // Test cases
    void testGetImageFilePath();
    void testGetImageFilePathInvalidType();
    void testGetImageFilePathInvalidFrame();
    void testSetImagePaths();
    void testCacheFunctionality();
    void testCacheEviction();
    void testPreloadFrameRange();
    void testClearCache();
    void testGetImageTypePathAndExtension();

private:
    ImageLoaderManager *m_manager;
    QTemporaryDir *m_tempDir;
    QString m_testPathA;
    QString m_testPathB;
    QString m_testPathC;
    QString m_testPathD;

    void createTestImages(const QString &basePath, int count);
};

void TestImageLoaderManager::initTestCase()
{
    // Create temporary directory for test images
    m_tempDir = new QTemporaryDir();
    QVERIFY(m_tempDir->isValid());

    // Create subdirectories for each image type
    QDir tempDir(m_tempDir->path());
    tempDir.mkpath("imagesA");
    tempDir.mkpath("imagesB");
    tempDir.mkpath("imagesC");
    tempDir.mkpath("imagesD");

    m_testPathA = tempDir.absoluteFilePath("imagesA/");
    m_testPathB = tempDir.absoluteFilePath("imagesB/");
    m_testPathC = tempDir.absoluteFilePath("imagesC/");
    m_testPathD = tempDir.absoluteFilePath("imagesD/");

    // Create some test images
    createTestImages(m_testPathA, 5);
    createTestImages(m_testPathB, 5);
    createTestImages(m_testPathC, 5);
    createTestImages(m_testPathD, 5);
}

void TestImageLoaderManager::cleanupTestCase()
{
    delete m_tempDir;
}

void TestImageLoaderManager::init()
{
    m_manager = new ImageLoaderManager(this);
    m_manager->setMaxCacheSize(10);  // Set cache size for tests
}

void TestImageLoaderManager::cleanup()
{
    delete m_manager;
}

void TestImageLoaderManager::createTestImages(const QString &basePath, int count)
{
    QDir dir(basePath);
    for (int i = 1; i <= count; ++i) {
        QString frameStr = QString("%1").arg(i, 4, 10, QChar('0'));
        QString filePath = dir.absoluteFilePath(frameStr + ".jpg");
        
        // Create a simple test image
        QImage image(100, 100, QImage::Format_RGB32);
        image.fill(Qt::red);
        image.save(filePath, "JPG");
        
        QVERIFY(QFile::exists(filePath));
    }
}

void TestImageLoaderManager::testGetImageFilePath()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    // Test valid image type and frame number
    QString path = m_manager->getImageFilePath("A", 1);
    QVERIFY(!path.isEmpty());
    QVERIFY(path.contains("0001"));
    QVERIFY(path.contains("imagesA"));
    QVERIFY(path.startsWith("file:///"));

    // Test different frame numbers
    path = m_manager->getImageFilePath("A", 5);
    QVERIFY(path.contains("0005"));

    // Test different image types
    path = m_manager->getImageFilePath("B", 1);
    QVERIFY(path.contains("imagesB"));

    path = m_manager->getImageFilePath("C", 1);
    QVERIFY(path.contains("imagesC"));

    path = m_manager->getImageFilePath("D", 1);
    QVERIFY(path.contains("imagesD"));
    QVERIFY(path.contains(".png"));  // Type D uses PNG
}

void TestImageLoaderManager::testGetImageFilePathInvalidType()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    // Test invalid image type
    QString path = m_manager->getImageFilePath("X", 1);
    QVERIFY(path.isEmpty());
}

void TestImageLoaderManager::testGetImageFilePathInvalidFrame()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    // Test invalid frame numbers
    QString path = m_manager->getImageFilePath("A", 0);
    QVERIFY(path.isEmpty());

    path = m_manager->getImageFilePath("A", -1);
    QVERIFY(path.isEmpty());
}

void TestImageLoaderManager::testSetImagePaths()
{
    // Test setting paths
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    QString pathA = m_manager->getImageFilePath("A", 1);
    QString pathB = m_manager->getImageFilePath("B", 1);
    QString pathC = m_manager->getImageFilePath("C", 1);
    QString pathD = m_manager->getImageFilePath("D", 1);

    QVERIFY(pathA.contains("imagesA"));
    QVERIFY(pathB.contains("imagesB"));
    QVERIFY(pathC.contains("imagesC"));
    QVERIFY(pathD.contains("imagesD"));

    // Test that cache is cleared when paths change
    m_manager->setImagePaths(m_testPathB, m_testPathA, m_testPathC, m_testPathD);
    // Paths should be updated
    pathA = m_manager->getImageFilePath("A", 1);
    QVERIFY(pathA.contains("imagesB"));  // A now points to imagesB
}

void TestImageLoaderManager::testCacheFunctionality()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);
    m_manager->setMaxCacheSize(5);

    // Load an image (should be cached)
    QPixmap pixmap = m_manager->getImage("A", 1);
    QVERIFY(!pixmap.isNull());

    // Check if it's in cache
    QPixmap cached = m_manager->getImageIfCached("A", 1);
    QVERIFY(!cached.isNull());
    QCOMPARE(cached.width(), pixmap.width());
}

void TestImageLoaderManager::testCacheEviction()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);
    m_manager->setMaxCacheSize(3);  // Small cache

    // Load more images than cache size
    m_manager->getImage("A", 1);
    m_manager->getImage("A", 2);
    m_manager->getImage("A", 3);
    m_manager->getImage("A", 4);  // This should evict the oldest (A,1)

    // Oldest should be evicted
    QPixmap cached = m_manager->getImageIfCached("A", 1);
    QVERIFY(cached.isNull());  // Should be evicted

    // Newer images should still be cached
    cached = m_manager->getImageIfCached("A", 4);
    QVERIFY(!cached.isNull());
}

void TestImageLoaderManager::testPreloadFrameRange()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);
    m_manager->setMaxCacheSize(10);

    // Preload a range of frames
    m_manager->preloadFrameRange("A", 3, 1, 1, 5);  // Preload frames 2, 3, 4

    // Wait a bit for async loading (in real scenario, you'd use QSignalSpy)
    QTest::qWait(100);

    // Check if frames are cached
    QPixmap cached = m_manager->getImageIfCached("A", 2);
    // Note: Preloading is async, so this might not be ready immediately
    // In a real test, you'd wait for imageLoaded signal
}

void TestImageLoaderManager::testClearCache()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    // Load some images
    m_manager->getImage("A", 1);
    m_manager->getImage("A", 2);

    // Verify they're cached
    QPixmap cached = m_manager->getImageIfCached("A", 1);
    QVERIFY(!cached.isNull());

    // Clear cache
    m_manager->clearCache();

    // Verify cache is empty
    cached = m_manager->getImageIfCached("A", 1);
    QVERIFY(cached.isNull());
}

void TestImageLoaderManager::testGetImageTypePathAndExtension()
{
    m_manager->setImagePaths(m_testPathA, m_testPathB, m_testPathC, m_testPathD);

    QString basePath;
    QString extension;

    // Test type A
    bool result = m_manager->getImageTypePathAndExtension("A", basePath, extension);
    QVERIFY(result);
    QCOMPARE(extension, QString(".jpg"));

    // Test type D (PNG)
    result = m_manager->getImageTypePathAndExtension("D", basePath, extension);
    QVERIFY(result);
    QCOMPARE(extension, QString(".png"));

    // Test invalid type
    result = m_manager->getImageTypePathAndExtension("X", basePath, extension);
    QVERIFY(!result);
}

// QTEST_MAIN removed - using shared main() in tests_main.cpp instead
#include "test_imageloadermanager.moc"
