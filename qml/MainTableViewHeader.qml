/**
 * @file MainTableViewHeader.qml
 * @brief Header bar for the table view with search, filter, and controls
 * 
 * This component provides the header controls for the main table view (page 0),
 * including:
 * - Search field for filtering table rows (Ctrl+F to focus)
 * - Reload button to refresh the table data
 * - FreeDView version combo box for filtering by version
 * - Render Compare button for launching batch rendering
 * - Frame threshold control for chart filtering
 * 
 * The header communicates with TopLayout_zero.qml via signals and property bindings
 * to coordinate filtering, searching, and data reloading.
 */

import QtQuick.Layouts 1.3
import QtQuick 2.7
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import QtQuick.Controls.Private 1.0
import Theme 1.0
import Logger 1.0

Rectangle {
    anchors.fill: parent
    color: mainColor
    property bool disableRenderCompare: false
    property string renderCompareIconPath: "/images/renderCompare.png"
    property real mainHeader_frameUnderThreshold: 1.00
    property var mainHeader_freeDViewVer_list: []
    property int selectedFreeDViewVerIndex: 0
    property string mainColor: Theme.primaryDark
    property string searchText: ""
    property var tableViewLoaderRef: null
    property var mainItemRef: null  // Reference to Main.qml for accessing showLogWindow
    
    // Signal to notify parent when version selection changes
    signal versionSelected(int index)
    
    // Function to focus the search field (called by Ctrl+F)
    function focusSearchField() {
        if (headerSearchField) {
            headerSearchField.forceActiveFocus()
        }
    }

    RowLayout {
        id: layoutTableViewHeader_id
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: 20  // Increased space from top
        anchors.left: parent.left
        anchors.leftMargin: 10
        spacing: 10

        //--- button - reload table view button -----------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 110
            Layout.preferredHeight: 25  // Match other elements' height
            color: mainColor
            Item{
                anchors.fill: parent
                Image{
                    anchors.centerIn: parent
                    source: "/images/reload.png"
                    fillMode: Image.PreserveAspectFit
                    width: 34
                    height: 34
                    mipmap:true
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPressed: { 
                    Logger.info("[UI] Reload button clicked - refreshing table data")
                    reloadTableView() 
                }
                onEntered: {
                    // Update tooltip in status bar
                    var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                    if (loader && loader.item) {
                        if (typeof loader.item.setTooltip === "function") {
                            loader.item.setTooltip("Reload table data")
                        }
                    }
                }
                onExited: {
                    // Clear tooltip
                    var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                    if (loader && loader.item) {
                        if (typeof loader.item.clearTooltip === "function") {
                            loader.item.clearTooltip()
                        }
                    }
                }
            }
        }

        //-- comboBox - freedview version select ----------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 600
            Layout.preferredHeight: 25  // Match other elements' height
            Layout.rightMargin: 460  // Space for search field container (450px) + margin (10px)
            color:mainColor
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton  // Don't interfere with ComboBox clicks
                z: 10  // Above the ComboBox for hover detection
                onEntered: {
                    // Update tooltip in status bar
                    var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                    if (loader && loader.item) {
                        if (typeof loader.item.setTooltip === "function") {
                            loader.item.setTooltip("Select FreeDView version to compare")
                        }
                    }
                }
                onExited: {
                    // Clear tooltip
                    var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                    if (loader && loader.item) {
                        if (typeof loader.item.clearTooltip === "function") {
                            loader.item.clearTooltip()
                        }
                    }
                }
            }
            
            ComboBox
            {
                id: fdvVerComboBox_id
                anchors.left:parent.left
                anchors.right: parent.right
                anchors.rightMargin: 20  // Small margin from right edge of parent Rectangle
                anchors.verticalCenter: parent.verticalCenter
                height: 25  // Match search field height
                currentIndex: 0
                onCurrentIndexChanged: {
                    var selectedName = mainHeader_freeDViewVer_list && mainHeader_freeDViewVer_list[currentIndex] ? mainHeader_freeDViewVer_list[currentIndex] : "Unknown"
                    Logger.info("[UI] FreeDView version selected: " + selectedName + " (index: " + currentIndex + ")")
                    comboBoxSelected(fdvVerComboBox_id.currentIndex)
                }

                activeFocusOnPress: true
                style: ComboBoxStyle {
                    id: comboBox

                    background: Rectangle {
                        id: rectCategory
                        color: Theme.primaryAccent
                        radius: 4
                        implicitHeight: 25  // Match search field height
                        
                        // Dropdown arrow indicator (inverted triangle)
                        Canvas {
                            id: dropdownArrow
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 8
                            
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = Theme.primaryDark  // Dark color for the arrow
                                ctx.beginPath()
                                ctx.moveTo(0, 0)  // Top-left
                                ctx.lineTo(width, 0)  // Top-right
                                ctx.lineTo(width / 2, height)  // Bottom-center (point)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton  // Don't interfere with ComboBox clicks
                            onEntered: {
                                // Update tooltip in status bar
                                var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                                if (loader && loader.item) {
                                    if (typeof loader.item.setTooltip === "function") {
                                        loader.item.setTooltip("Select FreeDView version to compare")
                                    }
                                }
                            }
                            onExited: {
                                // Clear tooltip
                                var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
                                if (loader && loader.item) {
                                    if (typeof loader.item.clearTooltip === "function") {
                                        loader.item.clearTooltip()
                                    }
                                }
                            }
                        }
                    }

                    label: Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: 25  // Leave space for dropdown arrow
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.pointSize: Theme.fontSizeExtraSmall
                        color: Theme.primaryDark  // Dark blue matching table header text
                        text: control.currentText
                        elide: Text.ElideRight  // Truncate with ellipsis if too long
                    }

                    //-- drop-down customization here
                    property Component __dropDownStyle: MenuStyle {
                        __maxPopupHeight: 200
                        __menuItemType: "comboboxitem"

                        frame: Rectangle {
                            color: Theme.primaryAccent
                            border.width: 1
                            border.color: Theme.borderLight
                            radius: 15
                        }
                        padding.top: 12
                        padding.bottom: 12

                        itemDelegate.label:             // an item text
                                                        Text
                        {
                        leftPadding :80
                        color: Theme.primaryDark  // Dark blue matching table header text
                        text: styleData.text
                    }

                    itemDelegate.background: Rectangle {
                        radius: 5
                        color: styleData.selected ? Theme.selectionHighlightAlt : Theme.uiTransparent
                    }

                    __scrollerStyle: ScrollViewStyle { }
                }

                property Component __popupStyle: Style {
                    property int __maxPopupHeight: 200
                    property int submenuOverlap: 100

                    property Component menuItemPanel: Text {
                        text: "NOT IMPLEMENTED"
                        color: Theme.primaryAccent

                        font {
                            pixelSize: 14
                            bold: true
                        }
                    }

                    property Component __scrollerStyle: null
                }
            }
            model: mainHeader_freeDViewVer_list
        }

    }

    //--- search input and log window button---------------------------------------------------------------
    Rectangle {
        id: searchFieldContainer
        anchors.right: parent.right
        anchors.rightMargin: 10  // Small margin to move further right
        anchors.top: parent.top
        anchors.topMargin: 0  // Match RowLayout top margin
        anchors.bottom: parent.bottom
        width: 450
        color: mainColor

        //-- create the Text Input  ---------------------
        Rectangle {
            id: serchTxtFiald_id
            anchors.verticalCenter: parent.verticalCenter
            height: 25
            // Right edge fixed at: logWindowButton.left - 20
            // Calculate width: expand 15% to the left from current position
            width: {
                var rightEdge = logWindowButton.x - 20  // Fixed right edge position
                var currentWidth = rightEdge - 10  // Current width (from left margin to right edge)
                return currentWidth * 1.15  // Expand by 15%
            }
            // Position so right edge stays fixed: x = rightEdge - width
            x: (logWindowButton.x - 20) - width  // Right edge fixed, left edge moves left
            color: mainColor
            TextField{
                id: headerSearchField
                anchors.fill: parent
                font.pixelSize: Theme.fontSizeMedium
                font.pointSize: Theme.fontSizeExtraSmall
                width: parent.width-16
                placeholderText: "Search..."
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: {
                    searchText = text  // Update the property when text changes
                    if (text && text.length > 0) {
                        Logger.debug("[UI] Search text changed: \"" + text + "\"")
                    } else {
                        Logger.debug("[UI] Search cleared")
                    }
                }
                Keys.onPressed: {
                    if (event.key === Qt.Key_Escape) {
                        text = ""
                        searchText = ""
                        Logger.debug("[UI] Search cleared (ESC key)")
                        event.accepted = true
                    }
                }
                style: TextFieldStyle {
                    textColor: "black"
                    background: Rectangle {
                        radius: 4
                        implicitWidth: 100
                        implicitHeight: 24
                    }
                }
            }
        }
        
        //--- Log window toggle button - positioned near right edge -----------------------
        Rectangle {
            id: logWindowButton
            anchors.right: parent.right
            anchors.rightMargin: 10  // Small margin from right edge
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 25  // Match search field height
            color: logWindowButtonMouseArea.containsMouse ? Theme.buttonHovered : Theme.buttonDefault
            radius: 4
            border.color: Theme.borderDark
            border.width: 1
            
            Image {
                anchors.centerIn: parent
                source: "/images/log.png"
                fillMode: Image.PreserveAspectFit
                width: 25  // Increased by 15% more (22 * 1.15 = 25.3, rounded to 25)
                height: 25  // Increased by 15% more (22 * 1.15 = 25.3, rounded to 25)
                mipmap: true
                smooth: true
                // Use Pad mode to avoid black borders on transparent images
                // This ensures transparent areas remain transparent
                cache: true
                asynchronous: false  // Load synchronously to avoid rendering issues
            }
            
                MouseArea {
                    id: logWindowButtonMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // Toggle log window visibility via mainItemRef
                        if (mainItemRef && typeof mainItemRef.showLogWindow === "function") {
                            // Get current state and toggle
                            var currentVisible = mainItemRef.logWindowInstance && mainItemRef.logWindowInstance.isVisible
                            Logger.info("[UI] Log window toggled: " + (!currentVisible ? "opened" : "closed"))
                            mainItemRef.showLogWindow(!currentVisible)
                        }
                    }
                }
        }
    }


}

