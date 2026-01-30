#ifndef IMAGELOADERMANAGER_H
#define IMAGELOADERMANAGER_H

#include <QObject>
#include <QString>
#include <QPixmap>
#include <QHash>
#include <QMutex>
#include <QThreadPool>
#include <QRunnable>
#include <QDebug>
#include "logger.h"

/**
 * @brief ImageLoaderManager - Manages image paths and provides file paths to QML
 * 
 * ARCHITECTURE DECISION: This class only manages paths, not image loading.
 * QML Image components load directly from disk for optimal performance.
 * 
 * This class handles:
 * - Managing base paths for different image types (A, B, C, D)
 * - Constructing full file paths for QML consumption
 * - Path validation and formatting (QML-compatible file:/// URLs)
 * 
 * PERFORMANCE: Direct file paths are faster than C++ image providers because:
 * - Eliminates C++ → QML conversion overhead
 * - Leverages QML's optimized native image loading
 * - No memory storage in C++ (images loaded on-demand by QML)
 * - Synchronous loading provides immediate display during scrubbing
 */
class ImageLoaderManager : public QObject
{
    Q_OBJECT

public:
    explicit ImageLoaderManager(QObject *parent = nullptr);
    ~ImageLoaderManager();

    /**
     * @brief Set the base paths for all image types
     * @param pathA - Base path for orig images (image type A)
     * @param pathB - Base path for test images (image type B)
     * @param pathC - Base path for diff images (image type C)
     * @param pathD - Base path for alpha images (image type D)
     */
    Q_INVOKABLE void setImagePaths(const QString &pathA, const QString &pathB, const QString &pathC, const QString &pathD);

    /**
     * @brief Get a cached image, or load it if not cached
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param frameNumber - Frame number (1-indexed, e.g., 1, 2, 3...)
     * @return QPixmap of the image, or null QPixmap if not found
     */
    QPixmap getImage(const QString &imageType, int frameNumber);

    /**
     * @brief Get the full file path for an image (without loading it)
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param frameNumber - Frame number (1-indexed, e.g., 1, 2, 3...)
     * @return Full file path as QString, formatted for QML (file:/// prefix, forward slashes)
     */
    Q_INVOKABLE QString getImageFilePath(const QString &imageType, int frameNumber) const;

    /**
     * @brief Get image only if it's already cached (doesn't load from disk)
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param frameNumber - Frame number (1-indexed)
     * @return QPixmap if cached, or null QPixmap if not in cache
     */
    QPixmap getImageIfCached(const QString &imageType, int frameNumber) const;

    /**
     * @brief Preload an image in background thread
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param frameNumber - Frame number (1-indexed)
     */
    void preloadImage(const QString &imageType, int frameNumber);

    /**
     * @brief Preload a range of frames in background (for smooth scrubbing)
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param currentFrame - Current frame number (1-indexed)
     * @param framesBefore - Number of frames before current to preload
     * @param framesAfter - Number of frames after current to preload
     * @param maxFrame - Maximum frame number (to avoid loading beyond range)
     */
    Q_INVOKABLE void preloadFrameRange(const QString &imageType, int currentFrame, int framesBefore, int framesAfter, int maxFrame);

    /**
     * @brief Preload all image types for a frame range (A, B, C, D)
     * @param currentFrame - Current frame number (1-indexed)
     * @param framesBefore - Number of frames before current to preload
     * @param framesAfter - Number of frames after current to preload
     * @param maxFrame - Maximum frame number
     */
    Q_INVOKABLE void preloadAllTypesForRange(int currentFrame, int framesBefore, int framesAfter, int maxFrame);
    
    /**
     * @brief Preload adjacent frames (optimized for small cache)
     * Only preloads ±1-2 frames to keep cache small and memory usage low
     * @param currentFrame - Current frame number (1-indexed)
     * @param maxFrame - Maximum frame number
     * @param imageTypes - Array of image types to preload (e.g., ["A", "B"] for page 2)
     */
    Q_INVOKABLE void preloadAdjacentFrames(int currentFrame, int maxFrame, const QStringList &imageTypes = QStringList());

