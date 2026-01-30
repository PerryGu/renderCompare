/**
 * @file Logger.qml
 * @brief Centralized logging system for the application
 * 
 * This singleton provides a logging service that can be used throughout the application.
 * Messages are stored and can be displayed in a log window.
 * Import using: import Logger 1.0
 */

pragma Singleton
import QtQuick 2.0
import Theme 1.0

QtObject {
    id: logger
    
    // Maximum number of log entries to keep in memory
    readonly property int maxLogEntries: 1000
    
    // Signal emitted when a new log entry is added (emits the entry object)
    signal logEntryAdded(var entry)
    
    // Signal emitted when log is cleared
    signal logCleared()
    
    // List of log entries (each entry is an object with level, message, timestamp)
    property var logEntries: []
    
    // Property to control whether debug messages are logged to console
    // Set to false in production builds to disable debug console output
    property bool enableDebugConsoleOutput: true  // Change to false for production
    
    // Property to track if LogWindow is visible (to pause logging when closed)
    property bool logWindowVisible: false
    
    // Property to control which log levels are enabled
    property bool showInfo: true
    property bool showWarning: true
    property bool showError: true
    property bool showDebug: true
    
    /**
     * @brief Add a log entry
     * @param level - Log level: "INFO", "WARNING", "ERROR", "DEBUG"
     * @param message - Log message text
     */
    function log(level, message) {
        if (!message || message === "") {
            return
        }
        
        var timestamp = new Date().toLocaleTimeString()
        var entry = {
            level: level || "INFO",
            message: message,
            timestamp: timestamp
        }
        
        // Add to log entries (always, for LogWindow)
        logEntries.push(entry)
        
        // Limit log entries to prevent memory issues
        if (logEntries.length > maxLogEntries) {
            logEntries.shift()  // Remove oldest entry
        }
        
        // Emit signal for log window to update (only if window is visible)
        // This prevents unnecessary processing when window is closed
        if (logWindowVisible) {
            logEntryAdded(entry)
        }
        
        // Output to console:
        // - INFO, WARNING, ERROR: Always log to console (user-facing)
        // - DEBUG: Only log to console if enableDebugConsoleOutput is true
        var isDebugMessage = (level === "DEBUG")
        var shouldLogToConsole = !isDebugMessage || enableDebugConsoleOutput
        
        if (shouldLogToConsole) {
            console.log("[" + entry.level + "] " + entry.timestamp + " - " + entry.message)
        }
    }
    
    /**
     * @brief Log an info message
     */
    function info(message) {
        log("INFO", message)
    }
    
    /**
     * @brief Log a warning message
     */
    function warning(message) {
        log("WARNING", message)
    }
    
    /**
     * @brief Log an error message
     */
    function error(message) {
        log("ERROR", message)
    }
    
    /**
     * @brief Log a debug message
     */
    function debug(message) {
        log("DEBUG", message)
    }
    
    /**
     * @brief Clear all log entries
     */
    function clear() {
        logEntries = []
        logCleared()  // Emit signal that log was cleared
        log("INFO", "Log cleared")
    }
    
    /**
     * @brief Get formatted log text for display
     * @param maxLines - Maximum number of lines to return (0 = all)
     * @param filterLevels - Optional array of levels to include (e.g., ["INFO", "WARNING"])
     */
    function getFormattedText(maxLines, filterLevels) {
        if (logEntries.length === 0) {
            return []  // Return empty array for ListView
        }
        
        // Determine which levels to show
        var levelsToShow = filterLevels || []
        if (levelsToShow.length === 0) {
            // Use current filter settings
            if (showInfo) levelsToShow.push("INFO")
            if (showWarning) levelsToShow.push("WARNING")
            if (showError) levelsToShow.push("ERROR")
            if (showDebug) levelsToShow.push("DEBUG")
        }
        
        var lines = []
        var startIndex = maxLines > 0 && logEntries.length > maxLines 
            ? logEntries.length - maxLines 
            : 0
        
        for (var i = startIndex; i < logEntries.length; i++) {
            var entry = logEntries[i]
            // Filter by level
            if (levelsToShow.indexOf(entry.level) !== -1) {
                lines.push(entry)  // Return entry object for color coding
            }
        }
        
        return lines
    }
    
    /**
     * @brief Get log entries as formatted HTML text (for color-coded display with text selection)
     * @param maxLines - Maximum number of lines to return (0 = all)
     */
    function getFormattedTextHTML(maxLines) {
        var entries = getFormattedText(maxLines)
        if (entries.length === 0) {
            // Use Theme color directly (QML colors convert to hex strings automatically)
            return "<span style='color: " + Theme.textMediumGray + ";'>No log entries</span>"
        }
        
        var lines = []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            var color = Theme.textMediumGray  // Default gray
            if (entry.level === "ERROR") color = Theme.statusError      // Red
            else if (entry.level === "WARNING") color = Theme.statusWarning  // Yellow
            else if (entry.level === "INFO") color = Theme.statusSuccess     // Green
            else if (entry.level === "DEBUG") color = Theme.textMediumGray    // Gray
            
            var escapedMessage = entry.message.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            lines.push("<span style='color: " + color + ";'>[" + entry.timestamp + "] [" + entry.level + "] " + escapedMessage + "</span>")
        }
        
        return lines.join("<br>")
    }
    
    /**
     * @brief Get log entries as formatted text (for backward compatibility)
     */
    function getFormattedTextPlain(maxLines) {
        var entries = getFormattedText(maxLines)
        if (entries.length === 0) {
            return "No log entries"
        }
        
        var lines = []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            lines.push("[" + entry.timestamp + "] [" + entry.level + "] " + entry.message)
        }
        
        return lines.join("\n")
    }
}