//-- disable renderCompare button and start blinking animation -----------------
function setRenderCompareBtnToDis(type)
{
    Logger.debug("setRenderCompareBtnToDis")
    if (eventIndexValidToRenderList.length !== 0)
    {
        if (disableRenderCompare === false)
        {
            animationOne_id.to = 1
            animationTwo_id.to = 0
            startRendeCompare(type)

            if (type !== "jsonLoca"){
                disableRenderCompare = true
                animationOne_id.start()
            }
        }
        else
        {Logger.debug("In Process")}
    }
}

//-- stop  blinking animation -----------
function stopRenderCompareAnimation()
{
    Logger.debug("stopRenderCompareAnimation")
    animationOne_id.to = 0
    animationTwo_id.to = 0
    animationOne_id.stop()
    animationTwo_id.stop()
    renderCompareRingBtn_id.opacity = 0
    disableRenderCompare = false
    mainHeader_id.renderCompareIconPath = "/images/renderCompare.png"

}


//-- select item in comboBox for FreeDViewVer  -----------------------
function comboBoxSelected(currentSelected)
{
    if (mainHeader_freeDViewVer_list[parseInt(currentSelected)] !==  undefined)
    {
        var selectedName = mainHeader_freeDViewVer_list[parseInt(currentSelected)]
        
        var currentSelected_
        
        // Handle "All Render Versions" (index 0) - pass through as-is
        if (selectedName === "All Render Versions") {
            currentSelected_ = parseInt(currentSelected)
        }
        // Handle separator items - skip to next item
        else if (selectedName === "-------- New FreeDView Ver --------" ||
                selectedName === "-------- FreeDView Exist in the events and in the main folder --------" ||
                selectedName === "-------- FreeDView Exist only in the events --------")
        {
            currentSelected_ = currentSelected +1
            fdvVerComboBox_id.currentIndex = currentSelected_
            return  // Don't emit signal for separator items
        }
        else
        {
            currentSelected_ = parseInt(currentSelected)
        }
        selectedFreeDViewVerIndex = parseInt(currentSelected_)
        // Emit signal to notify parent (TopLayout_zero) of version selection
        versionSelected(selectedFreeDViewVerIndex)
        setMinFrameValue(mainHeader_frameUnderThreshold, true)
    }
}


