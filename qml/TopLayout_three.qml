/**
 * @file TopLayout_three.qml
 * @brief Page 1: Three-window side-by-side image comparison view
 * 
 * This component displays three ImageItem components side-by-side for comparing:
 * - Window A: Original/expected render (imageA)
 * - Window B: Test/actual render (imageB)
 * - Window C: Difference visualization (imageC)
 * 
 * Features:
 * - Synchronized zoom and pan across all three windows
 * - Synchronized image marks (crosshairs) for precise comparison
 * - FreeDView version labels showing which versions are being compared
 * - Individual image effect controls (hue, saturation, lightness) for each window
 * - Smooth frame scrubbing with double-buffered image loading
 * 
 * This is page 1 (index 1) in the application's swipe view navigation.
 */

import QtQuick 2.0
import QtQuick.Layouts 1.3
import "utils.js" as Utils
import Theme 1.0

Rectangle {
    id: imageThree_id
    anchors.top: parent.top
    anchors.topMargin: 84  // Align with table header start position (34 topMargin + 50 toolbar)
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    color: Theme.primaryDark
    border.width: 10
    border.color: Theme.borderDark
    radius: 15

    property int frameIndex
    property string imagePathA
    property string imagePathB
    property string imagePathC
    property string imagePathD
    property string origFreeDViewName
    property string testFreeDViewName
    property var mainItemRef: null

    property real imageThree_m_x1: 0
    property real imageThree_m_y1: 0
    property real imageThree_m_y2: 0
    property real imageThree_m_x2: 0
    property real imageThree_m_zoom1: 0.5
    property real imageThree_m_zoom2: 1
    property real imageThree_m_max: 8
    property real imageThree_m_min: 0.8
    property real imageThree_xMouse: 0
    property real imageThree_yMouse: 0

    /**
     * @brief Update FreeDView version names in 3-window view
     * 
     * Updates the FreeDView version labels displayed in the 3-window comparison view.
     * These labels help users identify which versions are being compared.
     * 
     * @param origFreeDViewName - Original FreeDView version name
     * @param testFreeDViewName - Test FreeDView version name
     */
    function updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
    {
        // Handle undefined/null values - convert to empty string for string properties
        // Use explicit property assignment to avoid parameter shadowing
        imageThree_id.origFreeDViewName = (origFreeDViewName !== undefined && origFreeDViewName !== null) ? String(origFreeDViewName) : ""
        imageThree_id.testFreeDViewName = (testFreeDViewName !== undefined && testFreeDViewName !== null) ? String(testFreeDViewName) : ""
    }

    /**
     * @brief Update frame index for all three image windows
     * 
     * Called when user scrubs the timeline. Updates all three image displays
     * (A, B, C) to show the same frame simultaneously.
     * 
     * @param frameIndex - 4-digit padded frame string (e.g., "0001", "0002")
     */
    function indexUpdate(frameIndex){
        imageA_Id.indexUpdate(frameIndex)
        imageB_Id.indexUpdate(frameIndex)
        imageC_Id.indexUpdate(frameIndex)
    }

    /**
     * @brief Synchronize pan position across all three images
     * 
     * When user drags one image, this function synchronizes the pan position
     * to the other two images. This ensures all three images stay aligned
     * when panning, making comparison easier.
     * 
     * The function unlocks anchors on the other images before updating position,
     * allowing them to move independently.
     * 
     * @param imageType - Which image was moved (IMAGE_COMPONENT_A, IMAGE_COMPONENT_B, or IMAGE_COMPONENT_C)
     * @param x_changed - New X position
     * @param y_changed - New Y position
     */
    function updateMouseMoveVal(imageType, x_changed, y_changed){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.undefinedAnchors()
            imageB_Id.setImageMove(x_changed, y_changed)
            imageC_Id.undefinedAnchors()
            imageC_Id.setImageMove(x_changed, y_changed)
        }
        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.undefinedAnchors()
            imageA_Id.setImageMove(x_changed, y_changed)
            imageC_Id.undefinedAnchors()
            imageC_Id.setImageMove(x_changed, y_changed)
        }
        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.undefinedAnchors()
            imageA_Id.setImageMove(x_changed, y_changed)
            imageB_Id.undefinedAnchors()
            imageB_Id.setImageMove(x_changed, y_changed)
        }
    }

    /**
     * @brief Synchronize zoom parameters across all three images
     * 
     * When user zooms one image (via mouse wheel or pinch), this function
     * synchronizes all zoom parameters to the other two images. This ensures
     * all three images maintain the same zoom level and zoom center point,
     * making side-by-side comparison accurate.
     * 
     * Parameters synchronized:
     * - m_x1, m_y1: Zoom origin point (where zoom started)
     * - m_x2, m_y2: Current zoom center point
     * - m_zoom1: Previous zoom level
     * - m_zoom2: Current zoom level
     * - m_max, m_min: Zoom limits
     * 
     * @param imageType - Which image was zoomed ("imageA", "imageB", or "imageC")
     * @param m_x1 - Zoom origin X coordinate
     * @param m_y1 - Zoom origin Y coordinate
     * @param m_y2 - Current zoom center Y coordinate
     * @param m_x2 - Current zoom center X coordinate
     * @param m_zoom1 - Previous zoom level
     * @param m_zoom2 - Current zoom level
     * @param m_max - Maximum zoom level
     * @param m_min - Minimum zoom level
     */
    function updateZoomVal(imageType, m_x1, m_y1, m_y2, m_x2, m_zoom1, m_zoom2, m_max, m_min){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.undefinedAnchors()
            imageB_Id.m_x1 = m_x1
            imageB_Id.m_y1 = m_y1
            imageB_Id.m_x2 = m_x2
            imageB_Id.m_y2 = m_y2
            imageB_Id.m_zoom1 = m_zoom1
            imageB_Id.m_zoom2 = m_zoom2
            imageB_Id.m_min = m_min
            imageB_Id.m_max = m_max

            imageC_Id.undefinedAnchors()
            imageC_Id.m_x1 = m_x1
            imageC_Id.m_y1 = m_y1
            imageC_Id.m_x2 = m_x2
            imageC_Id.m_y2 = m_y2
            imageC_Id.m_zoom1 = m_zoom1
            imageC_Id.m_zoom2 = m_zoom2
            imageC_Id.m_min = m_min
            imageC_Id.m_max = m_max
        }

        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.undefinedAnchors()
            imageA_Id.m_x1 = m_x1
            imageA_Id.m_y1 = m_y1
            imageA_Id.m_x2 = m_x2
            imageA_Id.m_y2 = m_y2
            imageA_Id.m_zoom1 = m_zoom1
            imageA_Id.m_zoom2 = m_zoom2
            imageA_Id.m_min = m_min
            imageA_Id.m_max = m_max

            imageC_Id.undefinedAnchors()
            imageC_Id.m_x1 = m_x1
            imageC_Id.m_y1 = m_y1
            imageC_Id.m_x2 = m_x2
            imageC_Id.m_y2 = m_y2
            imageC_Id.m_zoom1 = m_zoom1
            imageC_Id.m_zoom2 = m_zoom2
            imageC_Id.m_min = m_min
            imageC_Id.m_max = m_max
        }

        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.undefinedAnchors()
            imageA_Id.m_x1 = m_x1
            imageA_Id.m_y1 = m_y1
            imageA_Id.m_x2 = m_x2
            imageA_Id.m_y2 = m_y2
            imageA_Id.m_zoom1 = m_zoom1
            imageA_Id.m_zoom2 = m_zoom2
            imageA_Id.m_min = m_min
            imageA_Id.m_max = m_max

            imageB_Id.undefinedAnchors()
            imageB_Id.m_x1 = m_x1
            imageB_Id.m_y1 = m_y1
            imageB_Id.m_x2 = m_x2
            imageB_Id.m_y2 = m_y2
            imageB_Id.m_zoom1 = m_zoom1
            imageB_Id.m_zoom2 = m_zoom2
            imageB_Id.m_min = m_min
            imageB_Id.m_max = m_max
        }
    }

    /**
     * @brief Reset zoom and re-lock anchors for all three images
     * 
     * Called after zoom reset animation completes. Resets all three images
     * to 1:1 zoom and locks them back to their default positions.
     */
    function dfinedAnchorsAndRsetZoom(){
        imageA_Id.resetZoomAndReDfinedAnchors()
        imageB_Id.resetZoomAndReDfinedAnchors()
        imageC_Id.resetZoomAndReDfinedAnchors()
    }

    /**
     * @brief Start reset zoom animation on other images
     * 
     * When one image starts a reset zoom animation, this function triggers
     * the same animation on the other two images for synchronized behavior.
     * 
     * @param imageType - Which image started the animation (IMAGE_COMPONENT_A, IMAGE_COMPONENT_B, or IMAGE_COMPONENT_C)
     */
    function resetZoomAnim(imageType){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.resetZoomAnim()
            imageC_Id.resetZoomAnim()}

        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.resetZoomAnim()
            imageC_Id.resetZoomAnim()
        }
        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.resetZoomAnim(
                        imageB_Id.resetZoomAnim())
        }
    }

    /**
     * @brief Synchronize image mark visibility across all three images
     * 
     * When user toggles image marks (crosshairs/overlays) on one image,
     * this function synchronizes the visibility to the other two images.
     * 
     * @param imageType - Which image was toggled (IMAGE_COMPONENT_A, IMAGE_COMPONENT_B, or IMAGE_COMPONENT_C)
     * @param val - Visibility state (true = visible, false = hidden)
     */
    function visibleImageMark(imageType, val){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.setVisibleImageMark(val)
            imageC_Id.setVisibleImageMark(val)}
        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.setVisibleImageMark(val)
            imageC_Id.setVisibleImageMark(val)}
        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.setVisibleImageMark(val)
            imageB_Id.setVisibleImageMark(val)}
    }
    /**
     * @brief Synchronize image mark X position across all three images
     * 
     * When user moves image marks horizontally on one image, this function
     * synchronizes the X position to the other two images.
     * 
     * @param imageType - Which image was moved (IMAGE_COMPONENT_A, IMAGE_COMPONENT_B, or IMAGE_COMPONENT_C)
     * @param val - New X position value
     */
    function moveImageMarkX(imageType, val){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.setMoveImageMarkX(val)
            imageC_Id.setMoveImageMarkX(val)}
        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.setMoveImageMarkX(val)
            imageC_Id.setMoveImageMarkX(val)}
        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.setMoveImageMarkX(val)
            imageB_Id.setMoveImageMarkX(val)}
    }

    /**
     * @brief Synchronize image mark Y position across all three images
     * 
     * When user moves image marks vertically on one image, this function
     * synchronizes the Y position to the other two images.
     * 
     * @param imageType - Which image was moved (IMAGE_COMPONENT_A, IMAGE_COMPONENT_B, or IMAGE_COMPONENT_C)
     * @param val - New Y position value
     */
    function moveImageMarkY(imageType, val){
        if (imageType === Utils.IMAGE_COMPONENT_A) {
            imageB_Id.setMoveImageMarkY(val)
            imageC_Id.setMoveImageMarkY(val)}
        if (imageType === Utils.IMAGE_COMPONENT_B) {
            imageA_Id.setMoveImageMarkY(val)
            imageC_Id.setMoveImageMarkY(val)}
        if (imageType === Utils.IMAGE_COMPONENT_C) {
            imageA_Id.setMoveImageMarkY(val)
            imageB_Id.setMoveImageMarkY(val)}
    }

    //-- load all the images fof page tree -----------------------------------
    function startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD){
        imageA_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
        imageB_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
        imageC_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
    }

    //****************************************************************
    GridLayout {
        id: gridId
        anchors.fill: parent
        columnSpacing:15

        //**** A **************************************
        Rectangle {
            id:imageItemA_Id
            Layout.preferredWidth: 400
            Layout.preferredHeight:gridId.implicitHeight
            Layout.fillHeight: true
            Layout.fillWidth: true

            Item {
                anchors.fill: parent
                clip : true
                ImageItem{id:imageA_Id
                    imagePathA: imagePathA
                    imagePathB: imagePathB
                    imagePathC: imagePathC
                    imagePathD: imagePathD
                    imageType: "imageA"
                    val_m_x1: imageThree_m_x1;
                    val_m_y1: imageThree_m_y1;
                    val_m_y2: imageThree_m_y2;
                    val_m_x2: imageThree_m_x2;
                    val_m_zoom1: imageThree_m_zoom1;
                    val_m_zoom2: imageThree_m_zoom2;
                    val_m_max: imageThree_m_max;
                    val_m_min: imageThree_m_min;
                    mainItemRef: imageThree_id.mainItemRef
                }
                // MouseArea to show tooltip when hovering over image panel A
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton  // Don't interfere with image interactions
                    propagateComposedEvents: true
                    z: -1  // Put it behind ImageItem so it doesn't block hover events
                    onEntered: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.setTooltip === "function") {
                            imageThree_id.mainItemRef.setTooltip("Middle mouse button to zoom and left and drag to move (press left to reset zoom)")
                        }
                    }
                    onExited: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.clearTooltip === "function") {
                            imageThree_id.mainItemRef.clearTooltip()
                        }
                    }
                }
            }
            // Text outside Item to avoid clipping, but inside Rectangle
            Text{
                id: textA_id
                text: imageThree_id.origFreeDViewName || "Original Version"  // Use explicit property path to avoid shadowing
                font.family: "Helvetica"
                font.pointSize: Theme.fontSizeMedium
                x: 24
                y: 64
                color: Theme.primaryAccent  // Light green matching UI theme
                z: 1000  // Very high z to ensure it's above everything
            }
        }

        //**** B **************************************
        Rectangle {
            id:imageItemB_Id
            Layout.preferredWidth: 400
            Layout.preferredHeight:gridId.implicitHeight
            Layout.fillHeight: true
            Layout.fillWidth: true

            Item{
                anchors.fill: parent
                clip : true
                ImageItem{id:imageB_Id
                    imagePathA: imagePathA
                    imagePathB: imagePathB
                    imagePathC: imagePathC
                    imagePathD: imagePathD
                    imageType: "imageB"
                    val_m_x1: imageThree_m_x1;
                    val_m_y1: imageThree_m_y1;
                    val_m_y2: imageThree_m_y2;
                    val_m_x2: imageThree_m_x2;
                    val_m_zoom1: imageThree_m_zoom1;
                    val_m_zoom2: imageThree_m_zoom2;
                    val_m_max: imageThree_m_max;
                    val_m_min: imageThree_m_min;
                    mainItemRef: imageThree_id.mainItemRef
                }
                // MouseArea to show tooltip when hovering over image panel B
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton  // Don't interfere with image interactions
                    propagateComposedEvents: true
                    z: -1  // Put it behind ImageItem so it doesn't block hover events
                    onEntered: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.setTooltip === "function") {
                            imageThree_id.mainItemRef.setTooltip("Middle mouse button to zoom and left and drag to move (press left to reset zoom)")
                        }
                    }
                    onExited: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.clearTooltip === "function") {
                            imageThree_id.mainItemRef.clearTooltip()
                        }
                    }
                }
            }
            // Text outside Item to avoid clipping, but inside Rectangle
            Text{
                id: textB_id
                text: imageThree_id.testFreeDViewName || "Test Version"  // Use explicit property path to avoid shadowing
                font.family: "Helvetica"
                font.pointSize: Theme.fontSizeMedium
                x: 24
                y: 64
                color: Theme.primaryAccent  // Light green matching UI theme
                z: 1000  // Very high z to ensure it's above everything
            }
        }


        //***** C *************************************
        Rectangle {
            id:imageItemC_Id
            Layout.preferredWidth: 400
            Layout.preferredHeight:gridId.implicitHeight
            Layout.fillHeight: true
            Layout.fillWidth: true

            Item{
                anchors.fill: parent
                clip : true
                ImageItem{id:imageC_Id;
                    imagePathA: imagePathA
                    imagePathB: imagePathB
                    imagePathC: imagePathC
                    imagePathD: imagePathD
                    imageType: "imageC"
                    val_m_x1: imageThree_m_x1;
                    val_m_y1: imageThree_m_y1;
                    val_m_y2: imageThree_m_y2;
                    val_m_x2: imageThree_m_x2;
                    val_m_zoom1: imageThree_m_zoom1;
                    val_m_zoom2: imageThree_m_zoom2;
                    val_m_max: imageThree_m_max;
                    val_m_min: imageThree_m_min;
                    mainItemRef: imageThree_id.mainItemRef
                }
                Text{
                    text:"Difference"
                    font.family: "Helvetica"
                    font.pointSize: Theme.fontSizeMedium
                    x:24
                    y:64
                    color: Theme.primaryAccent  // Light green matching UI theme
                }
                // MouseArea to show tooltip when hovering over Difference window
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton  // Don't interfere with right-click menu
                    propagateComposedEvents: true
                    z: -1  // Put it behind ImageItem so it doesn't block hover events
                    onEntered: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.setTooltip === "function") {
                            imageThree_id.mainItemRef.setTooltip("Right-click for menu")
                        }
                    }
                    onExited: {
                        if (imageThree_id.mainItemRef && typeof imageThree_id.mainItemRef.clearTooltip === "function") {
                            imageThree_id.mainItemRef.clearTooltip()
                        }
                    }
                }
            }

        }

    }

}
