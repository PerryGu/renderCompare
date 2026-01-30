/**
 * @file Theme.qml
 * @brief Centralized theme definitions for colors, spacing, and typography
 * 
 * This singleton provides consistent styling across the entire application.
 * Import using: import "Theme.qml" as Theme
 */

pragma Singleton
import QtQuick 2.0

QtObject {
    id: theme
    
    // ============================================================================
    // COLORS
    // ============================================================================
    
    // Primary colors
    readonly property color primaryDark: "#0e2639"
    readonly property color primaryAccent: "#25ae88"
    readonly property color chartMark: "#f7b645"
    
    // Background colors
    readonly property color backgroundDark: "#0e2639"
    readonly property color backgroundLight: "#404040"
    
    // Text colors
    readonly property color textLight: "white"
    readonly property color textDark: "#0e2639"
    readonly property color textAccent: "#25ae88"
    
    // Status colors
    readonly property color statusError: "#d32f2f"
    readonly property color statusErrorAlt: "#d85b4a"      // Alternative error color (red/orange)
    readonly property color statusWarning: "#f7b645"
    readonly property color statusSuccess: "#25ae88"
    readonly property color statusSuccessAlt: "#35b76b"     // Alternative success color (brighter green)
    readonly property color statusInfo: "#505050"
    
    // Selection colors
    readonly property color selectionHighlight: "#14aaff"
    readonly property color selectionHighlightAlt: "#1fcecb" // Alternative selection color (cyan)
    readonly property color selectionBackground: Qt.rgba(0xf7/255.0, 0xb6/255.0, 0x45/255.0, 0.3)
    
    // Border colors
    readonly property color borderDark: "#0e2639"           // Primary dark border
    readonly property color borderAccent: "#25ae88"         // Accent border
    readonly property color borderAccentDark: "#1f8e6f"    // Darker accent border
    readonly property color borderLight: "white"            // Light border
    readonly property color borderYellow: "#cccc99"         // Yellow border
    
    // Overlay colors
    readonly property color overlayDark: "#80000000"        // Semi-transparent black overlay
    readonly property color overlayAccent: Qt.rgba(0x25/255.0, 0xae/255.0, 0x88/255.0, 0.3)  // Semi-transparent accent overlay
    readonly property color overlayChartMark: Qt.rgba(0xf7/255.0, 0xb6/255.0, 0x45/255.0, 0.3)  // Semi-transparent chart mark overlay
    
    // Gradient colors
    readonly property color gradientTop: "#3d4444"          // Top gradient color (lighter gray)
    readonly property color gradientBottom: "#0a0c0c"       // Bottom gradient color (darker gray)
    
    // Button state colors
    readonly property color buttonDefault: "#1a1a1a"        // Default button background
    readonly property color buttonPressed: "#2a2a2a"        // Pressed button state
    readonly property color buttonHovered: "#3a3a3a"        // Hovered button state
    
    // Background colors (extended)
    readonly property color backgroundVeryLight: "#f0f0f0"  // Very light gray background
    readonly property color backgroundLightGray: "#dcdcdc"  // Light gray background
    readonly property color backgroundPaleBlue: "#f3f8f9"    // Very light blue/gray background
    readonly property color backgroundYellow: "#ffffcc"      // Yellow background
    
    // Text colors (extended)
    readonly property color textBlack: "black"              // Pure black text
    readonly property color textDarkGray: "#333333"         // Dark gray text
    readonly property color textMediumGray: "#555555"       // Medium gray text/separator
    
    // Special UI colors
    readonly property color uiRed: "red"                    // Pure red
    readonly property color uiSteelBlue: "steelblue"        // Steel blue
    readonly property color uiTransparent: "transparent"     // Transparent
    
    // ============================================================================
    // SPACING & DIMENSIONS
    // ============================================================================
    
    // Window dimensions
    readonly property int defaultWindowWidth: 1600
    readonly property int defaultWindowHeight: 850
    
    // Header dimensions
    readonly property int headerHeight: 100
    readonly property int headerTopMargin: 34
    
    // Chart dimensions
    readonly property int chartTopMargin: 50
    readonly property int chartBottomMargin: 34
    
    // Button dimensions
    readonly property int buttonWidth: 180
    readonly property int buttonHeight: 80
    readonly property int buttonScaledMargin: 2
    
    // SwipeView dimensions
    readonly property int swipeViewDefaultHeight: 550
    readonly property int swipeViewMinHeight: 300
    readonly property int swipeViewMaxHeight: 1200
    
    // Chart dimensions
    readonly property int chartDefaultHeight: 300
    readonly property int chartMinHeight: 100
    readonly property int chartMaxHeight: 1200
    
    // InfoHeader dimensions
    readonly property int infoHeaderBottomMargin: 84
    
    // ============================================================================
    // TYPOGRAPHY
    // ============================================================================
    
    readonly property int fontSizeTiny: 7          // Tiny text (circular progress bars, very small labels)
    readonly property int fontSizeExtraSmall: 11   // Very small text (log window filters, labels)
    readonly property int fontSizeMedium: 12        // Medium-small text (input fields, secondary text)
    readonly property int fontSizeSmall: 14         // Small text (secondary labels, tooltips)
    readonly property int fontSizeDialogTitle: 16   // Dialog titles (error/edit dialogs)
    readonly property int fontSizeNormal: 20         // Normal text (default body text)
    readonly property int fontSizeLarge: 25         // Large text (headers, titles)
    readonly property int fontSizeExtraLarge: 35    // Extra large text (large headers, buttons)
    
    // ============================================================================
    // OPACITY VALUES
    // ============================================================================
    
    readonly property real opacityDefault: 1.0
    readonly property real opacityDisabled: 0.5
    readonly property real opacityHover: 0.7
    readonly property real opacityActive: 0.95              // Active/selected state opacity
    readonly property real opacityInactive: 0.4              // Inactive state opacity
    readonly property real opacityVeryLow: 0.1               // Very low opacity for subtle effects
    readonly property real guideOpacity: 0.5                 // Guide lines opacity
}
