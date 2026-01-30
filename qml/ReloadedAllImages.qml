/**
 * @file ReloadedAllImages.qml
 * @brief Image management component implementing double-buffered image loading
 * 
 * This component manages image loading for a single image type (A, B, C, or D)
 * using double-buffering to prevent flicker during rapid frame scrubbing.
 * 
 * Features:
 * - Double-buffered image loading (loads new images into back buffer)
 * - Automatic buffer swapping when images are ready
 * - Frame tracking to prevent stale images from displaying
 * - Image effect controls (hue, saturation, lightness, opacity)
 * - Error handling for missing image files
 * 
 * The component creates ImageFileAB, ImageFileC, or ImageFileD components
 * based on the image type and manages their lifecycle.
 */

import QtQuick 2.0
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import "utils.js" as Utils

Item {
    id: container_Id
    anchors.fill: parent
    property string imagePathA
    property string imagePathB
    property string imagePathC
    property string imagePathD
    property string image_type
    property var object_list: []
    property var component
    property int startFrame: 0
    property int endFrame: 0


    /**
     * @brief Initialize image component when a new event set is selected
     * 
     * Creates and initializes the appropriate image component based on image_type:
     * - "imageA" or "imageB": Creates ImageFileAB component
     * - "imageC": Creates ImageFileC component (with HueSaturation effects)
     * - "imageD": Creates ImageFileD component (with A/B toggle and mask)
     * 
     * The function handles asynchronous component loading and destroys any
     * existing image objects before creating new ones.
     * 
     * @param startFrame - First frame number in sequence (0-indexed)
     * @param endFrame - Last frame number in sequence (0-indexed)
     * @param imagePathA - Base path for original images
     * @param imagePathB - Base path for test images
     * @param imagePathC - Base path for difference images
     * @param imagePathD - Base path for alpha/mask images
     */
    function startLoadAllImages(startFrame, endFrame, imagePathA, imagePathB, imagePathC, imagePathD){
        
        // Store frame range for preloading
        container_Id.startFrame = startFrame
        container_Id.endFrame = endFrame
        
        // Store base paths in component properties (function parameters shadow properties, so use explicit assignment)
        container_Id.imagePathA = imagePathA
        container_Id.imagePathB = imagePathB
        container_Id.imagePathC = imagePathC
        container_Id.imagePathD = imagePathD

        object_list = []

        //-- destroy old images -------------------
        if (object_list.length > 0)
        {
            object_list[0].destroy()
        }

        if (image_type === Utils.IMAGE_COMPONENT_C){
            component = Qt.createComponent("qrc:/qml/ImageFileC.qml")
        }
        else if (image_type === Utils.IMAGE_COMPONENT_D){
            component = Qt.createComponent("qrc:/qml/ImageFileD.qml")
        }
        else {
            // Default to ImageFileAB for imageA and imageB
            component = Qt.createComponent("qrc:/qml/ImageFileAB.qml")
        }
        
        // Wait for component to be ready (if asynchronous)
        if (component.status === Component.Loading) {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) {
                    createImageObject()
                } else if (component.status === Component.Error) {
                    // Component creation failed - silently fail (component will be null)
                }
            })
            return  // Will continue in callback
        } else if (component.status === Component.Error) {
            // Component creation failed - silently fail
            return
        }
        
        // Component is ready, create object immediately
        createImageObject()
    }
    
    /**
     * @brief Create the actual image object instance from the loaded component
     * 
     * Instantiates the image component with the appropriate properties based on
     * image_type. Uses ImageLoaderManager to get file paths formatted for QML.
     * 
     * Frame numbers are converted from 0-indexed (from startFrame) to 1-indexed
     * (for file naming: 0001.jpg, 0002.jpg, etc.)
     */
    function createImageObject() {
        
        if (!component || component.status !== Component.Ready) {
            // Component not ready - cannot create object
            return
        }
        
        // Check if imageLoaderManager is available
        if (typeof imageLoaderManager === "undefined" || !imageLoaderManager) {
            return
        }

        // Base paths are already stored in component properties from startLoadAllImages()
        // Use ImageLoaderManager to get formatted file paths

        // OPTIMIZATION: Use direct file paths instead of image provider
        // QML Image component loads directly from disk - faster than C++ provider
        // Get file paths from ImageLoaderManager (C++ only for path management)
        // startFrame is the actual frame number from the graph (e.g., 388, 389, etc.)
        // ImageLoaderManager expects 1-indexed frame numbers, and file names match actual frame numbers
        // So if startFrame is 388, the file is 0388.jpg - use startFrame directly
        var frameNum = startFrame
        
        // FALLBACK: If ImageLoaderManager paths are empty, construct paths directly from stored base paths
        // This handles the case where ImageLoaderManager isn't working correctly
        var useDirectPaths = false
        if (imageLoaderManager) {
            var testPath = imageLoaderManager.getImageFilePath("A", frameNum)
            if (!testPath || testPath.length === 0) {
                useDirectPaths = true
            }
        } else {
            useDirectPaths = true
        }
        
        var object = null
        var imageSource = ""
        
        // Helper function to construct file path directly
        function constructImagePath(basePath, frameNum, extension) {
            if (!basePath) return ""
            // Format frame number as 4-digit zero-padded string
            var frameStr = ("0000" + String(frameNum)).slice(-4)
            // Ensure basePath has trailing slash
            var path = basePath
            if (!path.endsWith("/") && !path.endsWith("\\")) {
                path = path + "/"
            }
            // Construct full path and convert to QML format
            var fullPath = path + frameStr + extension
            // Convert to QML file:/// format
            return "file:///" + fullPath.replace(/\\/g, "/")
        }
        
        if (image_type === Utils.IMAGE_COMPONENT_A){
            if (useDirectPaths) {
                imageSource = constructImagePath(container_Id.imagePathA, frameNum, ".jpg")
            } else {
                imageSource = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ORIG, frameNum)
            }
            if (imageSource) {
                object = component.createObject(container_Id, {pathImage: imageSource, imageType:image_type})
            }
        }
        else if (image_type === Utils.IMAGE_COMPONENT_B){
            if (useDirectPaths) {
                imageSource = constructImagePath(container_Id.imagePathB, frameNum, ".jpg")
            } else {
                imageSource = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_TEST, frameNum)
            }
            if (imageSource) {
                object = component.createObject(container_Id, {pathImage: imageSource, imageType:image_type})
            }
        }
        else if (image_type === Utils.IMAGE_COMPONENT_C){
            if (useDirectPaths) {
                imageSource = constructImagePath(container_Id.imagePathC, frameNum, ".jpg")
            } else {
                imageSource = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_DIFF, frameNum)
            }
            if (imageSource) {
                object = component.createObject(container_Id, {pathImage: imageSource});
            }
        }
        else if (image_type === Utils.IMAGE_COMPONENT_D){
            var imageSourceA, imageSourceB, imageSourceD
            if (useDirectPaths) {
                imageSourceA = constructImagePath(container_Id.imagePathA, frameNum, ".jpg")
                imageSourceB = constructImagePath(container_Id.imagePathB, frameNum, ".jpg")
                imageSourceD = constructImagePath(container_Id.imagePathD, frameNum, ".png")
            } else {
                imageSourceA = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ORIG, frameNum)
                imageSourceB = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_TEST, frameNum)
                imageSourceD = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ALPHA, frameNum)
            }
            if (imageSourceA && imageSourceB && imageSourceD) {
                object = component.createObject(container_Id, {imagePathA: imageSourceA, imagePathB: imageSourceB, imagePathD: imageSourceD});
            }
        }

        if (object) {
            object_list.push(object)
        }
        // If object creation failed, object_list remains empty and indexUpdate will skip
    }

    /**
     * @brief Update frame index for the image component
     * 
     * Called when user scrubs the timeline. Converts the 0-indexed frame string
     * to a 1-indexed frame number and retrieves the appropriate file path from
     * ImageLoaderManager, then updates the image component.
     * 
     * For imageD type, this function passes all three paths (A, B, D) since
     * that component needs to handle A/B switching.
     * 
     * @param frameIndex - 4-digit padded frame string (0-indexed, e.g., "0000", "0001")
     */
    function indexUpdate(frameIndex)
    {
        // Check if object_list has a valid object
        // If not, try to create it now (might have failed earlier or component wasn't ready)
        if (!object_list || object_list.length === 0 || !object_list[0]) {
            // Try to create the object if component is ready
            if (component && component.status === Component.Ready) {
                createImageObject()
            }
            // If still no object, skip update
            if (!object_list || object_list.length === 0 || !object_list[0]) {
                return
            }
        }
        
        // frameIndex is a padded string like "0388" from changeIndex (actual frame number)
        // Parse it as-is (it's already the actual frame number for file naming)
        var frameNum = Utils.parseFrameNumber(frameIndex, false)  // frameIndex is the actual frame number
        
        // Validate frame number is within valid range (startFrame to endFrame are graph frame numbers)
        // frameNum is the actual frame number (e.g., 388, 389, etc.)
        if (frameNum < container_Id.startFrame || frameNum > container_Id.endFrame) {
            // Frame is out of bounds, skip loading to prevent errors
            return
        }
        var frameIndex_path
        if (image_type === Utils.IMAGE_COMPONENT_A){
            frameIndex_path = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ORIG, frameNum)
            if (object_list[0] && typeof object_list[0].indexUpdate === "function") {
                object_list[0].indexUpdate(frameIndex_path)
            }
        }

        if (image_type === Utils.IMAGE_COMPONENT_B){
            frameIndex_path = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_TEST, frameNum)
            if (object_list[0] && typeof object_list[0].indexUpdate === "function") {
                object_list[0].indexUpdate(frameIndex_path)
            }
        }

        if (image_type === Utils.IMAGE_COMPONENT_C){
            frameIndex_path = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_DIFF, frameNum)
            if (object_list[0] && typeof object_list[0].indexUpdate === "function") {
                object_list[0].indexUpdate(frameIndex_path)
            }
        }

        if (image_type === Utils.IMAGE_COMPONENT_D){
            var imagePathA = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ORIG, frameNum)
            var imagePathB = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_TEST, frameNum)
            var imagePathD = imageLoaderManager.getImageFilePath(Utils.IMAGE_TYPE_ALPHA, frameNum)
            if (object_list[0] && typeof object_list[0].indexUpdate === "function") {
                object_list[0].indexUpdate(imagePathA, imagePathB, imagePathD)
            }
        }
    }


    //--- Image Switch -----------------
    function imageSwitchOnTypeD(){
        for (var i = 0; i < object_list.length; i++){
            object_list[i].imageSwitc()

        }
    }

    //--- hue slider -----------------
    function hueSlider(val){
        for (var i = 0; i < object_list.length; i++){
            object_list[i].sliderUpdateHue(val)
        }
    }

    //--- light slider -----------------
    function lightSlider(val){
        for (var i = 0; i < object_list.length; i++){
            object_list[i].sliderUpdateLight(val)
        }
    }

    //--- saturation slider -----------------
    function saturationSlider(val){
        for (var i = 0; i < object_list.length; i++){
            object_list[i].sliderUpdateSat(val)
        }
    }

    //--- opacity slider -----------------
    function opacitySlider(val){
        for (var i = 0; i < object_list.length; i++){
            object_list[i].sliderUpdateOpacity(val)
        }
    }

}
