/**
 * @file TheSwipeView.qml
 * @brief Main navigation component managing the three-page swipe view
 * 
 * This component implements the main navigation system for the application,
 * managing three distinct pages:
 * - Page 0 (TopLayout_zero): Table view for event selection
 * - Page 1 (TopLayout_three): 3-window side-by-side comparison
 * - Page 2 (TopLayout_one): Single large window view
 * 
 * Features:
 * - Swipe navigation between pages
 * - Page index buttons for direct navigation
 * - Shared chart component across pages 1 and 2
 * - InfoHeader components for displaying event metadata
 * - Image path management for all image types
 * - FreeDView version name management
 * 
 * The component coordinates communication between pages and manages
 * shared resources like the timeline chart.
 */

import QtQuick 2.6
import QtQuick.Controls 2.0
import Constants 1.0
import Theme 1.0
import Logger 1.0


Rectangle {
    id: swipeViewComponent_id
    anchors.fill: parent
    property string pathImageA
    property string pathImageB
    property string pathImageC
    property string pathImageD
    property string origFreeDViewName
    property string testFreeDViewName
    property var mainItemRef: null  // Reference to main.qml for accessing showError function

    property string infoHeader_id
    property string infoHeader_eventName
    property string infoHeader_sportType
    property string infoHeader_stadiumName
    property int infoHeader_numberOfFrames
    property real infoHeader_minVal
    property string infoHeader_frameUnderThreshold
    property int infoHeader_filteredPointCount: 0
    /**
     * @brief Set tooltip text for both InfoHeader components
     * 
     * Updates tooltip text in both InfoHeader instances (one for page 2, one for page 3)
     * since they share the same chart component and need synchronized tooltips.
     * 
     * @param text - Tooltip text to display
     */
    function setInfoHeaderTooltip(text) {
        // Update both InfoHeaders since chart is shared
        if (infoHeaderFirst_id) {
            infoHeaderFirst_id.setTooltip(text)
        }
        if (infoHeaderSecond_id) {
            infoHeaderSecond_id.setTooltip(text)
        }
    }
    
    /**
     * @brief Clear tooltip text for both InfoHeader components
     * 
     * Clears tooltip text in both InfoHeader instances to keep them synchronized.
     */
    function clearInfoHeaderTooltip() {
        // Clear both InfoHeaders
        if (infoHeaderFirst_id) {
            infoHeaderFirst_id.clearTooltip()
        }
        if (infoHeaderSecond_id) {
            infoHeaderSecond_id.clearTooltip()
        }
    }


    /**
     * @brief Initialize image views when a new event set is selected
     * 
     * Called when user selects an event set from the table. Initializes both
     * the 3-window view (TopLayout_three) and single-window view (TopLayout_one)
     * with the new image paths and frame range.
     * 
     * @param startFrame - First frame number in sequence (0-indexed)
     * @param endFrame - Last frame number in sequence (0-indexed)
     * @param pathImageA - Base path for original images (type A)
     * @param pathImageB - Base path for test images (type B)
     * @param pathImageC - Base path for difference images (type C)
     * @param pathImageD - Base path for alpha/mask images (type D)
     */
    function startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD){
        Logger.info("[UI] Initializing image views: frames " + startFrame + "-" + endFrame)
        
        // Update properties so bindings work correctly
        swipeViewComponent_id.pathImageA = pathImageA
        swipeViewComponent_id.pathImageB = pathImageB
        swipeViewComponent_id.pathImageC = pathImageC
        swipeViewComponent_id.pathImageD = pathImageD
        
        // Pass paths to child components
        threeItems_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
        oneItems_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
    }



    /**
     * @brief Update InfoHeader with event information
     * 
     * Called from TopLayout_zero when an event set is selected to update
     * the InfoHeader components on pages 2 and 3 with event metadata.
     * 
     * @param id_val - Event ID
     * @param eventName - Event name
     * @param sportType - Sport type
     * @param stadiumName - Stadium name
     * @param numberOfFrames - Total number of frames in sequence
     * @param minVal - Minimum frame value
     * @param frameUnderThreshold - Threshold value for filtering
     */
    function infoHeader(id_val, eventName, sportType, stadiumName, numberOfFrames,  minVal, frameUnderThreshold)
    {
        infoHeader_id = id_val
        infoHeader_eventName = eventName
        infoHeader_sportType = sportType
        infoHeader_stadiumName = stadiumName
        infoHeader_numberOfFrames = numberOfFrames
        infoHeader_minVal = minVal
        infoHeader_frameUnderThreshold = frameUnderThreshold
        infoHeader_minVal = minVal.toString()
    }


    property string frameIndexValue: "0001"
    
    SwipeView {
        id: swipeView_id
        anchors.fill: parent
        currentIndex: 0
        
        // When page changes, update the newly visible page to current frame
        onCurrentIndexChanged: {
            var pageNames = ["Table View", "3-Window View", "Single Window View"]
            Logger.info("[UI] Page changed to: " + (currentIndex >= 0 && currentIndex < pageNames.length ? pageNames[currentIndex] : "Unknown (" + currentIndex + ")"))
            
            if (currentIndex === Constants.pageThreeWindow) {
                // Switched to page 2 (3 windows) - update it to current frame
                threeItems_Id.indexUpdate(swipeViewComponent_id.frameIndexValue)
            } else if (currentIndex === Constants.pageSingleWindow) {
                // Switched to page 3 (1 large window) - update it to current frame
                oneItems_Id.indexUpdate(swipeViewComponent_id.frameIndexValue)
            }
        }

        Item {
            id: zeroPage_id
            TopLayout_zero{
                id: zeroItems_id
                focus: true
                mainItem: typeof mainItemRef !== "undefined" ? mainItemRef : null  // Pass mainItem reference from TheSwipeView
            }
        }

        Item {
            id: firstPage_id
            InfoHeader{id:infoHeaderFirst_id
                id_val:infoHeader_id
                eventName_val:infoHeader_eventName
                sportType_val: infoHeader_sportType
                stadiumName_val:infoHeader_stadiumName
                numberOfFrames_val: infoHeader_numberOfFrames
                minVal_val: infoHeader_minVal
                frameUnderThreshold:infoHeader_frameUnderThreshold
                filteredPointCount_val: infoHeader_filteredPointCount
                mainItemRef: typeof mainItem !== "undefined" ? mainItem : null
            }

            TopLayout_three{id:threeItems_Id
                imagePathA: pathImageA
                imagePathB: pathImageB
                imagePathC: pathImageC
                imagePathD: pathImageD
                mainItemRef: typeof mainItem !== "undefined" ? mainItem : null
                // frameIndex binding removed - only updated via indexUpdate() function call
            }
        }

        Item {
            id: secondPage_id
            InfoHeader{id:infoHeaderSecond_id
                id_val:infoHeader_id
                eventName_val:infoHeader_eventName
                sportType_val: infoHeader_sportType
                stadiumName_val:infoHeader_stadiumName
                numberOfFrames_val: infoHeader_numberOfFrames
                minVal_val: infoHeader_minVal
                frameUnderThreshold:infoHeader_frameUnderThreshold
                filteredPointCount_val: infoHeader_filteredPointCount
                mainItemRef: typeof mainItem !== "undefined" ? mainItem : null
                isPage3: true  // This InfoHeader is for page 3
            }

            TopLayout_one{
                id:oneItems_Id
                imagePathA: pathImageA
                imagePathB: pathImageB
                imagePathC: pathImageC
                imagePathD: pathImageD
                mainItemRef: typeof mainItem !== "undefined" ? mainItem : null
                // frameIndex binding removed - only updated via indexUpdate() function call
            }
        }
    }


    PageIndicator {
        id: indicator_id
        count: swipeView_id.count
        currentIndex: swipeView_id.currentIndex
        interactive: true
        anchors.bottom: swipeView_id.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        delegate: Rectangle {
            implicitWidth: 10
            implicitHeight: 10
            radius: width
            color: Theme.primaryAccent
            opacity: index === swipeView_id.currentIndex ? 0.95 : pressed ? 0.7 : 0.4
            Behavior on opacity {
                OpacityAnimator {
                    duration: 200
                }
            }

        }
    }

    /**
     * @brief Navigate between SwipeView pages
     * 
     * Changes the active page in the SwipeView. Accepts both absolute page numbers
     * and relative navigation (+1 for next, -1 for previous).
     * 
     * Pages are clamped to valid range [0, 2]:
     * - 0: Table view (event selection)
     * - 1: 3-window comparison view
     * - 2: Single large window view
     * 
     * @param pageIndex - Target page index (absolute) or relative change (+1/-1)
     */
    function changePageIndex(pageIndex)
    {
        // Input validation: Check for null, undefined, or invalid types
        if (pageIndex === undefined || pageIndex === null || typeof pageIndex !== "number") {
            return  // Invalid input - exit early
        }
        
        // Validate swipeView_id exists
        if (!swipeView_id) {
            return  // Component not ready - exit early
        }
        
        var oldIndex = swipeView_id.currentIndex
        
        // Clamp current index to valid range [0, 2]
        if (swipeView_id.currentIndex <= 0){swipeView_id.currentIndex  = 0}
        if (swipeView_id.currentIndex >= 2){swipeView_id.currentIndex  = 2}
        swipeView_id.currentIndex = swipeView_id.currentIndex + pageIndex
        
        // Clamp result to valid range
        if (swipeView_id.currentIndex < 0) swipeView_id.currentIndex = 0
        if (swipeView_id.currentIndex > 2) swipeView_id.currentIndex = 2
        
        // Log page change (onCurrentIndexChanged will also log, but this logs the intent)
        if (swipeView_id.currentIndex !== oldIndex) {
            Logger.debug("[UI] Page index change requested: " + oldIndex + " + " + pageIndex + " = " + swipeView_id.currentIndex)
        }
    }


    /**
     * @brief Update frame index for currently visible page only
     * 
     * OPTIMIZATION: Only updates images on the currently visible SwipeView page
     * to avoid unnecessary image loading. This significantly improves performance
     * during timeline scrubbing.
     * 
     * Page mapping:
     * - Page 0 (index 0): Table view - no image updates
     * - Page 1 (index 1): 3-window view (A, B, C side-by-side)
     * - Page 2 (index 2): Single large window (D with A/B toggle)
     * 
     * The current frame index is stored so that when switching pages, the new
     * page can immediately display the correct frame.
     * 
     * @param frameIndex - 4-digit padded frame string (e.g., "0001", "0002")
     */
    function indexUpdate(frameIndex)
    {
        // Store current frame index for page switching
        swipeViewComponent_id.frameIndexValue = frameIndex
        
        // Page 1 (index 1) = 3 windows (TopLayout_three)
        // Page 2 (index 2) = 1 large window (TopLayout_one)
        if (swipeView_id.currentIndex === Constants.pageThreeWindow) {
            // On page 2 (3 windows) - only update page 2
            Logger.debug("[UI] Updating 3-window view to frame: " + frameIndex)
            threeItems_Id.indexUpdate(frameIndex)
        } else if (swipeView_id.currentIndex === Constants.pageSingleWindow) {
            // On page 3 (1 large window) - only update page 3
            Logger.debug("[UI] Updating single-window view to frame: " + frameIndex)
            oneItems_Id.indexUpdate(frameIndex)
        }
        // If on page 0 (table), don't update any images
    }

    /**
     * @brief Update FreeDView version names in image views
     * 
     * Updates the FreeDView version labels in both the 3-window view
     * and single-window view to show which versions are being compared.
     * 
     * @param origFreeDViewName - Original FreeDView version name
     * @param testFreeDViewName - Test FreeDView version name
     */
    function updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
    {
        Logger.debug("[UI] FreeDView names updated: " + origFreeDViewName + " vs " + testFreeDViewName)
        threeItems_Id.updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
        oneItems_Id.updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
    }

    /**
     * @brief Set minimum frame value threshold in InfoHeaders
     * 
     * Updates the threshold value in both InfoHeader components (pages 2 and 3)
     * which controls filtering of scatter points in the chart.
     * 
     * @param value - New threshold value (0.0 to 1.0)
     */
    function setMinFrameValue(value)
    {
        infoHeaderFirst_id.setMinFrameValue(value)
        infoHeaderSecond_id.setMinFrameValue(value)
    }


    /**
     * @brief Set minimum frame value in table view
     * 
     * Updates the threshold value in the table view (page 1) which is
     * used for filtering and display purposes.
     * 
     * @param value - New threshold value (0.0 to 1.0)
     */
    function setMinFrameValueFromListModel(value)
    {
        zeroItems_id.setMinFrameValue(value)
    }
    
    /**
     * @brief Update filtered point count in InfoHeader
     * 
     * Called when scatter points are filtered to update the display
     * showing how many points remain visible after filtering.
     * 
     * @param count - Number of points visible after filtering
     */
    function updateFilteredPointCount(count)
    {
        infoHeader_filteredPointCount = count
    }
}
