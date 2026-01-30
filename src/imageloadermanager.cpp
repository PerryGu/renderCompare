#include "imageloadermanager.h"
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QImage>

ImageLoaderManager::ImageLoaderManager(QObject *parent)
    : QObject(parent)
    , m_maxCacheSize(6)  // Small cache: 6 images (~36MB for 1920x1080) for adjacent frames
    , m_threadPool(new QThreadPool(this))
{
    // Set thread pool to use 2 threads - prevents too many simultaneous loads that cause memory issues
    m_threadPool->setMaxThreadCount(2);
}

ImageLoaderManager::~ImageLoaderManager()
{
    clearCache();
}

void ImageLoaderManager::setImagePaths(const QString &pathA, const QString &pathB, const QString &pathC, const QString &pathD)
{
    // Remove file:/// prefix if present and convert to native path
    auto cleanPath = [](const QString &path) -> QString {
        QString cleaned = path;
        if (cleaned.startsWith("file:///")) {
            cleaned = cleaned.mid(8);  // Remove "file:///"
        } else if (cleaned.startsWith("file://")) {
            cleaned = cleaned.mid(7);   // Remove "file://"
        }
        // Convert forward slashes to native separators
        return QDir::toNativeSeparators(cleaned);
    };

    m_pathA = cleanPath(pathA);
    m_pathB = cleanPath(pathB);
    m_pathC = cleanPath(pathC);
    m_pathD = cleanPath(pathD);

    // Clear cache when paths change
    clearCache();
}

QPixmap ImageLoaderManager::getImageIfCached(const QString &imageType, int frameNumber) const
{
    if (m_maxCacheSize == 0) {
        return QPixmap();  // Cache disabled
    }
    
    QMutexLocker locker(&m_cacheMutex);
    QString key = getCacheKey(imageType, frameNumber);
    
    if (m_cache.contains(key)) {
        // Update access order (move to end = most recently used)
        m_cacheAccessOrder.removeAll(key);
        m_cacheAccessOrder.append(key);
        return m_cache.value(key);
    }
    
    return QPixmap();  // Not in cache
}

QPixmap ImageLoaderManager::getImage(const QString &imageType, int frameNumber)
{
    if (frameNumber < 1) {
        emit errorOccurred(QString("Invalid frame number: %1").arg(frameNumber));
        return QPixmap();
    }

    // Check cache first (if enabled)
    if (m_maxCacheSize > 0) {
        QPixmap cached = getImageIfCached(imageType, frameNumber);
        if (!cached.isNull()) {
            return cached;  // Cache hit
        }
    }

    // Cache miss or cache disabled: Load from disk
    QPixmap pixmap = loadImageFromDisk(imageType, frameNumber);

    if (!pixmap.isNull()) {
        // Add to cache if enabled
        if (m_maxCacheSize > 0) {
            QMutexLocker locker(&m_cacheMutex);
            QString key = getCacheKey(imageType, frameNumber);
            m_cache[key] = pixmap;
            
            // Update access order (move to end = most recently used)
            m_cacheAccessOrder.removeAll(key);
            m_cacheAccessOrder.append(key);
            
            // Evict oldest if cache is full
            evictOldestIfNeeded();
        }
        
        emit imageLoaded(imageType, frameNumber);
    } else {
        emit imageLoadFailed(imageType, frameNumber, "Failed to load image from disk");
    }

    return pixmap;
}

void ImageLoaderManager::preloadImage(const QString &imageType, int frameNumber)
{
    if (m_maxCacheSize == 0) {
        return;  // Cache disabled: Preloading disabled
    }
    
    // Check if already cached
    if (!getImageIfCached(imageType, frameNumber).isNull()) {
        return;  // Already in cache
    }
    
    // Preload in background thread
    ImageLoadTask *task = new ImageLoadTask(this, imageType, frameNumber);
    task->setAutoDelete(true);  // Ensure task is auto-deleted after completion to prevent memory leaks
    m_threadPool->start(task);
}

