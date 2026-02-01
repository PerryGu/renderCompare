/**
 * @file TimelineChart.qml
 * @brief Interactive timeline chart for frame-by-frame value visualization
 * 
 * A sophisticated chart component that displays frame values as a scatter plot
 * with an interactive timeline slider. Users can:
 * - Scrub through frames using the timeline slider
 * - Zoom into specific frame ranges using the zoom selector
 * - See frames below threshold highlighted in red
 * - Navigate to next/previous problematic frames
 * - Filter points based on threshold value
 * 
 * Features:
 * - Real-time frame value visualization
 * - Interactive zoom and pan
 * - Threshold-based filtering and highlighting
 * - Synchronized with image views (scrubbing updates images)
 * - Navigation controls for finding problematic frames
 * - Tooltip support for detailed frame information
 * 
 * The chart is shared between pages 1 and 2, with InfoHeader components
 * displaying metadata for each page.
 */

import QtCharts 2.1
import QtQuick.Controls 2.0
import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.4
import QtGraphicalEffects 1.0
import Theme 1.0
import Constants 1.0
import Logger 1.0


Rectangle {
    anchors.fill: parent
    id:chartHoldId
    color: Theme.primaryDark
    
    property var mainItemRef: null
    property int frame_index
    property real frame_value: 0.0
    property var oneDArray: []
    property string scatterMarkColor: Theme.chartMark
    property bool lockMarkMovement: false
    property var chartValue_y: []
    property var minFram_list: []

    property real guide_ops: Theme.guideOpacity

    property int minVal_x: 1
    property int maxVal_x: 1
    property real minVal_y: 1.0
    property real maxVal_y: 1.0
    property string short_valueOnThisFrame: "none"
    property alias sliderUpdate: timeSlider_id.value
    property int startFrame: 1
    property real value_x: 0.0
    property int value_start: chartHoldId.minVal_x - 5
    property int value_end: chartHoldId.maxVal_x + 5
    property real timeSliderDragRectMouseX: 0.0
    property real osx: 0.0
    property real sx: 1.0
    property var selection: undefined
    property var scatterSeries_id: undefined
    property var selComp_id
    property int last_startFrame: 0
    property int last_endFrame: 0
    property var chartList_frame: []
    property int actualFrameCount: 0
    property var originalChartList_frame: []
    property var originalChartList_val: []
    property real currentThreshold: 1.0
    property int filteredPointCount: 0
    
    property bool isPlayingForward: false
    property bool isPlayingReverse: false
    property int playbackSpeed: Constants.playbackSpeedNormal
    property bool chartAnimationEnabled: true
    
    // Performance optimization: Throttle chart updates during rapid scrubbing
    property bool isScrubbing: false
    property int pendingChartUpdate: -1  // Frame number pending update (-1 = none)
    
    /**
     * @brief Get current page index from SwipeView
     * 
     * Retrieves the currently active page index from the main SwipeView component.
     * Used to determine which view (table, 3-window, or single-window) is currently displayed.
     * 
     * @return {number} Current page index (0-based), or 0 if unable to determine
     */
    function getCurrentPageIndex() {
        var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
        if (main && typeof main.getCurrentPage === "function") {
            var page = main.getCurrentPage()
            return page >= 0 ? page : 0
        }
        return 0
    }

    /**
     * @brief Clear all chart data
     * 
     * Removes all data points from both the line series and scatter series,
     * effectively clearing the chart display. Used when switching between
     * different event sets or resetting the chart.
     */
    function clearChart()
    {
        lineSeries.clear()
        scatterSeries.clear()
    }


    /**
     * @brief Load chart data from XML frame/value arrays
     * 
     * Initializes the chart view with frame data for a selected event set.
     * Creates line series and scatter series from the provided frame/value arrays,
     * sets up axis ranges, and positions the timeline slider at the start frame.
     * 
     * @param startFrame - First frame number in sequence (0-indexed)
     * @param endFrame - Last frame number in sequence (0-indexed)
     * @param minVal - Minimum frame value for Y-axis scaling
     * @param maxVal - Maximum frame value for Y-axis scaling
     * @param chartList_frame - Array of frame numbers for data points
     * @param chartList_val - Array of frame values for data points (corresponds to chartList_frame)
     */
    function loadXML(startFrame, endFrame, minVal, maxVal,chartList_frame, chartList_val) {
        // Store chartList_frame for reference
        chartList_frame = chartList_frame
        
        // Store original data for filtering
        originalChartList_frame = []
        originalChartList_val = []
        for (var j = 0; j < chartList_frame.length; j++) {
            originalChartList_frame.push(chartList_frame[j])
            originalChartList_val.push(chartList_val[j])
        }
        
        // minVal_x and maxVal_x are for graph display (actual frame numbers from data)
        minVal_x = startFrame
        maxVal_x = endFrame
        minVal_y = minVal
        maxVal_y = maxVal
        
        // Store original chartValue_y for lookups (always keep full array for frame number mapping)
        chartValue_y = chartList_val
        
        // Initially show all points (filtering will be applied when threshold is set)
        lineSeries.clear()
        scatterSeries_id.clear()
        for (var i = 0; i < chartList_frame.length; i++){
            lineSeries.append(chartList_frame[i], chartList_val[i])
            scatterSeries_id.append(chartList_frame[i], chartList_val[i])
        }
        // Initialize filtered point count to all points
        filteredPointCount = chartList_frame.length

        // Slider uses actual frame numbers (startFrame to endFrame), not array indices
        timeSlider_id.minimumValue = startFrame
        timeSlider_id.maximumValue = endFrame  // Use exact endFrame to prevent going beyond
        timeSlider_id.value = Math.min(startFrame + Constants.frameOffset, endFrame)  // Start at startFrame+offset or endFrame if less
        
        chart.moveMarks(timeSlider_id.value)
        destroyTimeSliderZoomSelComponent()}


    /**
     * @brief Destroy timeline zoom selector and reset slider range
     * 
     * Cleans up the timeline zoom selector component (if it exists) and resets
     * the slider's minimum and maximum values to the full frame range.
     * Called when loading new chart data to ensure the slider reflects the
     * complete data range.
     */
    function destroyTimeSliderZoomSelComponent(){
        if (selection !== undefined && selection !== null){
            selection.destroy()
            selection = undefined
        }
        value_start = chartHoldId.minVal_x - Constants.chartAxisPadding
        value_end = chartHoldId.maxVal_x + Constants.chartAxisPadding
        // Slider uses actual frame numbers
        timeSlider_id.minimumValue = minVal_x
        timeSlider_id.maximumValue = maxVal_x
    }

    // Navigation control panel
    Rectangle {
        id: navigationPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Constants.controlPanelTopMargin
        anchors.bottom: chart.top
        anchors.bottomMargin: Constants.controlPanelBottomMargin
        width: Math.min(parent.width - Constants.controlPanelMinMargin, Constants.controlPanelMaxWidth)
        color: Theme.primaryDark
        border.width: Constants.controlPanelBorderWidth
        border.color: Theme.borderDark
        z: 3

        RowLayout {
            id: controlPanelLayout_id
            anchors.fill: parent
            spacing: Constants.controlPanelSpacing
            
            // Previous frame button
            Rectangle {
                id: previousBtn_id
                color: Theme.primaryDark
                Layout.leftMargin: Constants.buttonLeftMargin
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                
                Item {
                    anchors.fill: parent
                    Image {
                        id: imageTargetMark_Id
                        source: "/images/playr/previous.png"
                        fillMode: Image.PreserveAspectFit
                        anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                        mipmap: true
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        chartAnimationEnabled = false
                        var currentValue = Math.floor(timeSlider_id.value)
                        var newValue = currentValue - 1
                        Logger.debug("[UI] Previous frame button clicked: " + currentValue + " → " + newValue)
                        var minValue = Math.floor(timeSlider_id.minimumValue)
                        if (newValue >= minValue) {
                            setSliderVal(newValue)
                        } else {
                            setSliderVal(minValue)
                        }
                        if (reenableAnimationTimer) {
                            reenableAnimationTimer.restart()
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Previous frame")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }

            // Rewind to previous red scatter point button
            Rectangle {
                id: rewindBtn_id
                color: Theme.primaryDark
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                
                Item {
                    anchors.fill: parent
                    Image {
                        source: "/images/playr/rewind.png"
                        fillMode: Image.PreserveAspectFit
                        anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                        mipmap: true
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        chartAnimationEnabled = false
                        setTimeMarkerOnRedScatterPointsPrevious()
                        if (reenableAnimationTimer) {
                            reenableAnimationTimer.restart()
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Jump to previous red scatter point")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }

            // Play reverse button
            Rectangle {
                id: play_reversBtn_id
                color: isPlayingReverse ? Theme.overlayAccent : Theme.primaryDark
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                
                Image {
                    source: "/images/playr/play_revers.png"
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                    mipmap: true
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (mouse.button === Qt.LeftButton) {
                            if (isPlayingReverse) {
                                stopPlayback()
                            } else {
                                Logger.debug("[UI] Reverse playback button clicked")
                                startReversePlayback()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (playbackSpeedMenuLoader && playbackSpeedMenuLoader.item) {
                                var buttonPos = play_reversBtn_id.mapToItem(chartHoldId, 0, 0)
                                var loaderPos = playbackSpeedMenuLoader.mapToItem(chartHoldId, 0, 0)
                                playbackSpeedMenuLoader.item.x = buttonPos.x - loaderPos.x
                                playbackSpeedMenuLoader.item.y = buttonPos.y + play_reversBtn_id.height - loaderPos.y
                                playbackSpeedMenuLoader.item.open()
                            }
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Play reverse (right-click for speed menu)")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }
            
            // Frame number input - centered in RowLayout using Item spacer
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            
            Rectangle {
                id: timeInput_id
                color: Theme.primaryDark
                Layout.preferredWidth: Constants.frameInputWidth
                Layout.minimumWidth: Constants.frameInputWidth
                Layout.maximumWidth: Constants.frameInputWidth
                Layout.fillHeight: true
                
                TextInput {
                    id: frameNumberInput
                    anchors.fill: parent
                    anchors.margins: Constants.frameInputMargin
                    font.pixelSize: Theme.fontSizeDialogTitle
                    font.bold: true
                    color: Theme.primaryAccent
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    text: timeSlider_id ? Math.floor(timeSlider_id.value).toString() : ""
                    selectByMouse: true
                    activeFocusOnPress: true
                    onEditingFinished: {
                        chartAnimationEnabled = false
                        setSliderVal(text)
                        if (reenableAnimationTimer) {
                            reenableAnimationTimer.restart()
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Select specific frame")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }
            
            // Spacer to center the input field
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            
            // Play forward button
            Rectangle {
                id: playBtn_id
                color: isPlayingForward ? Theme.overlayAccent : Theme.primaryDark
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                
                Image {
                    source: "/images/playr/play.png"
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                    mipmap: true
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (mouse.button === Qt.LeftButton) {
                            if (isPlayingForward) {
                                stopPlayback()
                            } else {
                                Logger.debug("[UI] Forward playback button clicked")
                                startForwardPlayback()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            Logger.debug("[UI] Playback speed menu opened (right-click)")
                            if (playbackSpeedMenuLoader && playbackSpeedMenuLoader.item) {
                                var buttonPos = playBtn_id.mapToItem(chartHoldId, 0, 0)
                                var loaderPos = playbackSpeedMenuLoader.mapToItem(chartHoldId, 0, 0)
                                playbackSpeedMenuLoader.item.x = buttonPos.x - loaderPos.x
                                playbackSpeedMenuLoader.item.y = buttonPos.y + playBtn_id.height - loaderPos.y
                                playbackSpeedMenuLoader.item.open()
                            }
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Play forward (right-click for speed menu)")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }
            
            // Skip to next red scatter point button
            Rectangle {
                id: skipBtn_id
                color: Theme.primaryDark
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                
                Item {
                    anchors.fill: parent
                    Image {
                        source: "/images/playr/fast-forward.png"
                        fillMode: Image.PreserveAspectFit
                        anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                        mipmap: true
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        chartAnimationEnabled = false
                        setTimeMarkerOnRedScatterPointsForward()
                        if (reenableAnimationTimer) {
                            reenableAnimationTimer.restart()
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Jump to next red scatter point")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }
            
            // Next frame button
            Rectangle {
                id: fastforwardBtn_id
                color: Theme.primaryDark
                Layout.fillWidth: true
                Layout.minimumWidth: Constants.buttonMinWidth
                Layout.preferredWidth: Constants.buttonPreferredWidth
                Layout.maximumWidth: Constants.buttonMaxWidth
                Layout.minimumHeight: Constants.buttonMinHeight
                Layout.preferredHeight: Constants.buttonPreferredHeight
                Layout.rightMargin: Constants.buttonRightMargin
                
                Item {
                    anchors.fill: parent
                    Image {
                        source: "/images/playr/skip.png"
                        fillMode: Image.PreserveAspectFit
                        anchors.centerIn: parent
                    width: Math.min(parent.width - Constants.buttonImageMargin, Constants.buttonIconSize)
                    height: Math.min(parent.height - Constants.buttonImageMargin, Constants.buttonIconSize)
                        mipmap: true
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        chartAnimationEnabled = false
                        var currentValue = Math.floor(timeSlider_id.value)
                        var newValue = currentValue + 1
                        Logger.debug("[UI] Next frame button clicked: " + currentValue + " → " + newValue)
                        var maxValue = Math.floor(timeSlider_id.maximumValue)
                        if (newValue <= maxValue) {
                            setSliderVal(newValue)
                        } else {
                            setSliderVal(maxValue)
                        }
                        if (reenableAnimationTimer) {
                            reenableAnimationTimer.restart()
                        }
                    }
                    onEntered: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.setTooltip === "function") {
                            main.setTooltip("Next frame")
                        }
                    }
                    onExited: {
                        var main = mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                        if (main && typeof main.clearTooltip === "function") {
                            main.clearTooltip()
                        }
                    }
                }
            }
        }
    }

    //-- create the page index chane button (left) ----------
    Rectangle {
        id:pagIndexLeftBtn_id
        anchors.left: parent.left
        anchors.leftMargin: Constants.pageIndexButtonMargin
        anchors.top: parent.top
        anchors.topMargin: Constants.pageIndexButtonTopMargin
        width: Constants.pageIndexButtonWidth
        height: Constants.pageIndexButtonHeight
        color: Theme.primaryDark
        Item{
            anchors.fill: parent
            Image{
                id:pagIndexLeftImage_id
                source: "/images/playr/pageIndicator_right.png"
                fillMode: Image.PreserveAspectFit
                anchors.centerIn: parent
                width: Math.min(parent.width - 10, 24)  // Increased by 20% (20 * 1.2)
                height: Math.min(parent.height - 10, 24)
                mipmap:true
            }
            ColorOverlay {
                anchors.fill: pagIndexLeftImage_id
                source: pagIndexLeftImage_id
                color: Theme.primaryAccent  // Green color matching navigation buttons
                cached: false
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: { changePageIndex(-1)  }
            onEntered: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.setTooltip === "function") {
                    main.setTooltip("Previous page")
                }
            }
            onExited: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.clearTooltip === "function") {
                    main.clearTooltip()
                }
            }
        }
    }

    Rectangle {
        id:pagIndexRightBtn_id
        anchors.right: parent.right
        anchors.rightMargin: Constants.pageIndexButtonMargin
        anchors.top: parent.top
        anchors.topMargin: Constants.pageIndexButtonTopMargin
        width: Constants.pageIndexButtonWidth
        height: 42  // Increased by 20% (35 * 1.2)
        color: Theme.primaryDark

        Item{
            anchors.fill: parent
            Image{
                id:pagIndexRightImage_id
                source: "/images/playr/pageIndicator_left.png"
                fillMode: Image.PreserveAspectFit
                anchors.centerIn: parent
                width: Math.min(parent.width - 10, 24)  // Increased by 20% (20 * 1.2)
                height: Math.min(parent.height - 10, 24)
                mipmap:true
            }
            ColorOverlay {
                anchors.fill: pagIndexRightImage_id
                source: pagIndexRightImage_id
                color: Theme.primaryAccent  // Green color matching navigation buttons
                cached: false
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: { changePageIndex(1)  }
            onEntered: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.setTooltip === "function") {
                    main.setTooltip("Next page")
                }
            }
            onExited: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.clearTooltip === "function") {
                    main.clearTooltip()
                }
            }
        }
    }

    /**
     * @brief Change the active page in SwipeView
     * 
     * Delegates page navigation to the main SwipeView component.
     * Used to programmatically switch between different views (table, 3-window, single-window).
     * 
     * @param pageIndex - Page index to switch to (0 = table, 1 = 3-window, 2 = single-window)
     */
    function changePageIndex(pageIndex){
        mainItem.changePageIndex(pageIndex)
    }

    //-- create the timeline slider --------------------------------
    Slider {
        id:timeSlider_id
        Accessible.role: Accessible.Slider
        minimumValue: minVal_x  // Slider uses actual frame numbers
        maximumValue: maxVal_x  // Use exact endFrame to prevent going beyond
        activeFocusOnPress: true
        updateValueWhileDragging :true
        tickmarksEnabled: true
        stepSize:1
        anchors.left: parent.left
        anchors.leftMargin: Constants.timelineSliderX
        anchors.right: parent.right
        anchors.rightMargin: Constants.timelineSliderWidthOffset - Constants.timelineSliderX
        anchors.top: parent.top
        anchors.topMargin: 45
        z:1
        value: startFrame
        opacity: 0.95

        style: SliderStyle {
            groove: Rectangle {
                height: Constants.timelineSliderGrooveHeight
                color: Theme.primaryAccent
                radius: 10
            }
            handle: Item {
                width: 20
                height: 20
                x:10

                    Rectangle {
                        id:slidetHandle_Id
                        color: Theme.primaryAccent
                        anchors.centerIn: parent
                        width: Constants.timelineSliderHandleWidth
                        height: Constants.timelineSliderHandleHeight
                    radius: 4

                    Text{
                        anchors.centerIn: parent
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.pointSize: Theme.fontSizeExtraSmall
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.textLight  // Text color
                        width: parent.width-16
                        text: timeSlider_id.value + " | " + short_valueOnThisFrame
                        onTextChanged: {setSliderVal(timeSlider_id.value)}
                    }
                }
            }
        }

        onValueChanged: {
            // Disable chart animation during scrubbing
            chartAnimationEnabled = false
            isScrubbing = true
            
            // Cancel any pending preload (user is still scrubbing)
            preloadTimer.stop()
            
            // Performance optimization: Throttle chart updates during rapid scrubbing
            // Store the latest frame value but don't update immediately
            pendingChartUpdate = timeSlider_id.value
            
            // Use throttled update timer to batch rapid updates
            throttledChartUpdateTimer.restart()
            
            // Re-enable animation after a short delay when scrubbing stops
            reenableAnimationTimer.restart()
        }
        
        // Also handle pressedChanged to ensure updates during dragging
        onPressedChanged: {
            if (pressed) {
                // Disable chart animation when user starts dragging
                chartAnimationEnabled = false
                isScrubbing = true
            }
            if (!pressed) {
                // When released, ensure final value is set immediately (no throttling on release)
                pendingChartUpdate = -1  // Clear any pending throttled update
                throttledChartUpdateTimer.stop()  // Stop throttling timer
                chart.moveMarks(timeSlider_id.value)  // Apply final value immediately
                
                // Mark scrubbing as stopped and trigger preload
                isScrubbing = false
                preloadTimer.restart()  // Preload adjacent frames after pause
                
                // Re-enable animation after release
                reenableAnimationTimer.restart()
            }
        }
    }


    ChartView {
        id: chart
        // qmllint disable M16
        anchors.fill: parent
        anchors.topMargin: 50
        anchors.bottomMargin: 34
        antialiasing: true
        // qmllint enable M16
        animationOptions: chartHoldId.chartAnimationEnabled ? ChartView.SeriesAnimations : ChartView.NoAnimation
        theme: ChartView.ChartThemeDark
        // qmllint disable M17
        legend.visible: false
        // qmllint enable M17
        
        // MouseArea for tooltip when hovering over chart (page 3 only)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with chart interactions
            propagateComposedEvents: true
            onEntered: {
                // Check if we're on page 3 (index 2)
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.getCurrentPage === "function") {
                    var currentPage = main.getCurrentPage()
                    if (currentPage === 2 && typeof main.setTooltip === "function") {
                        main.setTooltip("Middle button press in main window toggles render test version")
                    }
                }
            }
            onExited: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.clearTooltip === "function") {
                    main.clearTooltip()
                }
            }
        }

        ValueAxis {
            id: axisX
            min: value_start
            max: value_end
            tickCount: 10
        }

        ValueAxis {
            id: axisY
            min: chartHoldId.minVal_y - minVal_y/10
            max: chartHoldId.maxVal_y + maxVal_y/10

        }

        LineSeries {
            id: lineSeries
            axisX: axisX
            axisY: axisY
        }

        ScatterSeries {
            id: scatterSeries_id
            axisX: axisX
            axisY: axisY
            markerSize: 5
        }

        ScatterSeries {
            id: scatterUnderValue_id
            markerSize: 8
            color: Theme.statusError
            XYPoint { x: 0; y: 0}
        }

        //-- create the marker guides -----------------
        LineSeries {
            id: lineMarkH_id
            width: 2
            opacity: chartHoldId.guide_ops
            color: Theme.chartMark
        }

        LineSeries {
            id: lineMarkV_id
            width: 2
            opacity: chartHoldId.guide_ops
            color: Theme.chartMark
        }

        ScatterSeries {
            id: scatterMark_id
            markerSize: 16
            opacity: chartHoldId.guide_ops
            color: scatterMarkColor
            XYPoint { x: 0; y: 0}
        }


        LineSeries {
            id: lineMarkRef
            width: 3
            opacity: 0.1
        }

        /**
         * @brief Move chart markers to indicate current frame position
         * 
         * Updates the chart visualization to show the current frame position:
         * - Vertical line (X-axis marker) at current frame
         * - Horizontal line (Y-axis marker) at current frame value
         * - Scatter point marker at (frame, value) intersection
         * 
         * Also triggers image updates by calling mainItem.changeIndex().
         * 
         * @param x - Frame number to move markers to (will be rounded to integer)
         */
        function moveMarks(x) {
            if (lockMarkMovement === false){
                x = Math.round(x)
                
                if (x < minVal_x) {
                    x = minVal_x
                } else if (x > maxVal_x) {
                    x = maxVal_x
                }

                // Calculate array index: frames are 0-indexed in array, but startFrame might not be 0
                var arrayIndex = x - minVal_x
                if (arrayIndex < 0 || arrayIndex >= chartValue_y.length) {
                    return;  // Out of bounds, skip
                }
                
                var valueOnThisFrame = chartValue_y[arrayIndex]
                
                // Safety check: if valueOnThisFrame is undefined, skip
                if (valueOnThisFrame === undefined || isNaN(valueOnThisFrame)) {
                    return;
                }

                lineMarkH_id.clear()
                lineMarkH_id.append(x, -8)
                lineMarkH_id.append(x, 8)

                //-- set the Y Line pos ------
                lineMarkV_id.clear()
                lineMarkV_id.append(minVal_x-8, valueOnThisFrame)
                lineMarkV_id.append(maxVal_x+8, valueOnThisFrame)

                //-- set the Point pos ------
                scatterMark_id.replace(0, x, valueOnThisFrame)
                short_valueOnThisFrame = valueOnThisFrame.toFixed(3)

                //-----------------------------------
                // Pass actual frame number to changeIndex (x is already the frame number, e.g., 388)
                valueOnThisFrame = mainItem.changeIndex(x)
            }
        }
    }

    /**
     * @brief Set the timeline slider position
     * 
     * Updates the slider value, which triggers chart marker updates
     * and image frame updates through the changeIndex signal chain.
     * 
     * @param val - Frame number to set slider to (0-indexed)
     */
    function setSliderVal(val){
        // Ensure val is a valid number before assigning
        if (val !== undefined && val !== null && !isNaN(val)) {
            // Clamp value to valid frame number range (minVal_x to maxVal_x)
            var clampedVal = val
            if (clampedVal < minVal_x) {
                clampedVal = minVal_x
            } else if (clampedVal > maxVal_x) {
                clampedVal = maxVal_x
            }
            sliderUpdate = clampedVal
        }
    }
    
    /**
     * @brief Start forward playback (automatic frame progression)
     */
    function startForwardPlayback() {
        // Stop any reverse playback first
        if (isPlayingReverse) {
            stopPlayback()
        }
        Logger.info("[UI] Playback started: Forward")
        isPlayingForward = true
        playbackTimer.running = true
    }
    
    /**
     * @brief Start reverse playback (automatic frame progression in reverse)
     */
    function startReversePlayback() {
        // Stop any forward playback first
        if (isPlayingForward) {
            stopPlayback()
        }
        Logger.info("[UI] Playback started: Reverse")
        isPlayingReverse = true
        playbackTimer.running = true
    }
    
    /**
     * @brief Stop playback (both forward and reverse)
     */
    function stopPlayback() {
        if (isPlayingForward || isPlayingReverse) {
            Logger.info("[UI] Playback stopped")
        }
        isPlayingForward = false
        isPlayingReverse = false
        playbackTimer.running = false
        // Re-enable chart animation when playback stops
        chartAnimationEnabled = true
    }
    
    /**
     * @brief Timer to throttle chart updates during rapid scrubbing
     * 
     * Performance optimization: Instead of updating chart on every slider value change
     * (which can be 60+ times per second during rapid scrubbing), we batch updates
     * and only apply the latest value after a short delay.
     */
    Timer {
        id: throttledChartUpdateTimer
        interval: 16  // ~60fps max update rate (16ms = 1 frame at 60fps)
        running: false
        repeat: false
        onTriggered: {
            if (pendingChartUpdate >= 0) {
                // Apply the latest pending update
                chart.moveMarks(pendingChartUpdate)
                pendingChartUpdate = -1
            }
        }
    }
    
    /**
     * @brief Timer to trigger preload when scrubbing pauses
     * 
     * Performance optimization: Preload adjacent frames (±2) when user pauses scrubbing
     * to make frame-by-frame navigation smoother. Only preloads for currently visible page.
     */
    Timer {
        id: preloadTimer
        interval: 200  // Wait 200ms after scrubbing stops before preloading
        running: false
        repeat: false
        onTriggered: {
            if (!isScrubbing && typeof imageLoaderManager !== "undefined" && imageLoaderManager) {
                var currentFrame = Math.round(timeSlider_id.value)
                var maxFrame = maxVal_x
                
                // Determine which image types to preload based on current page
                var currentPage = getCurrentPageIndex()
                var imageTypes = []
                
                if (currentPage === Constants.pageThreeWindow) {
                    // Page 2 (3-window): Preload A, B, C
                    imageTypes = [Constants.imageTypeOrig, Constants.imageTypeTest, Constants.imageTypeDiff]
                } else if (currentPage === Constants.pageSingleWindow) {
                    // Page 3 (single-window): Preload only visible version (A or B) + D
                    // Note: We can't determine which version is visible from here,
                    // so preload both A and B plus D (the optimization in ImageFileD
                    // will only load the visible one)
                    imageTypes = [Constants.imageTypeOrig, Constants.imageTypeTest, Constants.imageTypeAlpha]
                } else {
                    // Page 1 (table) or unknown: Don't preload (not viewing images)
                    return
                }
                
                // Preload adjacent frames (±2) for the determined image types
                if (imageTypes.length > 0) {
                    imageLoaderManager.preloadAdjacentFrames(currentFrame, maxFrame, imageTypes)
                }
            }
        }
    }
    
    /**
     * @brief Timer for automatic frame progression during playback
     */
    Timer {
        id: playbackTimer
        interval: playbackSpeed
        running: false
        repeat: true
        onTriggered: {
            if (isPlayingForward) {
                // Forward playback: increment frame number
                var nextValue = timeSlider_id.value + 1
                if (nextValue > timeSlider_id.maximumValue) {
                    // Reached end, stop playback and clamp to maximum
                    stopPlayback()
                    if (timeSlider_id.value > timeSlider_id.maximumValue) {
                        setSliderVal(timeSlider_id.maximumValue)
                    }
                } else {
                    setSliderVal(nextValue)
                }
            } else if (isPlayingReverse) {
                // Reverse playback: decrement frame number
                var prevValue = timeSlider_id.value - 1
                if (prevValue < timeSlider_id.minimumValue) {
                    // Reached beginning, stop playback and clamp to minimum
                    stopPlayback()
                    if (timeSlider_id.value < timeSlider_id.minimumValue) {
                        setSliderVal(timeSlider_id.minimumValue)
                    }
                } else {
                    setSliderVal(prevValue)
                }
            } else {
                // Should not happen, but stop timer if neither direction is active
                playbackTimer.running = false
            }
        }
    }
    
    // Stop playback if user manually interacts with the slider
    Connections {
        target: timeSlider_id
        onPressedChanged: {
            // If user starts dragging the slider, stop playback
            if (timeSlider_id.pressed && (isPlayingForward || isPlayingReverse)) {
                stopPlayback()
            }
        }
    }

    // Timer to re-enable chart animation after navigation stops
    Timer {
        id: reenableAnimationTimer
        interval: Constants.animationReenableDelay  // Delay after navigation stops
        onTriggered: {
            // Mark scrubbing as stopped (if not actively scrubbing)
            if (!timeSlider_id.pressed) {
                isScrubbing = false
                // Trigger preload if scrubbing has stopped
                preloadTimer.restart()
            }
            // Only re-enable if playback is not active
            if (!isPlayingForward && !isPlayingReverse) {
                chartAnimationEnabled = true
            }
        }
    }

    /**
     * @brief Playback speed context menu
     * 
     * Reusable component for selecting playback speed.
     * Appears when right-clicking on play buttons (forward or reverse).
     */
    Loader {
        id: playbackSpeedMenuLoader
        source: "qrc:/qml/PlaybackSpeedMenu.qml"
        onLoaded: {
            if (item) {
                item.playbackSpeed = chartHoldId.playbackSpeed
                item.speedSelected.connect(function(speed) {
                    chartHoldId.playbackSpeed = speed
                })
            }
        }
        
        // Update playbackSpeed when it changes (using binding)
        onItemChanged: {
            if (item) {
                item.playbackSpeed = Qt.binding(function() { return chartHoldId.playbackSpeed })
            }
        }
    }

    //-- create the holder time range Zoom item --------------------------------------------------------
    Rectangle {
        id:timeSliderZoom_id
        anchors.top: chart.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 15
        anchors.left: parent.left
        anchors.leftMargin: 40
        anchors.right: parent.right
        anchors.rightMargin: 30
        z:3
        color: Theme.chartMark
        radius: 14
        
        // Destroy zoom selector when orange bar resizes (separator moved)
        onWidthChanged: {
            if (selection) {
                destroyTimeSliderZoomSelComponent()
            }
        }
        onHeightChanged: {
            if (selection) {
                destroyTimeSliderZoomSelComponent()
            }
        }
        onXChanged: {
            if (selection) {
                destroyTimeSliderZoomSelComponent()
            }
        }
        onYChanged: {
            if (selection) {
                destroyTimeSliderZoomSelComponent()
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Always destroy existing selection first to ensure clean state
                if(selection) {
                    destroyTimeSliderZoomSelComponent()
                }
                
                // Calculate relative positions for the zoom selector
                // The selector should sit inside the orange bar (as a child of the orange bar)
                var selX = 10  // Small margin from left edge of orange bar
                var selY = 1  // Small margin from top of orange bar (positioned inside)
                var selWidth = parent.width - 20  // Width with margins on both sides
                var selHeight = parent.height - 2  // Height slightly less than orange bar to fit inside
                
                selection = timeSliderZoomSelComponent_id.createObject(parent, {"x": selX, "y": selY, "width": selWidth, "height": selHeight })
                if (!selection) {
                    Logger.error("[UI] Failed to create zoom selector")
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with clicks
            onEntered: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.setTooltip === "function") {
                    main.setTooltip("Timeline scale - click to select range")
                }
            }
            onExited: {
                var main = chartHoldId.mainItemRef || (typeof mainItem !== "undefined" ? mainItem : null)
                if (main && typeof main.clearTooltip === "function") {
                    main.clearTooltip()
                }
            }
        }
    }

    Component {
        id: timeSliderZoomSelComponent_id
        Rectangle {
            id: selComp_id
            border {
                width: 2
                color: Theme.uiSteelBlue
            }
            color: Theme.overlayChartMark  // Semi-transparent chart mark color
            property int rulersSize: 18

            MouseArea {     // drag mouse area
                anchors.fill: parent
                onClicked: {
                }

                drag
                {
                    target: parent
                    minimumX: 0
                    minimumY: 0
                    maximumX: parent.parent.width - parent.width
                    maximumY: parent.parent.height - parent.height
                    smoothed: true
                }
                onMouseXChanged: {
                    if(drag.active){
                        timeSliderOffset(selComp_id.x, selComp_id.width+selComp_id.x)
                    }
                }

                onDoubleClicked: {
                    destroyTimeSliderZoomSelComponent()
                }
            }

            Rectangle {
                id: startHandle_id
                width: rulersSize
                height: rulersSize
                radius: rulersSize
                color: Theme.primaryAccent //"#589acc"
                anchors.horizontalCenter: parent.left
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    drag{ target: parent; axis: Drag.XAxis }
                    onMouseXChanged: {
                        if(drag.active){
                            Logger.debug("[UI] Start handle dragging - mouseX=" + mouseX + ", current x=" + selComp_id.x + ", width=" + selComp_id.width)
                            timeSliderStart(selComp_id.x)
                            selComp_id.width = selComp_id.width - mouseX
                            selComp_id.x = selComp_id.x + mouseX
                            if(selComp_id.width < 30)
                                selComp_id.width = 30
                            Logger.debug("[UI] Start handle dragged - new x=" + selComp_id.x + ", new width=" + selComp_id.width)
                        }
                    }
                }
            }

            Rectangle {
                id: endHandle_id
                width: rulersSize
                height: rulersSize
                radius: rulersSize
                color: Theme.primaryAccent
                anchors.horizontalCenter: parent.right
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    drag{ target: parent; axis: Drag.XAxis }
                    onMouseXChanged: {
                        if(drag.active){
                            Logger.debug("[UI] End handle dragging - mouseX=" + mouseX + ", current x=" + selComp_id.x + ", width=" + selComp_id.width)
                            timeSliderEnd(selComp_id.width+selComp_id.x)
                            selComp_id.width = selComp_id.width + mouseX
                            if(selComp_id.width < 50)
                                selComp_id.width = 50
                            Logger.debug("[UI] End handle dragged - new x=" + selComp_id.x + ", new width=" + selComp_id.width)
                        }
                    }
                }
            }
        }
    }


    /**
     * @brief Update timeline zoom start position
     * 
     * Called when user drags the start handle of the timeline zoom selector.
     * Converts the visual position to a frame number and updates the slider's
     * minimum value, effectively zooming into a specific frame range.
     * 
     * The conversion uses linear mapping from visual coordinates to frame numbers.
     * 
     * @param value - X coordinate of the start handle in visual space
     */
    function timeSliderStart(value)
    {
        var oldRange = (timeSliderZoom_id.width - timeSliderZoom_id.x)
        var newRange = (chartHoldId.maxVal_x - chartHoldId.minVal_x)
        var newValue = Math.round(((((value - timeSliderZoom_id.x) * newRange) / oldRange) + chartHoldId.minVal_x) + Constants.timelineZoomStartOffset)

        if (newValue < value_end){
            value_start = newValue
            last_startFrame = value_start
            timeSlider_id.minimumValue = value_start
        }
    }

    /**
     * @brief Update timeline zoom end position
     * 
     * Called when user drags the end handle of the timeline zoom selector.
     * Converts the visual position to a frame number and updates the slider's
     * maximum value, effectively zooming into a specific frame range.
     * 
     * @param value - X coordinate of the end handle in visual space
     */
    function timeSliderEnd(value)
    {
        var oldRange = (timeSliderZoom_id.width - timeSliderZoom_id.x)
        var newRange = (chartHoldId.maxVal_x - chartHoldId.minVal_x)
        var newValue = Math.round(((((value - timeSliderZoom_id.x) * newRange) / oldRange) + chartHoldId.minVal_x) + Constants.timelineZoomEndOffset)

        if (newValue > value_start){
            value_end = newValue
            timeSlider_id.maximumValue = value_end
        }
    }

    /**
     * @brief Update timeline zoom range when dragging the entire selector
     * 
     * Called when user drags the timeline zoom selector rectangle (not the handles).
     * Updates both start and end positions while maintaining the zoom range width.
     * 
     * @param valueS_x - X coordinate of the start edge
     * @param valueE_x - X coordinate of the end edge
     */
    function timeSliderOffset(valueS_x, valueE_x)
    {
        var oldRange = (timeSliderZoom_id.width - timeSliderZoom_id.x)
        var newRange = (chartHoldId.maxVal_x - chartHoldId.minVal_x)
        var sValue = Math.round(((((valueS_x - timeSliderZoom_id.x) * newRange) / oldRange) + chartHoldId.minVal_x) + Constants.timelineZoomStartOffset)

        value_start = sValue
        timeSlider_id.minimumValue = value_start
        var eValue = Math.round(((((valueE_x - timeSliderZoom_id.x) * newRange) / oldRange) + chartHoldId.minVal_x) + Constants.timelineZoomEndOffset)

        var newOffset = eValue - sValue
        value_end = sValue + newOffset
        timeSlider_id.maximumValue = value_end
    }


    /**
     * @brief Filter scatter points based on threshold value
     * 
     * Only displays scatter points where Y value is less than or equal to the threshold.
     * Points with Y value greater than the threshold are hidden.
     * 
     * @param threshold - Threshold value (only points with Y <= threshold are shown)
     */
    function applyScatterPointFilter(threshold) {
        // Ensure threshold is a number (convert from string if needed)
        var numThreshold = typeof threshold === "string" ? parseFloat(threshold) : Number(threshold)
        if (isNaN(numThreshold)) {
            return
        }
        currentThreshold = numThreshold
        
        // Clear existing series (but keep chartValue_y intact for frame number lookups)
        lineSeries.clear()
        scatterSeries_id.clear()
        // NOTE: Do NOT modify chartValue_y - it must remain aligned with original frame numbers
        // for moveMarks() to work correctly
        
        // Filter and add points based on threshold
        var count = 0
        for (var i = 0; i < originalChartList_frame.length; i++) {
            var yValue = originalChartList_val[i]
            // Only add points where Y value is less than or equal to threshold
            if (yValue <= threshold) {
                var xValue = originalChartList_frame[i]
                lineSeries.append(xValue, yValue)
                scatterSeries_id.append(xValue, yValue)
                count++
                // Do NOT push to chartValue_y - keep original array for lookups
            }
        }
        
        // Update filtered point count
        filteredPointCount = count
        
        // Also update the red scatter points (for frames under threshold)
        setScaterPointsToRed(threshold)
    }
    
    /**
     * @brief Highlight scatter points below threshold value in red
     * 
     * Creates a separate scatter series (scatterUnderValue_id) containing only
     * points where the frame value is less than or equal to the threshold.
     * This visual indicator helps users quickly identify problematic frames.
     * 
     * @param val - Threshold value (frames with value <= val are highlighted red)
     */
    function setScaterPointsToRed(val) {
        scatterUnderValue_id.clear()
        for (var i = 0; i < scatterSeries_id.count; i++){
            var framVal = scatterSeries_id.at(i)
            if (framVal.y <= val){
                scatterUnderValue_id.append(framVal.x,  framVal.y)
            }
        }

    }

    /**
     * @brief Navigate to next frame with value below threshold
     * 
     * Finds the next red scatter point (frame below threshold) after the
     * current slider position and moves the slider to that frame.
     * Useful for quickly jumping between problematic frames.
     */
    function setTimeMarkerOnRedScatterPointsForward()
    {
        var getLowVal_list = []
        for (var i = 0; i < scatterUnderValue_id.count; i++){
            var framVal = scatterUnderValue_id.at(i)
            if (framVal.x > timeSlider_id.value)
            {
                getLowVal_list.push(framVal.x)
            }
        }
        setSliderVal(getLowVal_list[0])
    }

    /**
     * @brief Navigate to previous frame with value below threshold
     * 
     * Finds the previous red scatter point (frame below threshold) before the
     * current slider position and moves the slider to that frame.
     * Useful for quickly jumping between problematic frames.
     */
    function setTimeMarkerOnRedScatterPointsPrevious()
    {
        var getLowVal_list = []
        for (var i = 0; i < scatterUnderValue_id.count; i++){
            var framVal = scatterUnderValue_id.at(i)
            if (framVal.x < timeSlider_id.value)
            {
                getLowVal_list.push(framVal.x)
            }
        }
        setSliderVal(getLowVal_list[getLowVal_list.length-1])
    }
}