//-- fill the comboBox -----------------------
function fillComboBox(freeDViewVer_list)
{
    if (freeDViewVer_list !== undefined)
    {
        mainHeader_freeDViewVer_list = freeDViewVer_list
        
        // Check if first item is "All Render Versions" (our new default)
        if (mainHeader_freeDViewVer_list[0] === "All Render Versions")
        {
            // Set to index 0 (All render versions) and trigger selection
            fdvVerComboBox_id.currentIndex = 0
            comboBoxSelected(0)
        }
        else if (mainHeader_freeDViewVer_list[0] === "-------- New FreeDView Ver --------" ||
                mainHeader_freeDViewVer_list[0] === "-------- FreeDView Exist in the events and in the main folder --------" ||
                mainHeader_freeDViewVer_list[0] === "-------- FreeDView Exist only in the events --------")
        {
            fdvVerComboBox_id.currentIndex = 1
            comboBoxSelected(1)
        }
        else
        {
            // Default to index 0 (should be "All Render Versions" if list was properly populated)
            fdvVerComboBox_id.currentIndex = 0
            comboBoxSelected(0)
        }
    }

}

//-- reload (refresh) TableView --------------------------------
function reloadTableView()
{
    Logger.info("[UI] Reloading table view - clearing selection and refreshing data")
    
    // Set loading status immediately when reload button is clicked
    // Access isLoading property through tableViewLoader.item (which is TableviewHandlers)
    var loader = tableViewLoaderRef || (typeof tableViewLoader !== "undefined" ? tableViewLoader : null)
    if (loader && loader.item) {
        loader.item.isLoading = true
    }
    
    // Run Phase 4 (prepare-ui) and reload uiData.xml when reload button is clicked
    // This replaces the refresh button functionality
    if (typeof iniReader !== "undefined" && iniReader && typeof testerRunner !== "undefined" && testerRunner) {
        if (iniReader.isValid || iniReader.readINIFile()) {
            // Clear selection when reloading (row indices may change after refresh)
            // Access tableView through parent if available
            if (typeof tableViewLoader !== "undefined" && tableViewLoader && tableViewLoader.item) {
                if (typeof tableViewLoader.item.clearSelectedRowsArray === "function") {
                    tableViewLoader.item.clearSelectedRowsArray()
                }
                if (tableViewLoader.item.tableView) {
                    if (tableViewLoader.item.tableView.selection) {
                        tableViewLoader.item.tableView.selection.clear()
                    }
                    tableViewLoader.item.tableView.currentRow = -1
                }
            }
            
            // Get tester path and INI path
            var testerPath = iniReader.freeDViewTesterPath
            var iniPath = iniReader.iniFilePath
            
            if (testerPath) {
                // Run Phase 4 (prepare-ui) - data will reload automatically when it finishes
                testerRunner.runPrepareUI(testerPath, iniPath)
            }
        }
    } else {
        // Fallback: Just reload data if testerRunner not available
        if (typeof xmlDataModel !== "undefined" && xmlDataModel && typeof iniReader !== "undefined" && iniReader) {
            if (iniReader.readINIFile()) {
                xmlDataModel.loadData(iniReader.setTestResultsPath, "")
            }
        }
    }
    fillComboBox()
    setMinFrameValue(mainHeader_frameUnderThreshold, true)
}


//-- update the Min FrameValue ----------------------------
function updateMinFrameValue(value)
{
    Logger.debug("[UI] Frame threshold updated: " + value)
    mainHeader_frameUnderThreshold = value
    setMinFrameValue(value, true)
}

//-- when "+" button or "-" button is clicked change the min value of frameUnderThreshold --------------------
function changeValue(val)
{
    var newVal = parseFloat(mainHeader_frameUnderThreshold)
    if (val === "+")
    {
        newVal = newVal + 0.01
    }
    if (val === "-")
    {
        newVal = newVal - 0.01
    }

    mainHeader_frameUnderThreshold = Number((newVal).toFixed(3))
    mainHeader_frameUnderThreshold.toString()
    Logger.debug("[UI] Frame threshold adjusted: " + val + " → " + mainHeader_frameUnderThreshold)
    setMinFrameValue(mainHeader_frameUnderThreshold, true)
}


}