void ImageLoaderManager::preloadFrameRange(const QString &imageType, int currentFrame, int framesBefore, int framesAfter, int maxFrame)
{
    // Validate imageType
    if (imageType != "A" && imageType != "B" && imageType != "C" && imageType != "D") {
        DEBUG_LOG("ImageLoaderManager") << "preloadFrameRange - Invalid imageType:" << imageType;
        return;
    }
    
    // Validate frame parameters
    if (currentFrame < 1 || maxFrame < 1 || framesBefore < 0 || framesAfter < 0) {
        DEBUG_LOG("ImageLoaderManager") << "preloadFrameRange - Invalid frame parameters. currentFrame:" << currentFrame << "maxFrame:" << maxFrame << "framesBefore:" << framesBefore << "framesAfter:" << framesAfter;
        return;
    }
    
    // Preload frames before current
    for (int i = 1; i <= framesBefore; i++) {
        int frameNum = currentFrame - i;
        if (frameNum >= 1 && frameNum <= maxFrame) {
            preloadImage(imageType, frameNum);
        }
    }

    // Preload frames after current
    for (int i = 1; i <= framesAfter; i++) {
        int frameNum = currentFrame + i;
        if (frameNum >= 1 && frameNum <= maxFrame) {
            preloadImage(imageType, frameNum);
        }
    }
}

void ImageLoaderManager::preloadAllTypesForRange(int currentFrame, int framesBefore, int framesAfter, int maxFrame)
{
    // Validate frame parameters
    if (currentFrame < 1 || maxFrame < 1 || framesBefore < 0 || framesAfter < 0) {
        DEBUG_LOG("ImageLoaderManager") << "preloadAllTypesForRange - Invalid frame parameters. currentFrame:" << currentFrame << "maxFrame:" << maxFrame << "framesBefore:" << framesBefore << "framesAfter:" << framesAfter;
        return;
    }
    
    // Preload all image types (A, B, C, D) for the frame range
    // This ensures all three windows have images ready
    preloadFrameRange("A", currentFrame, framesBefore, framesAfter, maxFrame);
    preloadFrameRange("B", currentFrame, framesBefore, framesAfter, maxFrame);
    preloadFrameRange("C", currentFrame, framesBefore, framesAfter, maxFrame);
    preloadFrameRange("D", currentFrame, framesBefore, framesAfter, maxFrame);
}

void ImageLoaderManager::clearCache()
{
    QMutexLocker locker(&m_cacheMutex);
    m_cache.clear();
    m_cacheAccessOrder.clear();
}

void ImageLoaderManager::preloadAdjacentFrames(int currentFrame, int maxFrame, const QStringList &imageTypes)
{
    if (m_maxCacheSize == 0) {
        return;  // Cache disabled
    }
    
    // Validate frame parameters
    if (currentFrame < 1 || maxFrame < 1) {
        DEBUG_LOG("ImageLoaderManager") << "preloadAdjacentFrames - Invalid frame parameters. currentFrame:" << currentFrame << "maxFrame:" << maxFrame;
        return;
    }
    
    // Default to all image types if none specified
    QStringList types = imageTypes.isEmpty() ? QStringList() << "A" << "B" << "C" << "D" : imageTypes;
    
    // Only preload ±2 frames to keep cache small
    int framesBefore = 2;
    int framesAfter = 2;
    
    for (const QString &imageType : types) {
        // Validate each imageType in the list
        if (imageType != "A" && imageType != "B" && imageType != "C" && imageType != "D") {
            DEBUG_LOG("ImageLoaderManager") << "preloadAdjacentFrames - Invalid imageType in list:" << imageType;
            continue;  // Skip invalid type, continue with others
        }
        // Preload frames before current
        for (int i = 1; i <= framesBefore; i++) {
            int frameNum = currentFrame - i;
            if (frameNum >= 1 && frameNum <= maxFrame) {
                preloadImage(imageType, frameNum);
            }
        }
        
        // Preload frames after current
        for (int i = 1; i <= framesAfter; i++) {
            int frameNum = currentFrame + i;
            if (frameNum >= 1 && frameNum <= maxFrame) {
                preloadImage(imageType, frameNum);
            }
        }
    }
}

