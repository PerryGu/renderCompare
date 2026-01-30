/**
 * @file Constants.qml
 * @brief Application-wide constants and configuration values
 * 
 * This singleton provides constants used throughout the application.
 * Import using: import "Constants.qml" as Constants
 */

pragma Singleton
import QtQuick 2.0

QtObject {
    id: constants
    
    // ============================================================================
    // IMAGE TYPE CONSTANTS (for C++ ImageLoaderManager)
    // ============================================================================
    
    readonly property string imageTypeOrig: "A"      // Original/expected render
    readonly property string imageTypeTest: "B"      // Test/actual render
    readonly property string imageTypeDiff: "C"      // Difference image
    readonly property string imageTypeAlpha: "D"     // Alpha/mask image
    
    // ============================================================================
    // IMAGE COMPONENT TYPE CONSTANTS (for QML component names)
    // ============================================================================
    
    readonly property string componentImageA: "imageA"
    readonly property string componentImageB: "imageB"
    readonly property string componentImageC: "imageC"
    readonly property string componentImageD: "imageD"
    
    // ============================================================================
    // PAGE INDICES
    // ============================================================================
    
    readonly property int pageTable: 0           // Page 1: Table view (event selection)
    readonly property int pageThreeWindow: 1     // Page 2: 3-window comparison view (A, B, C)
    readonly property int pageSingleWindow: 2     // Page 3: Single large window view (D with A/B toggle)
    
    // ============================================================================
    // FRAME FORMATTING
    // ============================================================================
    
    readonly property int framePadding: 4        // Number of digits for frame padding (e.g., "0001")
    
    // ============================================================================
    // SLIDER & CHART
    // ============================================================================
    
    readonly property int chartAxisPadding: 5    // Padding for chart axis (minVal_x - 5, maxVal_x + 5)
    readonly property real defaultThreshold: 1.0
    readonly property int defaultPlaybackSpeed: 100  // milliseconds per frame
    
    // ============================================================================
    // THREAD POOL
    // ============================================================================
    
    readonly property int maxThreadCount: 4      // Maximum concurrent image loads
    
    // ============================================================================
    // TIMER INTERVALS
    // ============================================================================
    
    readonly property int pageNavigationDelay: 100  // Delay before navigating to page after double-click (ms)
    readonly property int animationReenableDelay: 300  // Delay before re-enabling chart animation after navigation (ms)
    readonly property int threadWaitTimeout: 3000  // Thread wait timeout in milliseconds
    
    // ============================================================================
    // TIMELINE CHART UI CONSTANTS
    // ============================================================================
    
    // Button dimensions
    readonly property int buttonMinWidth: 24
    readonly property int buttonPreferredWidth: 24
    readonly property int buttonMaxWidth: 120
    readonly property int buttonMinHeight: 24
    readonly property int buttonPreferredHeight: 36
    readonly property int buttonIconSize: 42
    
    // Control panel dimensions
    readonly property int controlPanelMaxWidth: 600
    readonly property int controlPanelMinMargin: 200
    readonly property int controlPanelTopMargin: 7
    readonly property int controlPanelBottomMargin: 7
    readonly property int controlPanelSpacing: 4
    readonly property int controlPanelBorderWidth: 2
    
    // Frame offset
    readonly property int frameOffset: 10  // Start slider at startFrame + 10
    
    // Timeline zoom offsets
    readonly property int timelineZoomStartOffset: 4  // Offset for start handle calculation
    readonly property int timelineZoomEndOffset: 5    // Offset for end handle calculation
    
    // Menu dimensions
    readonly property int menuItemHeight: 22
    readonly property int playbackSpeedMenuWidth: 120
    readonly property int playbackSpeedMenuHeight: 160
    
    // Navigation panel button margins
    readonly property int buttonLeftMargin: 10
    readonly property int buttonRightMargin: 10
    readonly property int buttonImageMargin: 10  // Margin for images inside buttons
    
    // Frame input field
    readonly property int frameInputWidth: 50
    readonly property int frameInputMargin: 2
    
    // Page index buttons
    readonly property int pageIndexButtonWidth: 60
    readonly property int pageIndexButtonHeight: 42
    readonly property int pageIndexButtonIconSize: 24
    readonly property int pageIndexButtonMargin: 15
    readonly property int pageIndexButtonTopMargin: 8
    
    // Timeline slider
    readonly property int timelineSliderX: 55
    readonly property int timelineSliderWidthOffset: 90
    readonly property int timelineSliderGrooveHeight: 5
    readonly property int timelineSliderHandleWidth: 90
    readonly property int timelineSliderHandleHeight: 20
    
    // ============================================================================
    // PLAYBACK SPEEDS (milliseconds per frame)
    // ============================================================================
    
    readonly property int playbackSpeedVerySlow: 400  // 0.25x speed
    readonly property int playbackSpeedSlow: 200      // 0.5x speed
    readonly property int playbackSpeedNormal: 100     // 1x speed (default)
    readonly property int playbackSpeedFast: 50       // 2x speed
    readonly property int playbackSpeedVeryFast: 33    // 3x speed
    
    // ============================================================================
    // TABLE VIEW CONSTANTS
    // ============================================================================
    
    readonly property int tableColumnCount: 11  // Number of columns in table model
    
    // ============================================================================
    // APPLICATION VERSION
    // ============================================================================
    
    // Application version (set from C++ context property, fallback to default if not available)
    readonly property string appVersion: typeof appVersion !== "undefined" ? appVersion : "1.0.0"
    readonly property string appName: "Render Compare"
    readonly property string appNameWithVersion: appName + " v" + appVersion
}
