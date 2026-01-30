/**
 * @file ImageFileD.qml
 * @brief Image display component for alpha mask (imageD) with A/B toggle and effects
 * 
 * This component displays the alpha mask (imageD) with the ability to toggle between
 * showing the original (imageA) or test (imageB) render underneath. Used in the
 * single-window view (page 2) for detailed inspection.
 * 
 * Features:
 * - Double-buffered image loading for smooth scrubbing
 * - OpacityMask effect to overlay A or B render with alpha mask
 * - HueSaturation effect for color adjustment
 * - Toggle between imageA and imageB via opacity control
 * - Real-time effect parameter updates (hue, saturation, lightness, opacity)
 * - Error handling for missing image files
 */

import QtQuick 2.2
import QtGraphicalEffects 1.0
import Theme 1.0
import Logger 1.0

Rectangle {
    id:imageContainer_id
    color: Theme.primaryDark
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    property string imagePathA
    property string imagePathB
    property string imagePathD
    property real hueValue: 1.0
    property real lightnessValue: 0.15
    property real saturationValue: 0.5
    property real opacityValue: 0.5
    
    property int frontBuffer: 1
    property int backBuffer: 2
    property bool showingVersionA: buffer1ImageHoldA.opacity === 1
    
    property string buffer1SourceA: ""
    property string buffer1SourceB: ""
    property string buffer1SourceD: ""
    property string buffer2SourceA: ""
    property string buffer2SourceB: ""
    property string buffer2SourceD: ""
    property string requestedFrameA: ""
    property string requestedFrameB: ""
    property string requestedFrameD: ""
    
    /**
     * @brief Show image error by bubbling up to main.qml
     * 
     * Helper function that walks up the parent chain to find mainItemRef
     * and displays an error dialog. Used when image files fail to load.
     * 
     * @param errorMsg - Error message to display
     */
    function showImageError(errorMsg) {
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
    
    readonly property var imageOpacitySource: frontBuffer === 1 ? 
        (buffer1ImageHoldA.opacity === 1 ? buffer1ImageA : buffer1ImageB) :
        (buffer2ImageHoldA.opacity === 1 ? buffer2ImageA : buffer2ImageB)

    /**
     * @brief Update frame index with optimized loading for page 3 (single large window)
     * 
     * This function implements an important performance optimization: it only loads
     * the currently visible image version (A or B) plus the alpha mask (D), rather
     * than loading both A and B simultaneously. This reduces image loading from
     * 3 images per frame to 2 images per frame, significantly improving scrubbing
     * performance.
     * 
     * The function uses double-buffering to ensure smooth transitions:
     * - Loads new images into the back buffer
     * - Keeps current images visible in the front buffer
     * - Swaps buffers when new images are ready
     * 
     * Frame tracking (requestedFrameA/B/D) prevents stale images from being displayed
     * if the user scrubs faster than images can load.
     * 
     * @param imagePathA - Full path to original image (type A) for current frame
     * @param imagePathB - Full path to test image (type B) for current frame
     * @param imagePathD - Full path to alpha/mask image (type D) for current frame
     */
    function indexUpdate(imagePathA_param, imagePathB_param, imagePathD_param){
        // Always update during scrubbing for immediate response
        // Store the current frame paths in component properties for use when switching
        // Use different parameter names to avoid shadowing component properties
        imageContainer_id.imagePathA = imagePathA_param
        imageContainer_id.imagePathB = imagePathB_param
        imageContainer_id.imagePathD = imagePathD_param
        requestedFrameA = imagePathA_param  // Track the most recent request
        requestedFrameB = imagePathB_param
        requestedFrameD = imagePathD_param
        
        // OPTIMIZATION: Only load the currently visible version (A or B) plus D
        // This reduces from 3 images to 2 images per frame, making scrubbing faster
        var currentlyShowingA = (frontBuffer === 1 ? buffer1ImageHoldA.opacity === 1 : buffer2ImageHoldA.opacity === 1)
        
        // Double-buffering: Load new images into back buffer (without clearing front buffer)
        if (frontBuffer === 1) {
            // Currently showing buffer 1, load new images into buffer 2
            // Only load the visible version to speed up loading
            if (currentlyShowingA) {
                buffer2SourceA = imagePathA_param
                buffer2SourceB = ""  // Don't load B if we're showing A
            } else {
                buffer2SourceA = ""  // Don't load A if we're showing B
                buffer2SourceB = imagePathB_param
            }
            buffer2SourceD = imagePathD_param  // Always load D (mask)
            // Keep buffer1 sources unchanged so old images stay visible
        } else {
            // Currently showing buffer 2, load new images into buffer 1
            // Only load the visible version to speed up loading
            if (currentlyShowingA) {
                buffer1SourceA = imagePathA_param
                buffer1SourceB = ""  // Don't load B if we're showing A
            } else {
                buffer1SourceA = ""  // Don't load A if we're showing B
                buffer1SourceB = imagePathB_param
            }
            buffer1SourceD = imagePathD_param  // Always load D (mask)
            // Keep buffer2 sources unchanged so old images stay visible
        }
    }
    
    /**
     * @brief Check if buffer images are ready and swap buffers if complete
     * 
     * This function implements the buffer swapping logic for double-buffering.
     * It only checks if the visible image (A or B, depending on current state)
     * and the mask (D) are ready, not both A and B. This is part of the optimization
     * that reduces image loading overhead.
     * 
     * The swap only occurs if:
     * 1. The buffer being checked is the back buffer (not currently visible)
     * 2. The visible image (A or B) is ready
     * 3. The mask image (D) is ready
     * 4. The sources are not empty
     * 
     * @param bufferNumber - Which buffer to check (1 or 2)
     */
    function checkAndSwapBuffer(bufferNumber) {
        if (bufferNumber === 1 && frontBuffer === 2) {
            var showingA1 = buffer1ImageHoldA.opacity === 1
            var visibleImageReady1 = showingA1 ? buffer1ImageA.status === Image.Ready : buffer1ImageB.status === Image.Ready
            var hasVisibleSource1 = showingA1 ? buffer1SourceA !== "" : buffer1SourceB !== ""
            
            if (visibleImageReady1 && 
                buffer1Mask.status === Image.Ready &&
                hasVisibleSource1 && buffer1SourceD !== "") {
                frontBuffer = 1
                backBuffer = 2
            }
        } else if (bufferNumber === 2 && frontBuffer === 1) {
            var showingA2 = buffer2ImageHoldA.opacity === 1
            var visibleImageReady2 = showingA2 ? buffer2ImageA.status === Image.Ready : buffer2ImageB.status === Image.Ready
            var hasVisibleSource2 = showingA2 ? buffer2SourceA !== "" : buffer2SourceB !== ""
            
            if (visibleImageReady2 && 
                buffer2Mask.status === Image.Ready &&
                hasVisibleSource2 && buffer2SourceD !== "") {
                frontBuffer = 2
                backBuffer = 1
            }
        }
    }

    /**
     * @brief Switch between displaying original (A) and test (B) image versions
     * 
     * Toggles the visible image version in both buffers. If the newly visible
     * version hasn't been loaded yet (lazy loading), it loads it on-demand.
     * This allows users to quickly compare original vs test renders without
     * preloading both versions for every frame.
     * 
     * The function updates opacity of both buffer holders to show/hide the
     * appropriate images, and triggers loading if needed.
     */
    function imageSwitc(){
        // This function switches between A and B images
        // When switching, load the newly visible version using the CURRENT frame paths
        // Use requestedFrameA/B to ensure we load the correct frame that matches the timeline
        var currentPathA = requestedFrameA || imageContainer_id.imagePathA || ""
        var currentPathB = requestedFrameB || imageContainer_id.imagePathB || ""
        
        if (buffer1ImageHoldA.opacity === 1){
            // Switch from A to B in both buffers
            Logger.info("[UI] Image D switched: A → B")
            buffer1ImageHoldB.opacity = 1
            buffer1ImageHoldA.opacity = 0
            buffer2ImageHoldB.opacity = 1
            buffer2ImageHoldA.opacity = 0
            
            // Load B images for the CURRENT frame (matching timeline position)
            if (buffer1SourceB === "" && currentPathB !== "") {
                buffer1SourceB = currentPathB
            }
            if (buffer2SourceB === "" && currentPathB !== "") {
                buffer2SourceB = currentPathB
            }
        }
        else if (buffer1ImageHoldB.opacity === 1){
            // Switch from B to A in both buffers
            Logger.info("[UI] Image D switched: B → A")
            buffer1ImageHoldA.opacity = 1
            buffer1ImageHoldB.opacity = 0
            buffer2ImageHoldA.opacity = 1
            buffer2ImageHoldB.opacity = 0
            
            // Load A images for the CURRENT frame (matching timeline position)
            if (buffer1SourceA === "" && currentPathA !== "") {
                buffer1SourceA = currentPathA
            }
            if (buffer2SourceA === "" && currentPathA !== "") {
                buffer2SourceA = currentPathA
            }
        }
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

    /**
     * @brief Update opacity value for mask overlay
     * @param val - Opacity value (0.0 to 1.0)
     */
    function sliderUpdateOpacity(val){
        opacityValue = val
    }

    // Loading text removed - no longer needed with optimized loading

    // Double-buffering: Two complete buffer sets that alternate
    // This ensures there's always an image visible (no blue screen flash)
    
    // Buffer 1 - keeps its images until new ones are ready
    Item {
        id: buffer1
        anchors.fill: parent
        z: frontBuffer === 1 ? 2 : 1
        
        Item{
            id: buffer1ImageHoldA
            anchors.fill: parent
            opacity: 1
            Image {
                id: buffer1ImageA
                anchors.fill: parent
                source: buffer1SourceA
                // No sourceSize - let QML load full image directly (fastest path)
                fillMode: Image.PreserveAspectFit
                asynchronous: false  // Synchronous for immediate display during scrubbing
                cache: false  // Disable cache - we're loading directly from disk each time
                
                onStatusChanged: {
                    if (status === Image.Ready) {
                        // Immediately check and swap if all images in buffer 1 are ready
                        // Don't wait - swap as soon as possible for smooth scrubbing
                        checkAndSwapBuffer(1)
                    } else if (status === Image.Error) {
                        // Show error dialog for missing image
                        var frameMatch = buffer1SourceA.match(/F(\d{4})\.jpg/)
                        var frameNum = frameMatch ? frameMatch[1] : "unknown"
                        var errorMsg = "Image file not found: Frame " + frameNum + " (Version A)\n\nPath: " + buffer1SourceA.replace(/file:\/\/\//g, "")
                        showImageError(errorMsg)
                    }
                }
            }
        }

        Item{
            id: buffer1ImageHoldB
            anchors.fill: parent
            opacity: 0
            Image {
                id: buffer1ImageB
                anchors.fill: parent
                source: buffer1SourceB
                // No sourceSize - let QML load full image directly (fastest path)
                fillMode: Image.PreserveAspectFit
                asynchronous: false  // Synchronous for immediate display during scrubbing
                cache: false  // Disable cache - we're loading directly from disk each time
                
                onStatusChanged: {
                    if (status === Image.Ready) {
                        // Immediately check and swap if all images in buffer 1 are ready
                        // Don't wait - swap as soon as possible for smooth scrubbing
                        checkAndSwapBuffer(1)
                    } else if (status === Image.Error) {
                        // Show error dialog for missing image
                        var frameMatch = buffer1SourceA.match(/F(\d{4})\.jpg/)
                        var frameNum = frameMatch ? frameMatch[1] : "unknown"
                        var errorMsg = "Image file not found: Frame " + frameNum + " (Version A)\n\nPath: " + buffer1SourceA.replace(/file:\/\/\//g, "")
                        showImageError(errorMsg)
                    }
                }
            }
        }

        Image {
            id: buffer1Mask
            anchors.fill: parent
            opacity: opacityValue
            source: buffer1SourceD
            // No sourceSize - let QML load full image directly (fastest path)
            fillMode: Image.PreserveAspectFit
            asynchronous: false  // Synchronous for immediate display during scrubbing
            cache: false  // Disable cache - we're loading directly from disk each time
            
            onStatusChanged: {
                if (status === Image.Ready) {
                    checkAndSwapBuffer(1)
                } else if (status === Image.Error) {
                    // Show error dialog for missing alpha mask
                    var frameMatch = buffer1SourceD.match(/F(\d{4})\.png/)
                    var frameNum = frameMatch ? frameMatch[1] : "unknown"
                    var errorMsg = "Alpha mask not found: Frame " + frameNum + "\n\nPath: " + buffer1SourceD.replace(/file:\/\/\//g, "")
                    showImageError(errorMsg)
                }
            }
        }

        OpacityMask{
            id: buffer1OpacityMask
            anchors.fill: parent
            source: buffer1ImageHoldA.opacity === 1 ? buffer1ImageA : buffer1ImageB
            maskSource: buffer1Mask
            visible: frontBuffer === 1
        }

        HueSaturation {
            id: buffer1HueSaturation
            anchors.fill: parent
            source: buffer1Mask
            hue: hueValue
            saturation: saturationValue
            lightness: lightnessValue
            opacity: opacityValue
            visible: frontBuffer === 1
        }
    }
    
    // Buffer 2 - keeps its images until new ones are ready
    Item {
        id: buffer2
        anchors.fill: parent
        z: frontBuffer === 2 ? 2 : 1
        
        Item{
            id: buffer2ImageHoldA
            anchors.fill: parent
            opacity: 1
            Image {
                id: buffer2ImageA
                anchors.fill: parent
                source: buffer2SourceA
                // No sourceSize - let QML load full image directly (fastest path)
                fillMode: Image.PreserveAspectFit
                asynchronous: false  // Synchronous for immediate display during scrubbing
                cache: false  // Disable cache - we're loading directly from disk each time
                
                onStatusChanged: {
                    if (status === Image.Ready) {
                        checkAndSwapBuffer(2)
                    } else if (status === Image.Error) {
                        var frameMatch = buffer2SourceA.match(/F(\d{4})\.jpg/)
                        var frameNum = frameMatch ? frameMatch[1] : "unknown"
                        var errorMsg = "Image file not found: Frame " + frameNum + " (Version A)\n\nPath: " + buffer2SourceA.replace(/file:\/\/\//g, "")
                        showImageError(errorMsg)
                    }
                }
            }
        }

        Item{
            id: buffer2ImageHoldB
            anchors.fill: parent
            opacity: 0
            Image {
                id: buffer2ImageB
                anchors.fill: parent
                source: buffer2SourceB
                // No sourceSize - let QML load full image directly (fastest path)
                fillMode: Image.PreserveAspectFit
                asynchronous: false  // Synchronous for immediate display during scrubbing
                cache: false  // Disable cache - we're loading directly from disk each time
                
                onStatusChanged: {
                    if (status === Image.Ready) {
                        checkAndSwapBuffer(2)
                    } else if (status === Image.Error) {
                        var frameMatch = buffer2SourceA.match(/F(\d{4})\.jpg/)
                        var frameNum = frameMatch ? frameMatch[1] : "unknown"
                        var errorMsg = "Image file not found: Frame " + frameNum + " (Version A)\n\nPath: " + buffer2SourceA.replace(/file:\/\/\//g, "")
                        showImageError(errorMsg)
                    }
                }
            }
        }

        Image {
            id: buffer2Mask
            anchors.fill: parent
            opacity: opacityValue
            source: buffer2SourceD
            // No sourceSize - let QML load full image directly (fastest path)
            fillMode: Image.PreserveAspectFit
            asynchronous: false  // Synchronous for immediate display during scrubbing
            cache: false  // Disable cache - we're loading directly from disk each time
            
            onStatusChanged: {
                if (status === Image.Ready) {
                    checkAndSwapBuffer(2)
                } else if (status === Image.Error) {
                    var frameMatch = buffer2SourceD.match(/F(\d{4})\.png/)
                    var frameNum = frameMatch ? frameMatch[1] : "unknown"
                    var errorMsg = "Alpha mask not found: Frame " + frameNum + "\n\nPath: " + buffer2SourceD.replace(/file:\/\/\//g, "")
                    showImageError(errorMsg)
                }
            }
        }

        OpacityMask{
            id: buffer2OpacityMask
            anchors.fill: parent
            source: buffer2ImageHoldA.opacity === 1 ? buffer2ImageA : buffer2ImageB
            maskSource: buffer2Mask
            visible: frontBuffer === 2
        }

        HueSaturation {
            id: buffer2HueSaturation
            anchors.fill: parent
            source: buffer2Mask
            hue: hueValue
            saturation: saturationValue
            lightness: lightnessValue
            opacity: opacityValue
            visible: frontBuffer === 2
        }
    }
}