void ImageLoaderManager::evictOldestIfNeeded()
{
    if (m_maxCacheSize == 0) {
        return;  // Cache disabled
    }
    
    QMutexLocker locker(&m_cacheMutex);
    
    // Remove oldest entries until cache is within limit
    while (m_cache.size() >= m_maxCacheSize && !m_cacheAccessOrder.isEmpty()) {
        QString oldestKey = m_cacheAccessOrder.takeFirst();
        m_cache.remove(oldestKey);
    }
}

/**
 * @brief Load an image from disk into a QPixmap
 * 
 * This function performs the actual disk I/O to load image files. It uses
 * a two-step process (QImage → QPixmap) to optimize memory usage and avoid
 * fragmentation. The QImage is explicitly cleared after conversion to free
 * memory immediately.
 * 
 * PERFORMANCE NOTE: This function is called from background threads during
 * preloading, but can also be called synchronously. The QPixmap result is
 * GPU-optimized for efficient rendering.
 * 
 * @param imageType - Image type: "A" (orig), "B" (test), "C" (diff), or "D" (alpha)
 * @param frameNumber - Frame number (1-indexed, e.g., 1, 2, 3...)
 * @return QPixmap of the loaded image, or null QPixmap if loading failed
 */
QPixmap ImageLoaderManager::loadImageFromDisk(const QString &imageType, const int frameNumber)
{
    // Validate imageType parameter
    if (imageType != "A" && imageType != "B" && imageType != "C" && imageType != "D") {
        QString errorMsg = QString("Invalid image type: %1 (must be A, B, C, or D)").arg(imageType);
        emit errorOccurred(errorMsg);
        return QPixmap();
    }
    
    // Format frame number as 4-digit zero-padded string (e.g., "0001", "0002")
    QString frameStr = QString("%1").arg(frameNumber, 4, 10, QChar('0'));
    QString basePath;
    QString extension;

    // Get base path and extension for image type
    if (!getImageTypePathAndExtension(imageType, basePath, extension)) {
        QString errorMsg = QString("Failed to get path for image type: %1").arg(imageType);
        emit errorOccurred(errorMsg);
        return QPixmap();
    }

    if (basePath.isEmpty()) {
        return QPixmap();
    }

    // Construct full file path: basePath + frameNumber + extension
    QString filePath = basePath + frameStr + extension;

    // Validate file exists before attempting to load
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        QString errorMsg = QString("Frame %1 (image type %2) not found: %3").arg(frameNumber).arg(imageType).arg(filePath);
        emit errorOccurred(errorMsg);
        return QPixmap();
    }

    // Load as QImage first (more memory efficient), then convert to QPixmap
    // This two-step process helps avoid memory fragmentation
    QImage image;
    if (!image.load(filePath)) {
        // Distinguish between memory issues and file corruption issues
        QString errorMsg;
        if (image.isNull() && QFileInfo(filePath).exists()) {
            errorMsg = QString("QImage load failed (possibly out of memory): %1").arg(filePath);
        } else {
            errorMsg = QString("Failed to load image from: %1").arg(filePath);
        }
        emit errorOccurred(errorMsg);
        return QPixmap();
    }

    // Validate image loaded successfully before converting
    if (image.isNull()) {
        QString errorMsg = QString("Image is null after load: %1").arg(filePath);
        emit errorOccurred(errorMsg);
        return QPixmap();
    }

    // Convert to QPixmap (this will be GPU-optimized for efficient rendering)
    QPixmap pixmap = QPixmap::fromImage(image);
    
    // Explicitly clear the QImage to free memory immediately
    // This prevents holding both QImage and QPixmap in memory simultaneously
    image = QImage();
    
    if (pixmap.isNull()) {
        QString errorMsg = QString("Failed to convert image to pixmap: %1").arg(filePath);
        emit errorOccurred(errorMsg);
        return QPixmap();
    }

    return pixmap;
}

