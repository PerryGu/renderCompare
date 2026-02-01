
/**
 * @file TableviewTable.qml
 * @brief Table UI components (toolbar, statusbar, table, columns, delegates)
 * 
 * This component contains all the visual table elements:
 * - Toolbar with loading indicators and status
 * - Status bar with status messages
 * - Tooltip component
 * - Context menu for row actions
 * - TableView with all columns and delegates
 * - SortFilterProxyModel for sorting and filtering
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.2
import com.rendercompare 1.0
import Theme 1.0
import Logger 1.0

Item {
    id: tableContainer
    anchors.fill: parent
    
    // Properties to receive references from parent
    property var tableViewContainer: null
    // xmlDataModel, iniReader, testerRunner are context properties (available globally)
    // We don't declare them as local properties to avoid shadowing the context properties
    property var editDialog: null  // Will be set by parent (TableviewHandlers)
    property var confirmationDialog: null
    property string headerSearchText: ""  // Bound from parent (TableviewHandlers)
    property bool isLoading: false
    property string errorMessage: ""
    property string testRunnerStatus: ""
    property int processingProgress: -1
    property string processingMessage: ""
    property bool isTestProcessRunning: false
    property string statusBarTooltipText: ""
    property bool tooltipActive: false
    property var rowsInProgress: ({})
    property int contextMenuRowIndex: -1
    property int contextMenuColumnIndex: -1
    property string contextMenuStatus: ""
    property bool contextMenuShowTestRunnerOptions: false
    property var selectedRows: []
    
    // Expose components for external access
    property alias proxyModelInstance: proxyModelInstance
    property alias statusBarText: statusBarText
    property alias statusMessageTimer: statusMessageTimer
    property alias progressClearTimer: progressClearTimer
    property alias searchBox: searchBox
    property alias tableView: tableView
    
    // Expose functions
    function getColumnTitle(columnIndex) {
        switch(columnIndex) {
            case 0: return idColumn.title
            case 1: return thumbnailColumn.title
            case 2: return eventNameColumn.title
            case 3: return sportTypeColumn.title
            case 4: return stadiumColumn.title
            case 5: return categoryColumn.title
            case 6: return framesColumn.title
            case 7: return minValColumn.title
            case 8: return notesColumn.title
            case 9: return statusColumn.title
            default: return "Unknown Column"
        }
    }
    
    // Helper function to show context menu (for use from Component delegates)
    function showContextMenu(row, column, globalX, globalY, selectedRowIds, selectedRowCount, columnTitle, hasRenderedNotCompare, hasAnyNotReady, hasNotReadyOrRendered) {
        // Update context menu text
        if (selectedRowCount === 1) {
            contextMenuId.text = "ID: " + (selectedRowIds.length > 0 ? selectedRowIds[0] : "")
        } else {
            contextMenuId.text = "Selected: " + selectedRowCount + " row(s)"
        }
        contextMenuColumnName.text = "Column: " + columnTitle
        
        // Update context menu properties
        tableViewContainer.contextMenuShowTestRunnerOptions = selectedRowCount > 0
        
        if (hasRenderedNotCompare) {
            tableViewContainer.contextMenuStatus = "Rendered not compare"
        } else if (hasAnyNotReady) {
            tableViewContainer.contextMenuStatus = "Not Ready"
        } else if (hasNotReadyOrRendered) {
            tableViewContainer.contextMenuStatus = "Not Ready"
        } else {
            tableViewContainer.contextMenuStatus = ""
        }
        
        // Position context menu
        contextMenu.x = globalX + 5
        contextMenu.y = globalY + 5
        
        if (contextMenu.x + contextMenu.width > tableViewContainer.width) {
            contextMenu.x = tableViewContainer.width - contextMenu.width - 10
        }
        if (contextMenu.y + contextMenu.height > tableViewContainer.height) {
            contextMenu.y = tableViewContainer.height - contextMenu.height - 10
        }
        if (contextMenu.x < 0) contextMenu.x = 10
        if (contextMenu.y < 0) contextMenu.y = 10
        
        // Force property updates
        var dummy1 = tableViewContainer.contextMenuShowTestRunnerOptions
        var dummy2 = tableViewContainer.contextMenuStatus
        
        // Show context menu
        contextMenu.visible = true
    }
    
    // Helper function to hide context menu (for use from Component delegates)
    function hideContextMenu() {
        contextMenu.visible = false
    }
    
    function mapTableViewColumnToModelColumn(tableViewColumnIndex) {
        switch(tableViewColumnIndex) {
            case 0: return 0;  // ID
            case 1: return 9;  // Thumbnail
            case 2: return 1;  // Event Name
            case 3: return 2;  // Sport Type
            case 4: return 3;  // Stadium Name
            case 5: return 4;  // Category Name
            case 6: return 5;  // Number Of Frames
            case 7: return 6;  // Min Value
            case 8: return 7;  // Notes
            case 9: return 8;  // Status
            default: return -1;
        }
    }
    
    function isRowSelected(rowIndex) {
        for (var i = 0; i < selectedRows.length; i++) {
            if (selectedRows[i] === rowIndex) return true
        }
        return false
    }
    
    function addRowToSelection(rowIndex) {
        if (!isRowSelected(rowIndex)) {
            selectedRows.push(rowIndex)
        }
    }
    
    function removeRowFromSelection(rowIndex) {
        for (var i = selectedRows.length - 1; i >= 0; i--) {
            if (selectedRows[i] === rowIndex) {
                selectedRows.splice(i, 1)
                return
            }
        }
    }
    
    function clearSelectedRowsArray() {
        selectedRows = []
    }
    
    function setTooltip(text) {
        statusBarTooltipText = text
        tooltipActive = true
    }
    
    function clearTooltip() {
        statusBarTooltipText = ""
        tooltipActive = false
    }

    // Toolbar (converted from ApplicationWindow toolBar)
    Rectangle {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: Theme.primaryDark  // Dark blue matching the header bar with comboBox
        z: 10
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 20  // Move content down, closer to table header

            // Loading indicator
            Item {
                width: 20
                height: 20
                visible: isLoading
                BusyIndicator {
                    anchors.centerIn: parent
                    running: isLoading
                    width: 16
                    height: 16
                }
            }

            Text {
                id: statusText
                text: {
                    // Show tooltip if active (takes priority over everything else)
                    if (tooltipActive && statusBarTooltipText !== "") {
                        return statusBarTooltipText
                    }
                    // Show processing progress if available (regardless of isLoading state)
                    // This allows progress to remain visible even when Phase 4 finishes
                    if (processingProgress >= 0) {
                        if (processingMessage !== "") {
                            return processingMessage + " (" + processingProgress + "%)"
                        }
                        return "Processing (" + processingProgress + "%)"
                    } else if (isLoading) {
                        return "Updating table ..."
                    } else if (xmlDataModel && xmlDataModel.rowCount > 0) {
                        var totalRows = xmlDataModel.rowCount
                        var visibleRows = proxyModelInstance ? proxyModelInstance.count : totalRows
                        if (visibleRows < totalRows) {
                            return "Showing " + visibleRows + " of " + totalRows + " rows"
                        } else {
                            return totalRows + " rows loaded"
                        }
                    } else {
                        return "No data loaded"
                    }
                }
                color: Theme.textLight  // White text for visibility on dark blue background
                font.pixelSize: Theme.fontSizeMedium
            }
            
            // Stop button - visible only when processing
            Button {
                id: stopButton
                text: "Stop"
                visible: processingProgress >= 0
                enabled: processingProgress >= 0 && testerRunner
                Layout.leftMargin: 10
                onClicked: {
                    if (testerRunner) {
                        testerRunner.stop()
                        // Reset progress indicators
                        tableViewContainer.processingProgress = -1
                        tableViewContainer.processingMessage = ""
                        tableViewContainer.rowsInProgress = ({})
                        tableViewContainer.testRunnerStatus = "Cancelled by user"
                    }
                }
                
                style: ButtonStyle {
                    background: Rectangle {
                        implicitWidth: 70
                        implicitHeight: 30
                        color: control.pressed ? Theme.buttonPressed : (control.hovered ? Theme.buttonHovered : Theme.buttonDefault)
                        border.color: Theme.borderDark
                        border.width: 1
                        radius: 4
                    }
                    label: Text {
                        text: control.text
                        color: Theme.chartMark  // Orange text (matches floating menu)
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }
            
            // Timer to reset status message after auto-save
            Timer {
                id: statusMessageTimer
                interval: 3000
                onTriggered: {
                    // Reset to default status message
                    if (xmlDataModel && xmlDataModel.rowCount > 0) {
                        var totalRows = xmlDataModel.rowCount
                        var visibleRows = proxyModelInstance ? proxyModelInstance.count : totalRows
                        var searchText = headerSearchText !== "" ? headerSearchText : searchBox.text
                        if (searchText !== "") {
                            statusBarText.text = "Filtered: " + visibleRows + " of " + totalRows + " rows match \"" + searchText + "\""
                        } else {
                            statusBarText.text = "Total: " + totalRows + " rows | Double-click row for details"
                        }
                    }
                }
            }
            
            // Timer to clear row progress indicators after completion
            Timer {
                id: progressClearTimer
                interval: 2000  // 2 seconds delay to show final state
                repeat: false
                onTriggered: {
                    // Only clear progress bars if test processes are not running
                    // If test processes are still running, progress bars should remain
                    if (!tableViewContainer.isTestProcessRunning) {
                        tableViewContainer.rowsInProgress = {}
                    }
                }
            }

            // Lower search field - hidden, search functionality moved to upper search field in MainTableViewHeader
            TextField {
                id: searchBox
                visible: false  // Hidden - search moved to upper search field
                placeholderText: "Search... (Ctrl+F)"
                inputMethodHints: Qt.ImhNoPredictiveText
                Layout.preferredWidth: tableViewContainer.width / 5 * 2
            }
            
            // Refresh button - hidden, functionality moved to reload button in MainTableViewHeader
            Button {
                id: refreshButton
                visible: false  // Hidden - refresh functionality moved to top-left reload button
                text: "Refresh"
                Layout.leftMargin: 10
                enabled: iniReader && iniReader.isValid && testerRunner && xmlDataModel && !xmlDataModel.isLoading
                onClicked: {
                    // Functionality moved to reload button in MainTableViewHeader
                }
            }
        }
    }
    // Status bar (converted from ApplicationWindow statusBar)
    Rectangle {
        id: statusbar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: Theme.backgroundVeryLight
        z: 10
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            Text {
                id: statusBarText
                text: {
                    if (testRunnerStatus !== "") {
                        return testRunnerStatus  // Show test runner status if active
                    } else if (errorMessage !== "") {
                        return "Error: " + errorMessage
                    } else if (xmlDataModel && xmlDataModel.rowCount > 0) {
                        var totalRows = xmlDataModel.rowCount
                        var visibleRows = proxyModelInstance ? proxyModelInstance.count : totalRows
                        var searchText = headerSearchText !== "" ? headerSearchText : searchBox.text
                        if (searchText !== "") {
                            return "Filtered: " + visibleRows + " of " + totalRows + " rows match \"" + searchText + "\""
                        } else {
                            return "Total: " + totalRows + " rows | Double-click row for details"
                        }
                    } else {
                        return "Ready"
                    }
                }
                color: (errorMessage !== "" || (testRunnerStatus !== "" && testRunnerStatus.indexOf("failed") !== -1)) ? Theme.statusError : Theme.statusInfo
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }
    // Tooltip for column headers
    Rectangle {
        id: tooltip
        visible: false
        width: tooltipText.width + 10
        height: tooltipText.height + 10
        color: Theme.backgroundYellow
        border.color: Theme.borderYellow
        border.width: 1
        z: 1000
        
        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: ""
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.textDarkGray
        }
    }
    Rectangle {
        id: contextMenu
        visible: false
        width: Math.max(contextMenuColumn.width + 20, 200)
        height: contextMenuColumn.height + 20
        border.color: Theme.borderDark  // Dark blue border (matches floating menu)
        border.width: 2  // Border thickness
        radius: 10  // Rounded corners (matches floating menu)
        z: 1001
        
        // Dark gray gradient background (matches floating menu)
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.gradientTop }  // Top: lighter gray
            GradientStop { position: 1; color: Theme.gradientBottom }  // Bottom: darker gray
        }
        
        Column {
            id: contextMenuColumn
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 4
            width: parent.width - 20
            
            // Row ID at the top
            Text {
                id: contextMenuId
                text: ""
                font.bold: true
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.chartMark  // Orange text (matches floating menu)
                width: parent.width
            }
            
            // Separator line
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.textMediumGray  // Dark gray separator
            }
            
            // Column name
            Text {
                id: contextMenuColumnName
                text: ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.chartMark  // Orange text (matches floating menu)
                width: parent.width
            }
            
            // Separator line before menu items
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.textMediumGray  // Dark gray separator
                anchors.topMargin: 4
            }
            
            // Edit menu item
            Rectangle {
                width: parent.width
                height: 22  // Match floating menu item height
                color: editMenuItemMouseArea.containsMouse ? Theme.overlayChartMark : Theme.uiTransparent  // Semi-transparent orange on hover
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Edit"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                MouseArea {
                    id: editMenuItemMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // Get current row and column data
                        var row = contextMenuRowIndex
                        var column = contextMenuColumnIndex
                        
                        if (row >= 0 && proxyModel) {
                            var rowData = proxyModelInstance.get(row)
                            var columnTitle = getColumnTitle(column)
                            var currentValue = ""
                            
                            // Get current value based on column
                            switch(column) {
                                case 0: currentValue = rowData.id || ""; break
                                case 1: currentValue = rowData.thumbnailPath || ""; break
                                case 2: currentValue = rowData.eventName || ""; break
                                case 3: currentValue = rowData.sportType || ""; break
                                case 4: currentValue = rowData.stadiumName || ""; break
                                case 5: currentValue = rowData.categoryName || ""; break
                                case 6: currentValue = rowData.numberOfFrames || ""; break
                                case 7: currentValue = rowData.minValue || ""; break
                                case 8: currentValue = rowData.notes || ""; break
                                case 9: currentValue = rowData.status || ""; break
                                default: currentValue = "";
                            }
                            
                            // Show edit dialog
                            // Try multiple ways to access the dialog
                            var dialog = null
                            
                            // First try the direct property
                            if (editDialog) {
                                dialog = editDialog
                            }
                            // Then try through container
                            else if (tableViewContainer && tableViewContainer.dialogsComponent) {
                                dialog = tableViewContainer.dialogsComponent.editDialog
                            }
                            // Last resort: try accessing through parent
                            else if (parent && parent.dialogsComponent) {
                                dialog = parent.dialogsComponent.editDialog
                            }
                            
                            if (dialog && typeof dialog.show === "function") {
                                dialog.show(row, column, columnTitle, currentValue)
                            } else {
                                Logger.error("[TableviewTable] editDialog is null or show function not available!")
                            }
                        }
                        
                        // Close context menu
                        contextMenu.visible = false
                    }
                }
            }
            
            // Open in Explorer menu item
            Rectangle {
                width: parent.width
                height: 22  // Match floating menu item height
                color: openInExplorerMouseArea.containsMouse ? Theme.overlayChartMark : Theme.uiTransparent  // Semi-transparent orange on hover
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open in Explorer"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                MouseArea {
                    id: openInExplorerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // Get current row
                        var row = contextMenuRowIndex
                        
                        if (row >= 0 && proxyModelInstance) {
                            // Map proxy model row to source model row
                            var sourceRow = proxyModelInstance.mapProxyRowToSource(row)
                            if (sourceRow >= 0) {
                                // Get testKey from xmlDataModel
                                var testKey = ""
                                if (typeof xmlDataModel !== "undefined" && xmlDataModel) {
                                    testKey = xmlDataModel.getTestKey(sourceRow) || ""
                                }
                                
                                if (testKey && testKey !== "") {
                                    // Get test results path from iniReader (this is where testSets_results is)
                                    var testResultsPath = ""
                                    if (typeof iniReader !== "undefined" && iniReader && iniReader.isValid) {
                                        testResultsPath = iniReader.setTestResultsPath || ""
                                    }
                                    
                                    // Construct full path
                                    var fullPath = ""
                                    if (testResultsPath) {
                                        // Normalize path separators
                                        var normalizedTestKey = testKey.replace(/\//g, "\\")
                                        var normalizedTestResultsPath = testResultsPath.replace(/\//g, "\\")
                                        
                                        // Remove trailing backslashes from base path
                                        normalizedTestResultsPath = normalizedTestResultsPath.replace(/\\+$/, "")
                                        // Remove leading backslashes from testKey
                                        normalizedTestKey = normalizedTestKey.replace(/^\\+/, "")
                                        
                                        // Combine paths: testResultsPath + testKey
                                        // testResultsPath points to testSets_results, testKey is relative from there
                                        fullPath = normalizedTestResultsPath + "\\" + normalizedTestKey
                                        
                                        // Convert to file:// URL for Qt.openUrlExternally
                                        // On Windows, we need to use file:/// with forward slashes
                                        var fileUrl = "file:///" + fullPath.replace(/\\/g, "/")
                                        
                                        // Open folder in Explorer
                                        Qt.openUrlExternally(fileUrl)
                                    } else {
                                        Logger.error("[TableviewTable] Cannot open in Explorer - testResultsPath not available from iniReader")
                                        // Show error dialog if available
                                        if (tableViewContainer && tableViewContainer.dialogsComponent && tableViewContainer.dialogsComponent.errorDialog) {
                                            tableViewContainer.dialogsComponent.errorDialog.show("Cannot open folder: Test results path not configured. Please check your INI file.")
                                        }
                                    }
                                } else {
                                    Logger.error("[TableviewTable] Cannot open in Explorer - testKey not available for row: " + sourceRow)
                                    // Show error dialog if available
                                    if (tableViewContainer && tableViewContainer.dialogsComponent && tableViewContainer.dialogsComponent.errorDialog) {
                                        tableViewContainer.dialogsComponent.errorDialog.show("Cannot open folder: Test path not found for this row.")
                                    }
                                }
                            }
                        }
                        
                        // Close context menu
                        contextMenu.visible = false
                    }
                }
            }
            
            // Separator before test runner options
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.textMediumGray  // Dark gray separator
                anchors.topMargin: 4
                visible: tableViewContainer.contextMenuShowTestRunnerOptions
            }
            
            // Run All Phases menu item (always available for any selected row)
            Rectangle {
                id: runAllMenuItem
                width: parent.width
                height: 22  // Match floating menu item height
                visible: tableViewContainer.contextMenuShowTestRunnerOptions
                color: runAllMouseArea.containsMouse ? Theme.overlayChartMark : Theme.uiTransparent  // Semi-transparent orange on hover
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Run All Phases" + (tableViewContainer.selectedRows.length > 1 ? " (" + tableViewContainer.selectedRows.length + " tests)" : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                MouseArea {
                    id: runAllMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        contextMenu.visible = false
                        confirmationDialog.showRunAll()
                    }
                }
            }
            
            // Run Phase 3 menu item (always available for any selected row, like Run All Phases)
            Rectangle {
                id: runPhase3MenuItem
                width: parent.width
                height: 22  // Match floating menu item height
                visible: tableViewContainer.contextMenuShowTestRunnerOptions
                color: runPhase3MouseArea.containsMouse ? Theme.overlayChartMark : Theme.uiTransparent  // Semi-transparent orange on hover
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Run Phase 3" + (tableViewContainer.selectedRows.length > 1 ? " (" + tableViewContainer.selectedRows.length + " tests)" : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                MouseArea {
                    id: runPhase3MouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        contextMenu.visible = false
                        confirmationDialog.showRunPhase3()
                    }
                }
            }
        }
    }
    TableView {
        id: tableView
        anchors.top: toolbar.bottom
        
        // Track mouse position over headers for tooltip
        property bool mouseOverHeader: false
        anchors.bottom: statusbar.top
        anchors.left: parent.left
        anchors.right: parent.right
        
        frameVisible: false
        sortIndicatorVisible: true
        
        // MouseArea to detect hover over header area (top 50 pixels) only
        // Only active when mouse is in header area to avoid interfering with row tooltips
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50  // Only cover header area (top 50 pixels)
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with table interactions
            propagateComposedEvents: true
            
            onEntered: {
                // Show tooltip when mouse enters header area
                if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                    if (typeof tableViewContainer.setTooltip === "function") {
                        tableViewContainer.setTooltip("Click for new sort")
                    }
                }
            }
            onExited: {
                // Clear tooltip when mouse leaves header area
                // Row tooltips will handle their own display when mouse moves to rows
                if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                    if (typeof tableViewContainer.clearTooltip === "function") {
                        tableViewContainer.clearTooltip()
                    }
                }
            }
        }

        Layout.minimumWidth: 400
        Layout.minimumHeight: 240
        Layout.preferredWidth: 600
        Layout.preferredHeight: 400

        Component {
            id: thumbnailDelegate
            Item {
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: { top: 5; bottom: 5; left: 10; right: 10 }
                    height: 55
                    width: thumbnailColumn.width - 20
                    fillMode: Image.PreserveAspectFit
                    cache: true
                    asynchronous: true
                    source: styleData.value ? (styleData.value.startsWith("file://") ? styleData.value : "file:///" + styleData.value.replace(/\\/g, "/")) : ""
                }
            }
        }

        Component {
            id: statusDelegate
            Item {
                // Circular progress bar for status column when row is being processed
                CircularProgressbar {
                    id: rowProgressBar
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: {
                        if (!proxyModel || !xmlDataModel) return false
                        var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(styleData.row) : -1
                        if (sourceRow < 0) return false
                        var testKey = xmlDataModel.getTestKey(sourceRow) || ""
                        var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                        return normalizedTestKey !== "" && tableViewContainer.rowsInProgress && tableViewContainer.rowsInProgress.hasOwnProperty(normalizedTestKey)
                    }
                    isActive: visible
                    
                    currentValue: {
                        if (!proxyModel || !xmlDataModel) return 0
                        var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(styleData.row) : -1
                        if (sourceRow < 0) return 0
                        var testKey = xmlDataModel.getTestKey(sourceRow) || ""
                        var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                        if (normalizedTestKey !== "" && tableViewContainer.rowsInProgress && tableViewContainer.rowsInProgress.hasOwnProperty(normalizedTestKey)) {
                            var info = tableViewContainer.rowsInProgress[normalizedTestKey]
                            if (info && typeof info.progress !== "undefined") {
                                return info.progress
                            }
                        }
                        return 0
                    }
                    
                    progressText: {
                        if (!proxyModel || !xmlDataModel) return "Processing"
                        var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(styleData.row) : -1
                        if (sourceRow < 0) return "Processing"
                        var testKey = xmlDataModel.getTestKey(sourceRow) || ""
                        var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                        if (normalizedTestKey !== "" && tableViewContainer.rowsInProgress && tableViewContainer.rowsInProgress.hasOwnProperty(normalizedTestKey)) {
                            var info = tableViewContainer.rowsInProgress[normalizedTestKey]
                            if (info) {
                                if (info.progress >= 100) {
                                    return "Finished"
                                }
                                if (info.text) {
                                    return info.text
                                }
                            }
                        }
                        return "Processing"
                    }
                    
                    textColor: {
                        if (!proxyModel || !xmlDataModel) return Theme.statusErrorAlt
                        var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(styleData.row) : -1
                        if (sourceRow < 0) return Theme.statusErrorAlt
                        var testKey = xmlDataModel.getTestKey(sourceRow) || ""
                        var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                        if (normalizedTestKey !== "" && tableViewContainer.rowsInProgress && tableViewContainer.rowsInProgress.hasOwnProperty(normalizedTestKey)) {
                            var info = tableViewContainer.rowsInProgress[normalizedTestKey]
                            if (info && (info.progress >= 100 || info.text === "Finish")) {
                                return Theme.statusSuccessAlt
                            } else if (info && info.text === "ERROR") {
                                return Theme.statusErrorAlt
                            }
                        }
                        return Theme.statusErrorAlt
                    }
                }
                
                // Status icon display (shown when not in progress)
                Image {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 8, parent.height - 8, 46)  // Reduced by 15% from current (54 * 0.85 = 45.9, rounded to 46)
                    height: width
                    fillMode: Image.PreserveAspectFit
                    visible: !rowProgressBar.visible
                    source: {
                        var statusValue = (styleData.value !== undefined ? String(styleData.value) : "")
                        if (statusValue === "Ready") {
                            return "/images/ready.png"
                        } else if (statusValue === "Rendered not compare") {
                            return "/images/rendered_not_compare.png"
                        } else if (statusValue === "Not Ready") {
                            return "/images/not_ready.png"
                        } else {
                            return ""
                        }
                    }
                }
                
                // MouseArea to handle right-click context menu (same as itemDelegate)
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    propagateComposedEvents: true
                    
                    onPressed: {
                        // Forward the event to the parent itemDelegate's MouseArea handler
                        // We need to trigger the same context menu logic
                        if (mouse.button === Qt.RightButton) {
                            var row = styleData.row
                            var column = styleData.column
                            var globalPos = mapToItem(tableViewContainer, mouse.x, mouse.y)
                            
                            // Ensure the hovered row is selected
                            if (!tableViewContainer.isRowSelected(row)) {
                                tableViewContainer.addRowToSelection(row)
                                tableView.selection.select(row)
                            }
                            tableView.currentRow = row
                            
                            // Store row and column for edit dialog
                            tableViewContainer.contextMenuRowIndex = row
                            tableViewContainer.contextMenuColumnIndex = column
                            
                            // Check if ANY of the selected rows can run test runner commands
                            var hasNotReadyOrRendered = false
                            var hasRenderedNotCompare = false
                            var hasAnyNotReady = false
                            var selectedRowIds = []
                            var rowsToCheck = tableViewContainer.selectedRows.length
                            
                            for (var i = 0; i < rowsToCheck; i++) {
                                var selectedRow = tableViewContainer.selectedRows[i]
                                if (selectedRow >= 0 && selectedRow !== undefined && proxyModel) {
                                    var rowData = proxyModelInstance.get(selectedRow)
                                    if (rowData) {
                                        var rowId = rowData.id || ""
                                        var status = rowData.status || ""
                                        selectedRowIds.push(rowId)
                                        
                                        if (status === "Not Ready" || status === "Rendered not compare") {
                                            hasNotReadyOrRendered = true
                                        }
                                        if (status === "Not Ready") {
                                            hasAnyNotReady = true
                                        }
                                        if (status === "Rendered not compare") {
                                            hasRenderedNotCompare = true
                                        }
                                    }
                                }
                            }
                            
                            var selectedRowCount = tableViewContainer.selectedRows.length
                            // Get column title - need to access through tableViewContainer's function
                            var columnTitle = ""
                            switch(column) {
                                case 0: columnTitle = idColumn.title; break
                                case 1: columnTitle = thumbnailColumn.title; break
                                case 2: columnTitle = eventNameColumn.title; break
                                case 3: columnTitle = sportTypeColumn.title; break
                                case 4: columnTitle = stadiumColumn.title; break
                                case 5: columnTitle = categoryColumn.title; break
                                case 6: columnTitle = framesColumn.title; break
                                case 7: columnTitle = minValColumn.title; break
                                case 8: columnTitle = notesColumn.title; break
                                case 9: columnTitle = statusColumn.title; break
                                default: columnTitle = "Unknown Column"; break
                            }
                            
                            // Store row and column for edit dialog
                            tableViewContainer.contextMenuRowIndex = row
                            tableViewContainer.contextMenuColumnIndex = column
                            
                            // Use helper function to show context menu (Components can't access parent scope directly)
                            tableContainer.showContextMenu(row, column, globalPos.x, globalPos.y, selectedRowIds, selectedRowCount, columnTitle, hasRenderedNotCompare, hasAnyNotReady, hasNotReadyOrRendered)
                        } else {
                            // Left-click - hide context menu
                            tableContainer.hideContextMenu()
                        }
                    }
                }
            }
        }

        headerDelegate: Rectangle {
            id: headerRect
            height: 50  // Increased height for more prominent header
            color: Theme.primaryAccent  // Green background matching the app theme
            border.color: Theme.borderAccentDark  // Slightly darker green for border
            border.width: 1
            
            property string tooltipText: {
                var colTitle = styleData.value
                if (colTitle === "ID") return "Unique identifier for each event"
                if (colTitle === "Thumbnail") return "Preview image for the event"
                if (colTitle === "Event Name") return "Name of the event"
                if (colTitle === "Sport Type") return "Type of sport"
                if (colTitle === "Stadium Name") return "Name of the stadium"
                if (colTitle === "Category Name") return "Category classification"
                if (colTitle === "Number Of Frames") return "Total number of frames in the event"
                if (colTitle === "Min Value") return "Minimum value across all frames"
                if (colTitle === "Notes") return "Additional notes or comments"
                if (colTitle === "Status") return "Status of the event"
                return ""
            }
            
            Text {
                anchors.centerIn: parent
                text: styleData.value
                font.bold: false  // Less bold text as requested
                font.pixelSize: Theme.fontSizeMedium  // Slightly larger font to match increased height
                color: Theme.primaryDark  // Dark blue text matching the comboBox border color
            }
            
            // Tooltip MouseArea - use propagateComposedEvents to allow clicks through
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                
                onEntered: {
                    // Show tooltip "Click for new sort" in status bar
                    if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                        if (typeof tableViewContainer.setTooltip === "function") {
                            tableViewContainer.setTooltip("Click for new sort")
                        }
                    }
                }
                onExited: {
                    // Clear tooltip from status bar
                    if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                        if (typeof tableViewContainer.clearTooltip === "function") {
                            tableViewContainer.clearTooltip()
                        }
                    }
                }
                
                // Allow clicks to pass through to TableView for sorting
                onClicked: {
                    mouse.accepted = false
                }
                onPressed: {
                    mouse.accepted = false
                }
                onReleased: {
                    mouse.accepted = false
                }
            }
        }
        

        TableViewColumn {
            id: idColumn
            title: "ID"
            role: "id"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(0) : 50
        }
        
        TableViewColumn {
            id: thumbnailColumn
            role: "thumbnailPath"
            title: "Thumbnail"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(1) : 200
            delegate: thumbnailDelegate
        }

        TableViewColumn {
            id: eventNameColumn
            title: "Event Name"
            role: "eventName"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(2) : 300
        }

        TableViewColumn {
            id: sportTypeColumn
            title: "Sport Type"
            role: "sportType"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(3) : 150
        }

        TableViewColumn {
            id: stadiumColumn
            title: "Stadium Name"
            role: "stadiumName"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(4) : 200
        }

        TableViewColumn {
            id: categoryColumn
            title: "Category Name"
            role: "categoryName"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(5) : 200
        }

        TableViewColumn {
            id: framesColumn
            title: "Number Of Frames"
            role: "numberOfFrames"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(6) : 150
        }

        TableViewColumn {
            id: minValColumn
            title: "Min Value"
            role: "minValue"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(7) : 150
        }

        TableViewColumn {
            id: notesColumn
            title: "Notes"
            role: "notes"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(8) : 150
        }

        TableViewColumn {
            id: statusColumn
            title: "Status"
            role: "status"
            movable: false
            resizable: true
            width: xmlDataModel && tableView ? tableView.viewport.width * xmlDataModel.getColumnWidthRatio(9) : 80
            delegate: statusDelegate
        }

        rowDelegate: Rectangle {
            id: rowRect
            height: 65
            
            property bool isHovered: false
            
            color: {
                if (isHovered) {
                    return Theme.overlayChartMark  // Semi-transparent orange (same as playback speed menu)
                } else if (styleData.selected) {
                    return Theme.overlayChartMark  // Semi-transparent orange (same as playback speed menu)
                } else if (styleData.alternate) {
                    return Theme.backgroundLightGray
                } else {
                    return Theme.backgroundPaleBlue
                }
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: rowRect.isHovered = true
                onExited: rowRect.isHovered = false
            }
        }

        itemDelegate: Item {
            // Regular text display for all columns except status (which has its own delegate)
            Text {
                anchors.fill: parent
                anchors.margins: 4
                text: styleData.value !== undefined ? styleData.value : ""
                color: styleData.selected ? Theme.primaryAccent : "black"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            // MouseArea handles row selection and click events
            // Uses onPressed (not onClicked) to ensure it fires on every click,
            // even when clicking the same row multiple times
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                
                onEntered: {
                    // Show tooltip for row interaction
                    if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                        if (typeof tableViewContainer.setTooltip === "function") {
                            tableViewContainer.setTooltip("Click to select row | Double-click to load test")
                        }
                    }
                }
                onExited: {
                    // Clear tooltip when mouse leaves row
                    if (typeof tableViewContainer !== "undefined" && tableViewContainer) {
                        if (typeof tableViewContainer.clearTooltip === "function") {
                            tableViewContainer.clearTooltip()
                        }
                    }
                }
                
                
                // Timer to delay selection logic for left-clicks (to allow double-click to be recognized first)
                Timer {
                    id: selectionDelayTimer
                    interval: 200  // Delay slightly to allow double-click recognition
                    repeat: false
                    property int pendingRow: -1
                    property bool pendingCtrlPressed: false
                    onTriggered: {
                        if (pendingRow >= 0) {
                            var row = pendingRow
                            var ctrlPressed = pendingCtrlPressed
                            
                            if (ctrlPressed) {
                                // Ctrl+Click: Toggle selection for this row
                                if (tableViewContainer.isRowSelected(row)) {
                                    // Row is already selected, remove it
                                    Logger.debug("[UI] Table row deselected (Ctrl+click): row " + row)
                                    tableViewContainer.removeRowFromSelection(row)
                                    // Rebuild the selection from our selectedRows array
                                    tableView.selection.clear()
                                    if (tableViewContainer.selectedRows.length > 0) {
                                        // Select all remaining rows
                                        for (var j = 0; j < tableViewContainer.selectedRows.length; j++) {
                                            tableView.selection.select(tableViewContainer.selectedRows[j])
                                        }
                                        tableView.currentRow = tableViewContainer.selectedRows[tableViewContainer.selectedRows.length - 1]
                                    } else {
                                        tableView.currentRow = -1
                                    }
                                } else {
                                    // Row is not selected, add it
                                    Logger.debug("[UI] Table row selected (Ctrl+click): row " + row)
                                    tableViewContainer.addRowToSelection(row)
                                    tableView.selection.select(row)
                                    tableView.currentRow = row
                                }
                            } else {
                                // Normal click: Clear all and select only this row
                                Logger.debug("[UI] Table row selected: row " + row)
                                tableView.selection.clear()
                                tableViewContainer.clearSelectedRowsArray()
                                tableViewContainer.addRowToSelection(row)
                                tableView.currentRow = row
                                tableView.selection.select(row)
                            }
                            
                            pendingRow = -1
                        }
                    }
                }
                                // Click handler - fires on every press, even same row
                onPressed: {
                    var row = styleData.row
                    var column = styleData.column
                    
                    // Handle right-click for context menu
                    if (mouse.button === Qt.RightButton) {
                        
                        // Ensure the hovered row is selected (add to selection if not already selected)
                        // This preserves multi-selection instead of clearing it
                        if (!tableViewContainer.isRowSelected(row)) {
                            tableViewContainer.addRowToSelection(row)
                            tableView.selection.select(row)
                        }
                        tableView.currentRow = row
                        
                        // Store row and column for edit dialog (use hovered row for edit)
                        contextMenuRowIndex = row
                        contextMenuColumnIndex = column
                        
                        // Check if ANY of the selected rows can run test runner commands
                        // Use selectedRows array directly (it's updated after adding the row above)
                        var hasNotReadyOrRendered = false
                        var hasRenderedNotCompare = false
                        var hasAnyNotReady = false
                        var selectedRowIds = []
                        
                        // Make sure we're checking all currently selected rows (including the one we just added)
                        var rowsToCheck = tableViewContainer.selectedRows.length
                        
                        for (var i = 0; i < rowsToCheck; i++) {
                            var selectedRow = tableViewContainer.selectedRows[i]
                            if (selectedRow >= 0 && selectedRow !== undefined && proxyModel) {
                                var rowData = proxyModelInstance.get(selectedRow)
                                if (rowData) {
                                    var rowId = rowData.id || ""
                                    var status = rowData.status || ""
                                    selectedRowIds.push(rowId)
                                    
                                    // Check status - must match exactly (case-sensitive)
                                    if (status === "Not Ready" || status === "Rendered not compare") {
                                        hasNotReadyOrRendered = true
                                    }
                                    if (status === "Not Ready") {
                                        hasAnyNotReady = true
                                    }
                                    if (status === "Rendered not compare") {
                                        hasRenderedNotCompare = true
                                    }
                                } else {
                                }
                            }
                        }
                        
                        // Determine menu visibility based on selected rows
                        var selectedRowCount = tableViewContainer.selectedRows.length
                        
                        // Get column title for the hovered row (used for edit)
                        var columnTitle = getColumnTitle(column)
                        
                        // Update context menu content
                        if (selectedRowCount === 1) {
                            contextMenuId.text = "ID: " + (selectedRowIds.length > 0 ? selectedRowIds[0] : "")
                        } else {
                            contextMenuId.text = "Selected: " + selectedRowCount + " row(s)"
                        }
                        contextMenuColumnName.text = "Column: " + columnTitle
                        
                        // Determine if test runner options should be shown
                        // Show options if we have at least one selected row (regardless of status)
                        // This allows running commands on any selected row
                        tableViewContainer.contextMenuShowTestRunnerOptions = selectedRowCount > 0
                        
                        // Set status for menu item visibility - "Run Phase 3" shows if ANY row is "Rendered not compare"
                        // "Run All Phases" shows for all rows (always visible if contextMenuShowTestRunnerOptions is true)
                        if (hasRenderedNotCompare) {
                            tableViewContainer.contextMenuStatus = "Rendered not compare"
                        } else if (hasAnyNotReady) {
                            tableViewContainer.contextMenuStatus = "Not Ready"
                        } else if (hasNotReadyOrRendered) {
                            // Some rows can run, but we already set status above
                            tableViewContainer.contextMenuStatus = "Not Ready"
                        } else {
                            // No rows with "Not Ready" or "Rendered not compare", but we still show options
                            // Set status to empty or "Ready" - menu items will still show
                            tableViewContainer.contextMenuStatus = ""
                        }
                        
                        // Position menu at mouse cursor
                        // Convert mouse position to global coordinates
                        var globalPos = mapToItem(tableViewContainer, mouse.x, mouse.y)
                        contextMenu.x = globalPos.x + 5
                        contextMenu.y = globalPos.y + 5
                        
                        // Ensure menu stays within window bounds
                        if (contextMenu.x + contextMenu.width > tableViewContainer.width) {
                            contextMenu.x = tableViewContainer.width - contextMenu.width - 10
                        }
                        if (contextMenu.y + contextMenu.height > tableViewContainer.height) {
                            contextMenu.y = tableViewContainer.height - contextMenu.height - 10
                        }
                        if (contextMenu.x < 0) contextMenu.x = 10
                        if (contextMenu.y < 0) contextMenu.y = 10
                        
                        // Force property updates by accessing them (triggers bindings)
                        var dummy1 = tableViewContainer.contextMenuShowTestRunnerOptions
                        var dummy2 = tableViewContainer.contextMenuStatus
                        
                        // Show context menu (visibility bindings should update)
                        contextMenu.visible = true
                    } else {
                        // Left-click handler - fires on every press, even same row
                        var row = styleData.row
                        var ctrlPressed = (mouse.modifiers & Qt.ControlModifier)
                        
                        // Hide context menu on left-click
                        contextMenu.visible = false
                        
                        if (ctrlPressed) {
                            // Ctrl+Click: Toggle selection for this row
                            if (tableViewContainer.isRowSelected(row)) {
                                // Row is already selected, remove it
                                tableViewContainer.removeRowFromSelection(row)
                                // Rebuild the selection from our selectedRows array
                                tableView.selection.clear()
                                if (tableViewContainer.selectedRows.length > 0) {
                                    // Select all remaining rows
                                    for (var j = 0; j < tableViewContainer.selectedRows.length; j++) {
                                        tableView.selection.select(tableViewContainer.selectedRows[j])
                                    }
                                    tableView.currentRow = tableViewContainer.selectedRows[tableViewContainer.selectedRows.length - 1]
                                } else {
                                    tableView.currentRow = -1
                                }
                            } else {
                                // Row is not selected, add it
                                tableViewContainer.addRowToSelection(row)
                                tableView.selection.select(row)
                                tableView.currentRow = row
                            }
                        } else {
                            // Normal click: Clear all and select only this row
                            tableView.selection.clear()
                            tableViewContainer.clearSelectedRowsArray()
                            tableViewContainer.addRowToSelection(row)
                            tableView.currentRow = row
                            tableView.selection.select(row)
                        }
                    }
                }
                
                // Double-click handler - fires on double-click gesture
                onDoubleClicked: {
                    // Hide context menu on double-click
                    contextMenu.visible = false
                    
                    var row = styleData.row
                    var ctrlPressed = (mouse.modifiers & Qt.ControlModifier)
                    
                    if (!ctrlPressed) {
                        // Normal double-click: Clear all and select only this row
                        tableView.selection.clear()
                        tableViewContainer.clearSelectedRowsArray()
                        tableViewContainer.addRowToSelection(row)
                        tableView.currentRow = row
                        tableView.selection.select(row)
                        
                        // Emit signal for TopLayout_zero.qml
                        var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(row) : row
                        Logger.info("[UI] Table row double-clicked: row " + row + " (source row: " + sourceRow + ")")
                        tableViewContainer.rowDoubleClicked(sourceRow)
                    } else {
                        Logger.debug("[UI] Table row Ctrl+double-clicked: row " + row + " (toggle selection)")
                    }
                    // If Ctrl+Double-click, treat it like Ctrl+Click (toggle selection)
                    // The onPressed handler already handles this, so we don't need to do anything here
                }
            }
        }

        model: SortFilterProxyModel {
            id: proxyModelInstance
            // Access context property directly (just like original file did)
            // Context properties are available globally, so we can use them directly
            source: xmlDataModel

            // Sort configuration - bound to table's sort indicator
            sortOrder: tableView.sortIndicatorOrder  // Ascending or descending
            sortCaseSensitivity: Qt.CaseInsensitive  // Case-insensitive sorting
            sortRole: {
                // Get the role name of the currently sorted column
                var col = tableView.getColumn(tableView.sortIndicatorColumn)
                return col ? col.role : ""
            }

            // Filter configuration - global search across all columns
            // Use headerSearchText from upper search field, fallback to searchBox for backward compatibility
            // Use a function binding to ensure it updates when headerSearchText changes
            filterString: {
                var searchText = headerSearchText !== "" ? headerSearchText : (searchBox && searchBox.text !== "" ? searchBox.text : "")
                return searchText !== "" ? "*" + searchText + "*" : "*"
            }
            filterSyntax: SortFilterProxyModel.Wildcard  // Use wildcard matching
            filterCaseSensitivity: Qt.CaseInsensitive  // Case-insensitive search
            dynamicSortFilter: true  // Automatically re-sort/filter when data changes
            
            Component.onCompleted: {
                // Proxy model initialized
            }
        }
    }
    
    Component.onCompleted: {
        // Context properties (xmlDataModel, iniReader, testerRunner) are available globally
        // No need to set them - they're accessible directly
        
        // Set object/array properties from parent container
        if (tableViewContainer) {
            rowsInProgress = tableViewContainer.rowsInProgress || ({})
            selectedRows = tableViewContainer.selectedRows || []
        }
    }

}
