/**
 * @file TopLayout_one.qml
 * @brief Page 2: Single large window view with A/B toggle
 * 
 * This component displays a single large ImageItem for detailed inspection.
 * The view shows the alpha mask (imageD) with the ability to toggle between
 * showing the original (imageA) or test (imageB) render underneath.
 * 
 * Features:
 * - Large single-window view for detailed inspection
 * - Toggle between original and test renders (click text to switch)
 * - FreeDView version labels
 * - Full zoom and pan capabilities
 * - Image effect controls (hue, saturation, lightness, opacity)
 * - Smooth frame scrubbing with double-buffered image loading
 * 
 * This is page 2 (index 2) in the application's swipe view navigation.
 */

import QtQuick 2.4
import QtQuick.Layouts 1.3
import QtQuick.Controls 1.2
import Theme 1.0


Rectangle {
    id: imageOne_id
    anchors.top: parent.top
    anchors.topMargin: 84  // Align with table header start position (34 topMargin + 50 toolbar)
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    border.width: 5
    radius: 15

    property int frameIndex
    property string imagePathA
    property string imagePathB
    property string imagePathC
    property string imagePathD
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
    property string origFreeDViewName
    property string testFreeDViewName
    property int  changeFreeDViewVer_case:0
    property var mainItemRef: null

    //-- update thr frame index --------------------------------
    function indexUpdate(frameIndex){
        imageD_Id.indexUpdate(frameIndex)
    }

    //-- update the "origFreeDViewName" and the "testFreeDViewName" ----
    function updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
    {
        // Handle undefined/null values - convert to empty string for string properties
        // Note: Parameters are intentionally swapped for this component
        // Use 'this.' to explicitly reference component properties and avoid parameter shadowing
        this.origFreeDViewName = (testFreeDViewName !== undefined && testFreeDViewName !== null) ? String(testFreeDViewName) : ""
        this.testFreeDViewName = (origFreeDViewName !== undefined && origFreeDViewName !== null) ? String(origFreeDViewName) : ""
        // Reset to show test version initially (changeFreeDViewVer_case = 0)
        this.changeFreeDViewVer_case = 0
        // Don't set imageDText_Id.text directly - let the binding handle it
    }

    /**
     * @brief Initialize image view when a new event set is selected
     * 
     * Called when user selects an event set from the table. Initializes the
     * single-window view with new image paths and frame range.
     * 
     * @param startFrame - First frame number in sequence (0-indexed)
     * @param endFrame - Last frame number in sequence (0-indexed)
     * @param pathImageA - Base path for original images (type A)
     * @param pathImageB - Base path for test images (type B)
     * @param pathImageC - Base path for difference images (type C)
     * @param pathImageD - Base path for alpha/mask images (type D)
     */
    function startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD){
        imageD_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
    }

    /**
     * @brief Toggle between original and test FreeDView version display
     * 
     * Switches the displayed version name text between original and test
     * FreeDView versions. This is a visual indicator for which version
     * is currently being shown in the image.
     */
    function changeFreeDViewVer_text() {
        // Toggle between original and test FreeDView version
        // The Text element's binding will automatically update when changeFreeDViewVer_case changes
        // Use 'this.' to explicitly reference component property
        if (this.changeFreeDViewVer_case === 0)
        {
            this.changeFreeDViewVer_case = 1
        }
        else if (this.changeFreeDViewVer_case === 1)
        {
            this.changeFreeDViewVer_case = 0
        }
    }

    Item{
        id:holdSplitFrame_Id
        anchors.fill: parent
        clip : true
        Rectangle {
            anchors.fill: parent
            ImageItem{id:imageD_Id;
                imagePathA: imagePathA
                imagePathB: imagePathB
                imagePathC: imagePathC
                imagePathD: imagePathD
                imageType: "imageD"
                val_m_x1: imageThree_m_x1;
                val_m_y1: imageThree_m_y1;
                val_m_y2: imageThree_m_y2;
                val_m_x2: imageThree_m_x2;
                val_m_zoom1: imageThree_m_zoom1;
                val_m_zoom2: imageThree_m_zoom2;
                val_m_max: imageThree_m_max;
                val_m_min: imageThree_m_min;
                mainItemRef: imageOne_id.mainItemRef
            }
        }

        Text{
            id:imageDText_Id
            // Use changeFreeDViewVer_case to determine which version to show
            // This binding will automatically update when changeFreeDViewVer_case changes
            text: imageOne_id.changeFreeDViewVer_case === 0 ? imageOne_id.testFreeDViewName : imageOne_id.origFreeDViewName
            font.family: "Helvetica"
            font.pointSize: Theme.fontSizeMedium
            x:24
            y:64
            color: Theme.primaryAccent  // Light green matching UI theme
            z: 10  // Ensure text is above other elements
        }
        
        // MouseArea for tooltip when hovering over render version text (page 3 only)
        // Must be a sibling of Text, positioned above parent MouseArea
        MouseArea {
            x: imageDText_Id.x
            y: imageDText_Id.y
            width: imageDText_Id.implicitWidth || imageDText_Id.contentWidth || 200
            height: imageDText_Id.implicitHeight || imageDText_Id.contentHeight || 20
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with any interactions
            propagateComposedEvents: true
            z: 20  // Higher z-order than parent MouseArea to receive events first
            onEntered: {
                if (imageOne_id.mainItemRef && typeof imageOne_id.mainItemRef.setTooltip === "function") {
                    imageOne_id.mainItemRef.setTooltip("Pressing the middle button switches the render test version")
                }
            }
            onExited: {
                if (imageOne_id.mainItemRef && typeof imageOne_id.mainItemRef.clearTooltip === "function") {
                    imageOne_id.mainItemRef.clearTooltip()
                }
            }
        }
        
        // MouseArea to show tooltip when hovering over the central image window
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with image interactions
            propagateComposedEvents: true
            z: -1  // Put it behind ImageItem so it doesn't block hover events
            onEntered: {
                // Don't show tooltip if mouse is over the text area
                if (imageOne_id.mainItemRef && typeof imageOne_id.mainItemRef.setTooltip === "function") {
                    imageOne_id.mainItemRef.setTooltip("Middle scroll of the mouse to zoom and left and drag to move (left click to reset zoom)")
                }
            }
            onExited: {
                if (imageOne_id.mainItemRef && typeof imageOne_id.mainItemRef.clearTooltip === "function") {
                    imageOne_id.mainItemRef.clearTooltip()
                }
            }
        }
    }
}

