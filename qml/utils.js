/**
 * @fileoverview Utility functions and constants for common operations
 * 
 * This file contains reusable utility functions and constants used throughout the application.
 */

/**
 * Image type constants for C++ ImageLoaderManager calls
 * These match the image type strings used in C++ (single letter)
 */
var IMAGE_TYPE_ORIG = "A"      // Original/expected render
var IMAGE_TYPE_TEST = "B"      // Test/actual render
var IMAGE_TYPE_DIFF = "C"      // Difference image
var IMAGE_TYPE_ALPHA = "D"     // Alpha/mask image

/**
 * Image component type constants for QML component names
 * These match the image_type property values used in QML components
 */
var IMAGE_COMPONENT_A = "imageA"
var IMAGE_COMPONENT_B = "imageB"
var IMAGE_COMPONENT_C = "imageC"
var IMAGE_COMPONENT_D = "imageD"

/**
 * @brief Format a frame number as a 4-digit zero-padded string
 * @param {number} frameNumber - Frame number (0-indexed or 1-indexed)
 * @param {boolean} isZeroIndexed - If true, frameNumber is 0-indexed (will add 1). If false, frameNumber is already 1-indexed.
 * @return {string} Formatted string like "0001", "0002", etc. (clamped to 9999 max)
 */
function formatFrameNumber(frameNumber, isZeroIndexed) {
    var frameIndex = isZeroIndexed ? (frameNumber + 1) : frameNumber
    // Clamp to 4-digit maximum (9999) to prevent overflow
    if (frameIndex > 9999) {
        frameIndex = 9999
    }
    // Ensure non-negative
    if (frameIndex < 0) {
        frameIndex = 0
    }
    var str = "" + frameIndex
    var pad = "0000"
    return pad.substring(0, pad.length - str.length) + str
}

/**
 * @brief Convert a padded frame string to a frame number
 * @param {string} paddedFrame - String like "0001", "0002", etc.
 * @param {boolean} isZeroIndexed - If true, return 0-indexed. If false, return 1-indexed (default).
 * @return {number} Frame number
 */
function parseFrameNumber(paddedFrame, isZeroIndexed) {
    var frameNum = parseInt(paddedFrame.toString())
    return isZeroIndexed ? (frameNum - 1) : frameNum
}

/**
 * @brief Format a Windows path to QML-compatible file:// URL
 * @param {string} path - Windows path (may contain backslashes)
 * @return {string} QML-compatible file:/// URL with forward slashes
 */
function formatPathForQML(path) {
    if (!path) return ""
    // Convert backslashes to forward slashes
    var formatted = path.replace(/\\/g, "/")
    // Remove trailing slash if present (we'll add it)
    if (formatted.endsWith("/")) {
        formatted = formatted.substring(0, formatted.length - 1)
    }
    // Add file:// prefix and trailing slash
    return "file:///" + formatted + "/"
}

/**
 * @brief Format a Windows file path to QML-compatible file:// URL (for individual files, not directories)
 * @param {string} filePath - Windows file path (may contain backslashes)
 * @return {string} QML-compatible file:/// URL with forward slashes (no trailing slash)
 */
function formatFilePathForQML(filePath) {
    if (!filePath) return ""
    // Convert backslashes to forward slashes
    var formatted = filePath.replace(/\\/g, "/")
    // Remove trailing slash if present (files shouldn't have trailing slashes)
    if (formatted.endsWith("/")) {
        formatted = formatted.substring(0, formatted.length - 1)
    }
    // Add file:// prefix (no trailing slash for files)
    return "file:///" + formatted
}


