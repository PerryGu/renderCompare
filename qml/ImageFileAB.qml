/**
 * @file ImageFileAB.qml
 * @brief Image display component for original (A) and test (B) renders
 * 
 * This component displays either the original render (imageA) or test render (imageB)
 * using double-buffered image loading. It's used in the 3-window comparison view
 * to show side-by-side comparison of expected vs actual renders.
 * 
 * Features:
 * - Double-buffered loading for smooth frame scrubbing
 * - Automatic buffer swapping
 * - Error handling for missing images
 * - Integration with parent component's error reporting
 */

import QtQuick 2.2
import Theme 1.0

Rectangle {
    id:imageContainer_id
    color: Theme.primaryDark
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    property string pathImage

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

    // Use reusable DoubleBufferedImage component
    DoubleBufferedImage {
        id: doubleBufferedImage
        anchors.fill: parent
        showLoadingText: true
        
        // Connect image errors to show error dialog
        onImageError: function(source) {
            // Extract frame number from path for user-friendly message
            var frameMatch = source.match(/F(\d{4})\.jpg/)
            var frameNum = frameMatch ? frameMatch[1] : "unknown"
            var errorMsg = "Image file not found: Frame " + frameNum + "\n\nPath: " + source.replace(/file:\/\/\//g, "")
            
            // Try to show error in main.qml if accessible
            // Find mainItem by walking up the parent chain
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
}



