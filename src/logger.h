#ifndef LOGGER_H
#define LOGGER_H

#include <QDebug>
#include <QLoggingCategory>

/**
 * @brief Centralized logging utility for conditional debug output
 * 
 * This utility provides debug logging that is automatically disabled
 * in release builds, preventing performance overhead and information leakage.
 * 
 * Usage:
 *   DEBUG_LOG("Message") << variable;
 *   DEBUG_LOG("Category") << "Debug info";
 * 
 * In debug builds: Outputs to console
 * In release builds: No overhead (compiled out)
 */
#ifdef QT_DEBUG
    // Debug build: Enable logging
    #define DEBUG_LOG(category) qDebug() << "[" << category << "]"
    #define DEBUG_LOG_MSG(msg) qDebug() << msg
#else
    // Release build: Disable logging (no overhead)
    #define DEBUG_LOG(category) QNoDebug()
    #define DEBUG_LOG_MSG(msg) ((void)0)
#endif

/**
 * @brief Error logging (always enabled, even in release)
 * Use for important errors that should always be logged
 */
#define ERROR_LOG(msg) qCritical() << "[ERROR]" << msg
#define WARNING_LOG(msg) qWarning() << "[WARNING]" << msg
#define INFO_LOG(msg) qInfo() << "[INFO]" << msg

#endif // LOGGER_H
