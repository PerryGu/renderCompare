/**
 * @file ImageFileC.qml
 * @brief Image display component for difference visualization (imageC) with effects
 * 
 * This component displays the difference image (imageC) with adjustable image effects
 * (hue, saturation, lightness) using Qt's HueSaturation effect. Used in the 3-window
 * comparison view to highlight differences between original and test renders.
 * 
 * Features:
 * - Double-buffered image loading via DoubleBufferedImage component
 * - HueSaturation effect for color adjustment
 * - Real-time effect parameter updates
 * - Error handling with user-friendly messages
 */

import QtQuick 2.2
import QtGraphicalEffects 1.0
import Theme 1.0

Rectangle {
    id:imageContainer_id
    color: Theme.primaryDark
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    property string pathImage
    property real hueValue: 1.0
    property real lightnessValue: 0.15
    property real saturationValue: 0.5

    /**
     * @brief Update the displayed frame image
     * 
     * Called when user scrubs the timeline. Updates the image source
     * to display the frame at the specified path.
     * 
     * @param frameIndex_path - Full file path to the frame image (file:/// URL)
     */
    function indexUpdate(frameIndex_path){
        pathImage = frameIndex_path
        doubleBufferedImage.updateImage(frameIndex_path)
    }

    /**
     * @brief Update hue value for HueSaturation effect
     * @param val - Hue value (-1.0 to 1.0)
     */
    function sliderUpdateHue(val){
        hueValue = val
    }
    
    /**
     * @brief Update lightness value for HueSaturation effect
     * @param val - Lightness value (-1.0 to 1.0)
     */
    function sliderUpdateLight(val){
        lightnessValue = val
    }
    
    /**
     * @brief Update saturation value for HueSaturation effect
     * @param val - Saturation value (-1.0 to 1.0)
     */
    function sliderUpdateSat(val){
        saturationValue = val
    }

    // Use reusable DoubleBufferedImage component with HueSaturation effect
    Item {
        id: imageContainer
        anchors.fill: parent
        
        DoubleBufferedImage {
            id: doubleBufferedImage
            anchors.fill: parent
            showLoadingText: true
            
            // Connect image errors to show error dialog
            onImageError: function(source) {
                // Extract frame number from path for user-friendly message
                var frameMatch = source.match(/F(\d{4})\.jpg/)
                var frameNum = frameMatch ? frameMatch[1] : "unknown"
                var errorMsg = "Difference image not found: Frame " + frameNum + "\n\nPath: " + source.replace(/file:\/\/\//g, "")
                
                // Try to show error in main.qml if accessible
                var parentItem = imageContainer_id.parent
                while (parentItem) {
                    // Check if parent has mainItemRef (TheSwipeView pattern)
                    if (parentItem.mainItemRef && parentItem.mainItemRef.showError && typeof parentItem.mainItemRef.showError === "function") {
                        parentItem.mainItemRef.showError(errorMsg)
                        break
                    }
                    // Also check if parent itself has showError (direct access)
                    if (parentItem.showError && typeof parentItem.showError === "function") {
                        parentItem.showError(errorMsg)
                        break
                    }
                    parentItem = parentItem.parent
                }
            }
        }
        
        // Apply HueSaturation effect to the currently visible buffer
        HueSaturation {
            id: hueSaturation
            anchors.fill: parent
            source: doubleBufferedImage.currentImage
            hue: hueValue
            saturation: saturationValue
            lightness: lightnessValue
        }
    }
}