    /**
     * @brief Clear the image cache
     */
    Q_INVOKABLE void clearCache();

    /**
     * @brief Get cache size (number of images currently cached)
     */
    int getCacheSize() const { return m_cache.size(); }

    /**
     * @brief Set maximum cache size (number of images to keep in memory)
     * @param maxSize - Maximum number of images (default: 20, 0 = disabled)
     */
    Q_INVOKABLE void setMaxCacheSize(int maxSize) {
        if (maxSize < 0) {
            DEBUG_LOG("ImageLoaderManager") << "setMaxCacheSize - Invalid maxSize:" << maxSize << "(must be >= 0)";
            return;
        }
        m_maxCacheSize = maxSize;
    }

    /**
     * @brief Get base path and file extension for an image type
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param basePath - Output parameter for base path
     * @param extension - Output parameter for file extension
     * @return true if imageType is valid, false otherwise
     */
    bool getImageTypePathAndExtension(const QString &imageType, QString &basePath, QString &extension) const;
    
    /**
     * @brief Get maximum cache size
     */
    int getMaxCacheSize() const { return m_maxCacheSize; }

signals:
    /**
     * @brief Emitted when an image has finished loading
     * @param imageType - Image type that was loaded
     * @param frameNumber - Frame number that was loaded
     */
    void imageLoaded(const QString &imageType, int frameNumber);

    /**
     * @brief Emitted when an image failed to load
     * @param imageType - Image type that failed
     * @param frameNumber - Frame number that failed
     * @param errorMessage - Error description
     */
    void imageLoadFailed(const QString &imageType, int frameNumber, const QString &errorMessage);
    
    /**
     * @brief Emitted when a general error occurs (for UI display)
     * @param errorMessage - User-friendly error message
     */
    void errorOccurred(const QString &errorMessage);

private:
    /**
     * @brief Load image from disk synchronously
     * @param imageType - Image type: "A", "B", "C", or "D"
     * @param frameNumber - Frame number (1-indexed)
     * @return QPixmap of the image, or null QPixmap if failed
     */
    QPixmap loadImageFromDisk(const QString &imageType, int frameNumber);


    /**
     * @brief Generate cache key for an image
     * @param imageType - Image type
     * @param frameNumber - Frame number
     * @return Cache key string
     */
    QString getCacheKey(const QString &imageType, int frameNumber) const;

    // Base paths for each image type
    QString m_pathA;  // orig images
    QString m_pathB;  // test images
    QString m_pathC;  // diff images
    QString m_pathD;  // alpha images

    // Image cache: key = "A_0001", value = QPixmap
    QHash<QString, QPixmap> m_cache;
    
    // Cache access order for LRU eviction (most recent at end)
    // Mutable because updating access order is a logical const operation (doesn't change observable cache state)
    mutable QStringList m_cacheAccessOrder;
    
    // Maximum cache size (default: 20 images = ~120MB for 1920x1080)
    int m_maxCacheSize;
    
    // Mutex for thread-safe cache access
    mutable QMutex m_cacheMutex;

    // Thread pool for background loading
    QThreadPool *m_threadPool;
    
    /**
     * @brief Evict oldest images from cache if over limit
     */
    void evictOldestIfNeeded();
};

/**
 * @brief ImageLoadTask - Runnable task for loading images in background thread
 */
class ImageLoadTask : public QRunnable
{
public:
    ImageLoadTask(ImageLoaderManager *manager, const QString &imageType, int frameNumber)
        : m_manager(manager), m_imageType(imageType), m_frameNumber(frameNumber) {}

    void run() override {
        if (m_manager) {
            m_manager->getImage(m_imageType, m_frameNumber);
        }
    }

private:
    ImageLoaderManager *m_manager;
    QString m_imageType;
    int m_frameNumber;
};

#endif // IMAGELOADERMANAGER_H