QString ImageLoaderManager::getImageFilePath(const QString &imageType, int frameNumber) const
{
    // Validate image type
    if (imageType != "A" && imageType != "B" && imageType != "C" && imageType != "D") {
        DEBUG_LOG("ImageLoaderManager") << "getImageFilePath - Invalid imageType:" << imageType;
        return QString();  // Invalid image type - QML handles empty string gracefully
    }
    
    // Validate frame number
    if (frameNumber < 1) {
        DEBUG_LOG("ImageLoaderManager") << "getImageFilePath - Invalid frameNumber:" << frameNumber << "(must be >= 1)";
        return QString();  // Invalid frame number - QML handles empty string gracefully
    }

    // Format frame number as 4-digit zero-padded string (e.g., 0001, 0002)
    QString frameStr = QString("%1").arg(frameNumber, 4, 10, QChar('0'));

    QString basePath;
    QString extension;

    // Get base path and extension for image type
    if (!getImageTypePathAndExtension(imageType, basePath, extension)) {
        DEBUG_LOG("ImageLoaderManager") << "getImageFilePath - Failed to get path/extension for imageType:" << imageType;
        return QString();
    }

    if (basePath.isEmpty()) {
        // Base path is empty - this is a configuration issue, not a runtime error
        // QML handles empty string gracefully
        DEBUG_LOG("ImageLoaderManager") << "getImageFilePath - Base path is empty for imageType:" << imageType;
        return QString();
    }

    // Validate base path directory exists (optional check - can be disabled for performance)
    // Note: This check is lightweight (directory check, not file check)
    QDir baseDir(basePath);
    if (!baseDir.exists()) {
        DEBUG_LOG("ImageLoaderManager") << "getImageFilePath - Base directory does not exist:" << basePath;
        // Still return the path - QML will handle missing files gracefully
        // This allows the application to work even if some directories are missing
    }

    // Construct full path: basePath + frameNumber + extension
    QString filePath = basePath + frameStr + extension;

    // OPTIONAL: Validate file exists before returning path
    // This prevents QML from trying to load non-existent files
    // Commented out for performance - QML handles missing files gracefully
    // QFileInfo fileInfo(filePath);
    // if (!fileInfo.exists()) {
    //     qDebug() << "ImageLoaderManager::getImageFilePath: File does not exist:" << filePath;
    //     return QString();  // Return empty string if file doesn't exist
    // }

    // Convert to QML-compatible format: file:/// with forward slashes
    // QML Image component requires file:/// prefix and forward slashes
    QString qmlPath = "file:///" + QDir::toNativeSeparators(filePath).replace("\\", "/");
    
    return qmlPath;
}

bool ImageLoaderManager::getImageTypePathAndExtension(const QString &imageType, QString &basePath, QString &extension) const
{
    if (imageType == "A") {
        basePath = m_pathA;
        extension = ".jpg";
        return true;
    } else if (imageType == "B") {
        basePath = m_pathB;
        extension = ".jpg";
        return true;
    } else if (imageType == "C") {
        basePath = m_pathC;
        extension = ".jpg";
        return true;
    } else if (imageType == "D") {
        basePath = m_pathD;
        extension = ".png";  // Alpha images are PNG
        return true;
    }
    return false;
}

QString ImageLoaderManager::getCacheKey(const QString &imageType, int frameNumber) const
{
    // Format: "A_0001", "B_0002", etc.
    QString frameStr = QString("%1").arg(frameNumber, 4, 10, QChar('0'));
    return imageType + "_" + frameStr;
}

