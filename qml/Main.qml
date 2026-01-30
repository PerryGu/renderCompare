/**
 * @file Main.qml
 * @brief Main application entry point and root component
 * 
 * This is the root QML component that orchestrates the entire application.
 * It manages:
 * - Main application layout (SplitView with table, images, and chart)
 * - Component lifecycle and initialization
 * - Error handling and logging
 * - Communication between major components (table view, swipe view, chart)
 * - Global error dialog and log window management
 * 
 * The application uses a three-page swipe view:
 * - Page 0: Table view for event selection
 * - Page 1: 3-window comparison view (original, test, difference)
 * - Page 2: Single large window view (alpha mask with A/B toggle)
 */

import QtQuick 2.6
import QtQuick.Layouts 1.3
import QtQuick.Controls 1.4
import QtQuick.Controls 2.0
import "utils.js" as Utils
import Logger 1.0
import Theme 1.0
import Constants 1.0

Item {
    id: mainItem
    width: 1600
    height: 850
    property var swipeViewComponent
    property var chartComponent
    property var tableViewComponent  // Reference to Tableview component for tooltip updates
    property int frameIndexValue
    property int currentStartFrame: 0  // Store current startFrame for validation (graph frame numbers)
    property int currentEndFrame: 0    // Store current endFrame for validation (graph frame numbers)
    property int currentFrameCount: 0  // Store actual number of frames (for array index validation)
    property var currentChartListFrame: []  // Store chartList_frame for mapping array index to actual frame number

    property string sourcePath
    property string testPath
    property string diffPath
    property string alphaPath

    property int itemWidth: 180
    property int itemHeight: 80
    property int scaledMargin: 2
    property int fontSize: 20

    // Menu bar removed - log window is now accessible via button next to search field
    
    // Log window (separate window - created dynamically)
    property var logWindowInstance: null
    
    // Function to create/show the log window
    function createLogWindow() {
        if (!logWindowInstance) {
            var component = Qt.createComponent("qrc:/qml/LogWindow.qml")
                if (component.status === Component.Ready) {
                    logWindowInstance = component.createObject(null)  // null parent = separate window
                    if (!logWindowInstance) {
                        Logger.error("[Main] Failed to create LogWindow instance")
                    }
                } else if (component.status === Component.Error) {
                    Logger.error("[Main] Failed to load LogWindow component")
                    Logger.error("[Main] Error string: " + component.errorString())
                } else {
                    // Component is still loading, wait for it
                    component.statusChanged.connect(function() {
                        if (component.status === Component.Ready) {
                            logWindowInstance = component.createObject(null)
                        } else if (component.status === Component.Error) {
                            Logger.error("[Main] Failed to load LogWindow component")
                            Logger.error("[Main] Error string: " + component.errorString())
                        }
                    })
                }
        }
        return logWindowInstance
    }
    
    // Function to show/hide the log window
    function showLogWindow(visible) {
        var window = createLogWindow()
        if (window) {
            window.isVisible = visible
        }
    }

    //-- the SplitView ---------------------------
    SplitView{
        id:layoutId
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        orientation: Qt.Vertical

        Rectangle {
            id: swipeViewHold_id
            height: 550
            Layout.minimumHeight: 300
            Layout.maximumHeight: 1200
            Layout.fillWidth: true

            //-- create The SwipeView ------------------------------------------------
            Loader {
                id: swipeViewLoader
                anchors.fill: parent
                source: "qrc:/qml/TheSwipeView.qml"
                onLoaded: {
                    if (item) {
                        swipeViewComponent = item
                        // Pass mainItem reference so TheSwipeView can access showError function
                        item.mainItemRef = mainItem
                    }
                }
            }
        }

        //-- create The chart view  ------------------------------------------------
        Rectangle {
            id: chartHold_id
            height: 300
            Layout.minimumHeight: 100
            Layout.maximumHeight: 1200
            Layout.fillWidth: true
            anchors.bottom: parent.bottom

            Loader {
                id: chartLoader
                anchors.fill: parent
                source: "qrc:/qml/TimelineChart.qml"
                onLoaded: {
                    if (item) {
                        chartComponent = item
                        // Pass mainItem reference for tooltip access
                        if (item.chartHoldId) {
                            item.chartHoldId.mainItemRef = mainItem
                        }
                    }
                }
            }
        }
    }

    // Global error dialog for application-wide errors
    ErrorDialog {
        id: globalErrorDialog
        anchors.fill: parent
    }
    
    /**
     * @brief Show error message in global error dialog
     * 
     * Displays an error message to the user using the global ErrorDialog component.
     * Can be called from any child component to show application-wide errors.
     * 
     * @param errorMessage - Error message text to display (empty strings are ignored)
     */
    function showError(errorMessage) {
        if (errorMessage && errorMessage !== "") {
            globalErrorDialog.show(errorMessage)
            Logger.error(errorMessage)  // Also log the error
        }
    }

    // Connect to ImageLoaderManager error signals
    Connections {
        target: imageLoaderManager
        onErrorOccurred: function(errorMessage) {
            if (errorMessage && errorMessage !== "") {
                globalErrorDialog.show(errorMessage)
                Logger.error("ImageLoader: " + errorMessage)
            }
        }
    }

    // Connect to XmlDataModel error signals (for errors not handled by Tableview)
    Connections {
        target: xmlDataModel
        onErrorOccurred: function(errorMessage) {
            // Only show if not already handled by Tableview component
            // Tableview has its own error handling, so this is a fallback
            if (errorMessage && errorMessage !== "" && 
                (!tableViewComponent || typeof tableViewComponent.showError !== "function")) {
                globalErrorDialog.show(errorMessage)
                Logger.error("XmlDataModel: " + errorMessage)
            }
        }
    }
    
    // Initialize logging
    Component.onCompleted: {
        Logger.info("Application started")
        Logger.info(Constants.appNameWithVersion)
    }

    /**
     * @brief Update frame index when user scrubs the timeline slider
     * 
     * Called from the chart/timeline component when the user moves the slider.
     * Converts the 0-indexed slider value to a 4-digit padded frame string (e.g., "0001")
     * and updates all image views to display the corresponding frame.
     * 
     * @param val - Frame index from slider (0-indexed, e.g., 0, 1, 2...)
     */
    function changeIndex(val){
        // Input validation: Check for null, undefined, or invalid types
        if (val === undefined || val === null || typeof val !== "number") {
            return  // Invalid input - exit early
        }
        
        // val is the actual frame number (e.g., 388, 389, etc.), not an array index
        // Validate val is within valid frame range
        if (val < currentStartFrame || val > currentEndFrame) {
            // Frame is out of bounds, clamp to valid range
            if (val < currentStartFrame) {
                val = currentStartFrame
            } else if (val > currentEndFrame) {
                val = currentEndFrame
            }
        }
        
        // Validate components are available before calling
        if (!swipeViewComponent || typeof swipeViewComponent.indexUpdate !== "function") {
            return  // Component not ready - exit early
        }
        
        // Convert actual frame number to padded frame string for image loading
        // val is already the frame number (e.g., 388, 389, etc.)
        // formatFrameNumber with isZeroIndexed=false will pad it as-is (388 -> "0388")
        frameIndexValue = Utils.formatFrameNumber(val, false)  // val is already the frame number
        swipeViewComponent.indexUpdate(frameIndexValue)
        
        // Log frame change for debugging
        Logger.debug("[UI] Frame changed to: " + val + " (formatted: " + frameIndexValue + ")")
        
        // Performance optimization: Preload adjacent frames when scrubbing pauses
        // This is handled by the throttled preload timer in TimelineChart.qml
        // which triggers after user stops scrubbing for 200ms
    }

    /**
     * @brief Initialize a new project/event set for comparison
     * 
     * This is the main entry point when a user selects an event set from the table.
     * It sets up all image paths, initializes the image views, loads chart data,
     * and configures the FreeDView version names.
     * 
     * Process:
     * 1. Converts Windows paths to QML-compatible file:// URLs
     * 2. Updates ImageLoaderManager with new base paths
     * 3. Clears image cache to free memory
     * 4. Initializes all image views (3-window and single-window views)
     * 5. Loads chart data with frame values
     * 6. Sets initial slider position and highlights frames under threshold
     * 7. Updates FreeDView version labels
     * 
     * @param startFrame - First frame number in the sequence (0-indexed)
     * @param endFrame - Last frame number in the sequence (0-indexed)
     * @param minVal - Minimum frame value for chart scaling
     * @param maxVal - Maximum frame value for chart scaling
     * @param outputPathList - Array of 4 base paths: [orig, test, diff, alpha]
     * @param chartList_frame - Array of frame numbers for chart data points
     * @param chartList_val - Array of frame values for chart data points
     * @param frameUnderThreshold - Threshold value for highlighting frames (duplicate param - legacy)
     * @param origFreeDViewName - Original FreeDView version name
     * @param testFreeDViewName - Test FreeDView version name
     */
    function openProjectUpdate(startFrame, endFrame, minVal, maxVal, outputPathList, chartList_frame, chartList_val, frameUnderThreshold, origFreeDViewName, testFreeDViewName){
        // Input validation: Only check for null/undefined (defensive programming)
        // Other validation (ranges, types) is handled by calling code in TopLayout_zero.qml
        if (startFrame === undefined || startFrame === null || 
            endFrame === undefined || endFrame === null) {
            return  // Invalid frame parameters - exit early
        }
        
        // Validate outputPathList exists and has at least 4 elements
        // QStringList from C++ has length property accessible in QML
        if (!outputPathList || typeof outputPathList.length === "undefined" || outputPathList.length < 4) {
            return  // Invalid path list - exit early
        }
        
        // Components are loaded asynchronously - check if they exist
        // The actual method calls below will check for function availability
        if (swipeViewComponent === undefined || swipeViewComponent === null ||
            chartComponent === undefined || chartComponent === null) {
            return  // Components not loaded yet - exit early
        }
        
        // Log project loading
        Logger.info("[UI] Loading project: frames " + startFrame + "-" + endFrame + " (" + (endFrame - startFrame + 1) + " frames), versions: " + origFreeDViewName + " vs " + testFreeDViewName)
        
        // Store frame range for validation (graph frame numbers)
        currentStartFrame = startFrame
        currentEndFrame = endFrame
        // Store actual frame count (number of frames in the array)
        currentFrameCount = chartList_frame ? chartList_frame.length : 0
        // Store chartList_frame for mapping array indices to actual frame numbers
        // Create a proper JavaScript array copy to ensure QML handles it correctly
        if (chartList_frame && chartList_frame.length > 0) {
            currentChartListFrame = []
            for (var i = 0; i < chartList_frame.length; i++) {
                currentChartListFrame.push(chartList_frame[i])
            }
        } else {
            currentChartListFrame = []
        }
        
        // Convert Windows paths to QML file:// URLs using utility function
        sourcePath = Utils.formatPathForQML(outputPathList[0])
        testPath = Utils.formatPathForQML(outputPathList[1])
        diffPath = Utils.formatPathForQML(outputPathList[2])
        alphaPath = Utils.formatPathForQML(outputPathList[3])

        // Update image loader manager with new paths (for C++ image loading)
        if (typeof imageLoaderManager !== "undefined" && imageLoaderManager) {
            imageLoaderManager.setImagePaths(sourcePath, testPath, diffPath, alphaPath)
            imageLoaderManager.clearCache()  // Clear cache when switching events
            Logger.debug("[UI] Image paths updated, cache cleared")
        }

        //-- when set is selected - delete old images and chart and create new images and new chart ------------
        swipeViewComponent.startLoadAllImages(startFrame, endFrame, sourcePath, testPath, diffPath, alphaPath)
        chartComponent.loadXML(startFrame, endFrame, minVal, maxVal, chartList_frame, chartList_val)
        chartComponent.setSliderVal(startFrame)
        // Apply filter to show only points with Y <= threshold
        chartComponent.applyScatterPointFilter(frameUnderThreshold)
        // Update filtered point count in InfoHeader
        if (swipeViewComponent && typeof swipeViewComponent.updateFilteredPointCount === "function") {
            swipeViewComponent.updateFilteredPointCount(chartComponent.filteredPointCount)
        }

        //-- update the "origFreeDViewName" and the "testFreeDViewName" ----
        swipeViewComponent.updateFreeDViewNames(origFreeDViewName, testFreeDViewName)
        
        Logger.info("[UI] Project loaded successfully")
    }

    /**
     * @brief Update minimum frame value threshold from table view
     * 
     * Called when user changes the frame threshold value in the table view header.
     * Updates the chart to highlight frames below the threshold in red.
     * 
     * @param value - New minimum frame value threshold
     */
    function getMinFrameValueFromTopLayoutZero(value)
    {
        // Input validation: Check for null, undefined, or invalid types
        if (value === undefined || value === null || (typeof value !== "number" && typeof value !== "string")) {
            return  // Invalid input - exit early
        }
        
        // Log threshold change
        Logger.debug("[UI] Frame threshold changed to: " + value)
        
        // Check if chartComponent is loaded before calling methods
        if (chartComponent && typeof chartComponent.applyScatterPointFilter === "function") {
            // Apply filter to show only points with Y <= threshold
            chartComponent.applyScatterPointFilter(value)
            // Update filtered point count in InfoHeader
            if (swipeViewComponent && typeof swipeViewComponent.updateFilteredPointCount === "function") {
                swipeViewComponent.updateFilteredPointCount(chartComponent.filteredPointCount)
            }
        }
    }

    /**
     * @brief Change the active page in the SwipeView
     * 
     * Navigates between the three main views:
     * - Page 0: Table view (event selection)
     * - Page 1: 3-window comparison view (A, B, C side-by-side)
     * - Page 2: Single large window view (D with A/B toggle)
     * 
     * @param pageIndex - Target page index (0, 1, or 2)
     *                        Can also be relative: +1 for next, -1 for previous
     */
    function changePageIndex(pageIndex)
    {
        // Input validation: Check for null, undefined, or invalid types
        if (pageIndex === undefined || pageIndex === null || typeof pageIndex !== "number") {
            return  // Invalid input - exit early
        }
        
        // Validate component is available
        if (!swipeViewComponent || typeof swipeViewComponent.changePageIndex !== "function") {
            return  // Component not ready - exit early
        }
        
        // Get current page before change (if swipeViewComponent exists)
        var currentPage = -1
        if (swipeViewComponent && typeof swipeViewComponent.getCurrentPage === "function") {
            currentPage = swipeViewComponent.getCurrentPage()
        } else if (swipeViewComponent && swipeViewComponent.swipeView_id) {
            currentPage = swipeViewComponent.swipeView_id.currentIndex
        }
        var pageNames = ["Table View", "3-Window View", "Single Window View"]
        Logger.info("[UI] Navigating page: " + (currentPage >= 0 && currentPage < pageNames.length ? pageNames[currentPage] : "Unknown") + " → " + (pageIndex > 0 ? "Next" : pageIndex < 0 ? "Previous" : "Same"))
        
        swipeViewComponent.changePageIndex(pageIndex)
    }
    
    /**
     * @brief Update tooltip text in the status bar
     * 
     * Forwards tooltip updates to the Tableview component's status bar (page 1)
     * or InfoHeader component's info bar (pages 2 and 3).
     * This allows components like TimelineChart to update tooltips.
     * 
     * @param text - Tooltip text to display
     */
    function setTooltip(text) {
        // Input validation: Check for null or undefined (empty string is valid)
        if (text === undefined || text === null) {
            return  // Invalid input - exit early
        }
        
        // Update tooltip for the active page
        var currentPage = -1
        if (swipeViewComponent) {
            if (swipeViewComponent.swipeView_id) {
                currentPage = swipeViewComponent.swipeView_id.currentIndex
            }
        }
        
        if (currentPage === 0) {
            // Page 1 (table) - use Tableview status bar
            if (tableViewComponent && typeof tableViewComponent.setTooltip === "function") {
                tableViewComponent.setTooltip(text)
            }
        } else if (currentPage === 1 || currentPage === 2) {
            // Pages 2 or 3 (image views) - update InfoHeaders
            if (swipeViewComponent && typeof swipeViewComponent.setInfoHeaderTooltip === "function") {
                swipeViewComponent.setInfoHeaderTooltip(text)
            }
        } else {
            // Fallback: if page detection fails or not initialized, try both
            // Try InfoHeader first (for pages 2/3)
            if (swipeViewComponent && typeof swipeViewComponent.setInfoHeaderTooltip === "function") {
                swipeViewComponent.setInfoHeaderTooltip(text)
            }
            // Also try Tableview (for page 1)
            if (tableViewComponent && typeof tableViewComponent.setTooltip === "function") {
                tableViewComponent.setTooltip(text)
            }
        }
    }
    
    /**
     * @brief Get the current page index
     * 
     * Returns the current SwipeView page index:
     * - 0 = Page 1 (table view)
     * - 1 = Page 2 (3-window image view)
     * - 2 = Page 3 (single large image view)
     * 
     * @returns Current page index, or -1 if not available
     */
    function getCurrentPage() {
        var currentPage = -1
        if (swipeViewComponent && swipeViewComponent.swipeView_id) {
            currentPage = swipeViewComponent.swipeView_id.currentIndex
        }
        return currentPage
    }
    
    /**
     * @brief Clear tooltip text in the status bar
     * 
     * Forwards tooltip clear to the Tableview component's status bar (page 1)
     * or InfoHeader component's info bar (pages 2 and 3).
     */
    function clearTooltip() {
        // Clear tooltip for the active page
        var currentPage = -1
        if (swipeViewComponent) {
            if (swipeViewComponent.swipeView_id) {
                currentPage = swipeViewComponent.swipeView_id.currentIndex
            }
        }
        
        if (currentPage === 0) {
            // Page 1 (table) - use Tableview status bar
            if (tableViewComponent && typeof tableViewComponent.clearTooltip === "function") {
                tableViewComponent.clearTooltip()
            }
        } else if (currentPage === 1 || currentPage === 2) {
            // Pages 2 or 3 (image views) - clear InfoHeaders
            if (swipeViewComponent && typeof swipeViewComponent.clearInfoHeaderTooltip === "function") {
                swipeViewComponent.clearInfoHeaderTooltip()
            }
        } else {
            // Fallback: if page detection fails, try Tableview (page 1 is most common)
            if (tableViewComponent && typeof tableViewComponent.clearTooltip === "function") {
                tableViewComponent.clearTooltip()
            }
        }
    }
}
