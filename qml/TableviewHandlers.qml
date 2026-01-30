/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

/**
 * @file TableviewHandlers.qml
 * @brief Main container with logic, functions, and data connections
 * 
 * This component orchestrates the table view by:
 * - Managing state properties (loading, errors, selection)
 * - Handling keyboard shortcuts
 * - Loading TableviewDialogs and TableviewTable as child components
 * - Connecting to C++ backend signals (iniReader, xmlDataModel, testerRunner)
 * - Providing Component.onCompleted initialization
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.2
import com.rendercompare 1.0
import Theme 1.0
import Logger 1.0

Item {
    id: tableViewContainer
    anchors.fill: parent
    
    // Signals expected by TopLayout_zero.qml
    signal rowDoubleClicked(int rowIndex)
    signal dataLoaded()
    
    // Expose proxyModel so parent components can access it for filtering
    property alias proxyModel: tableComponent.proxyModelInstance
    
    // Expose dialogs component so child components can access it
    property alias dialogsComponent: dialogsComponent
    
    // Expose tooltip functions from tableComponent
    function setTooltip(text) {
        if (tableComponent && typeof tableComponent.setTooltip === "function") {
            tableComponent.setTooltip(text)
        }
    }
    
    function clearTooltip() {
        if (tableComponent && typeof tableComponent.clearTooltip === "function") {
            tableComponent.clearTooltip()
        }
    }
    
    // Property to receive search text from upper search field (MainTableViewHeader)
    // This property is set by TopLayout_zero.qml when searchText changes in MainTableViewHeader
    property string headerSearchText: ""
    
    // State properties
    property bool isLoading: false
    property string errorMessage: ""
    property bool hasUnsavedChanges: false
    property string testRunnerStatus: ""  // Status message from test runner
    property int processingProgress: -1  // Progress percentage (-1 means no progress info)
    property string processingMessage: ""  // Progress message
    property bool isTestProcessRunning: false
    property string statusBarTooltipText: ""
    property bool tooltipActive: false
    property var rowsInProgress: ({})
    property int contextMenuRowIndex: -1
    property int contextMenuColumnIndex: -1
    property string contextMenuStatus: ""
    property bool contextMenuShowTestRunnerOptions: false
    property var selectedRows: []
    property int selectedRowIndex: -1
    
    // Function to clear selected rows array
    function clearSelectedRowsArray() {
        selectedRows = []
    }
    
    // Function to check if a row is selected
    function isRowSelected(rowIndex) {
        return selectedRows.indexOf(rowIndex) !== -1
    }
    
    // Function to add a row to selection
    function addRowToSelection(rowIndex) {
        if (!isRowSelected(rowIndex)) {
            selectedRows.push(rowIndex)
        }
    }
    
    // Function to remove a row from selection
    function removeRowFromSelection(rowIndex) {
        for (var i = selectedRows.length - 1; i >= 0; i--) {
            if (selectedRows[i] === rowIndex) {
                selectedRows.splice(i, 1)
                return
            }
        }
    }
    
    // C++ backend references (context properties from main.cpp)
    // Context properties are available globally - don't declare local properties to avoid shadowing
    // Access them directly: xmlDataModel, iniReader, testerRunner
    
    // Keyboard shortcuts
    Item {
        id: keyboardHandler
        anchors.fill: parent
        focus: true
        
        Keys.onPressed: {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                // Ctrl+F is handled by parent (TopLayout_zero) to focus upper search field
                event.accepted = false  // Let parent handle it
            } else if (event.key === Qt.Key_Escape) {
                // Close context menu if visible, otherwise clear search
                if (tableComponent && tableComponent.contextMenu && tableComponent.contextMenu.visible) {
                    tableComponent.contextMenu.visible = false
                    event.accepted = true
                } else {
                    // Clear search in upper search field (handled by parent)
                    event.accepted = true
                }
            }
        }
    }
    
    // Load TableviewDialogs component
    TableviewDialogs {
        id: dialogsComponent
        anchors.fill: parent
        // High z-order to ensure dialogs appear above the table
        // Dialogs themselves also have high z-orders (10002+) when visible
        z: 10000
        tableViewContainer: tableViewContainer
        proxyModelInstance: tableComponent.proxyModelInstance
        statusBarText: tableComponent.statusBarText
        statusMessageTimer: tableComponent.statusMessageTimer
        hasUnsavedChanges: hasUnsavedChanges
        mapTableViewColumnToModelColumn: tableComponent.mapTableViewColumnToModelColumn
        // Don't pass context properties - they're available globally in QML
        // Passing them as properties can cause binding issues
    }
    
    // Load TableviewTable component
    TableviewTable {
        id: tableComponent
        anchors.fill: parent
        // Keep z-order low so dialogs appear above it
        z: 0
        tableViewContainer: tableViewContainer
        // Bind editDialog and confirmationDialog directly - QML will handle the binding
        editDialog: dialogsComponent ? dialogsComponent.editDialog : null
        confirmationDialog: dialogsComponent ? dialogsComponent.confirmationDialog : null
        headerSearchText: tableViewContainer.headerSearchText
        isLoading: tableViewContainer.isLoading
        errorMessage: tableViewContainer.errorMessage
        testRunnerStatus: testRunnerStatus
        processingProgress: tableViewContainer.processingProgress
        processingMessage: tableViewContainer.processingMessage
        isTestProcessRunning: tableViewContainer.isTestProcessRunning
        statusBarTooltipText: statusBarTooltipText
        tooltipActive: tooltipActive
        contextMenuRowIndex: contextMenuRowIndex
        contextMenuColumnIndex: contextMenuColumnIndex
        contextMenuStatus: contextMenuStatus
        contextMenuShowTestRunnerOptions: contextMenuShowTestRunnerOptions
        
        Component.onCompleted: {
            // Set C++ backend objects explicitly to avoid binding loops
            xmlDataModel = tableViewContainer.xmlDataModel
            iniReader = tableViewContainer.iniReader
            testerRunner = tableViewContainer.testerRunner
            
            // Set object/array properties explicitly to avoid binding loops
            rowsInProgress = tableViewContainer.rowsInProgress
            selectedRows = tableViewContainer.selectedRows
        }
    }

        Component.onCompleted: {
            // Set C++ backend objects from context properties (explicit assignment breaks binding loops)
            var ctxXmlDataModel = typeof xmlDataModel !== "undefined" ? xmlDataModel : null
            var ctxIniReader = typeof iniReader !== "undefined" ? iniReader : null
            var ctxTesterRunner = typeof testerRunner !== "undefined" ? testerRunner : null
            
            // Explicitly assign to break binding loops
            xmlDataModel = ctxXmlDataModel
            iniReader = ctxIniReader
            testerRunner = ctxTesterRunner
            
            // Just ensure iniReader is valid
            if (iniReader && !iniReader.isValid) {
                iniReader.readINIFile()
            }
        }

        Connections {
            target: iniReader ? iniReader : null
            enabled: iniReader !== null && iniReader !== undefined
            onPathsChanged: {
                if (typeof iniReader !== "undefined" && iniReader && iniReader.isValid && typeof xmlDataModel !== "undefined" && xmlDataModel) {
                    tableViewContainer.isLoading = true
                    tableViewContainer.errorMessage = ""
                    // Reset unsaved changes flag when data is loaded
                    hasUnsavedChanges = false
                    
                    // Emit signal for TopLayout_zero.qml
                    tableViewContainer.dataLoaded()
                    // Clear selection when data is reloaded (row indices may have changed)
                    if (tableComponent && tableComponent.tableView) {
                        tableComponent.tableView.selection.clear()
                        tableComponent.tableView.currentRow = -1
                    }
                    tableViewContainer.clearSelectedRowsArray()
                    
                    // After reload, check which progress bars should remain
                    // Preserve progress bars if there are any with progress < 100% (still active)
                    var hasActiveProgressBars = false
                    if (tableViewContainer.rowsInProgress) {
                        var progressKeys = Object.keys(tableViewContainer.rowsInProgress)
                        for (var checkIdx = 0; checkIdx < progressKeys.length; checkIdx++) {
                            var checkProgressInfo = tableViewContainer.rowsInProgress[progressKeys[checkIdx]]
                            if (checkProgressInfo && (checkProgressInfo.progress || 0) < 100 && (checkProgressInfo.progress || 0) >= 0) {
                                hasActiveProgressBars = true
                                break
                            }
                        }
                    }
                    if (hasActiveProgressBars && tableViewContainer.rowsInProgress && Object.keys(tableViewContainer.rowsInProgress).length > 0) {
                        var rowsInProgressObj = tableViewContainer.rowsInProgress
                        var rowKeys = Object.keys(rowsInProgressObj)
                        var updatedRowsInProgress = {}
                        var removedCount = 0
                        var keptCount = 0
                        
                        // Iterate through all rows in the new data to find matching test keys
                        var proxyModel = tableComponent ? tableComponent.proxyModelInstance : null
                        if (xmlDataModel && proxyModel) {
                            var totalRows = proxyModel.count
                            
                            for (var i = 0; i < rowKeys.length; i++) {
                                // rowKeys are now testKeys (rowsInProgress is keyed by testKey)
                                var testKey = rowKeys[i]
                                var progressInfo = rowsInProgressObj[testKey]
                                if (!progressInfo) {
                                    // No progress info - remove it
                                    removedCount++
                                    continue
                                }
                                
                                // Normalize testKey for comparison
                                var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                                var foundRow = false
                                var rowStatus = ""
                                progressValue = progressInfo.progress || 0  // Reuse variable from outer scope (line 302)
                                
                                // Search for this testKey in the reloaded data
                                for (var newRow = 0; newRow < totalRows; newRow++) {
                                    if (proxyModel) {
                                            var sourceRow = proxyModel.mapProxyRowToSource(newRow)
                                        if (sourceRow >= 0 && xmlDataModel) {
                                            var rowTestKey = xmlDataModel.getTestKey(sourceRow)
                                            // Normalize test keys for comparison
                                            var normalizedRowTestKey = (rowTestKey || "").replace(/\\/g, "/").replace(/\/+$/, "")
                                            
                                            if (normalizedRowTestKey === normalizedTestKey ||
                                                normalizedTestKey.indexOf(normalizedRowTestKey) >= 0 ||
                                                normalizedRowTestKey.indexOf(normalizedTestKey) >= 0) {
                                                // Found matching test
                                                var rowData = proxyModel.get(newRow)
                                                if (rowData) {
                                                    rowStatus = rowData.status || ""
                                                    // Only keep progress bar if progress < 100% (test not finished)
                                                    // If progress >= 100%, remove progress bar and show status from XML
                                                    var isFinished = (progressValue >= 100)
                                                    
                                                    if (isFinished) {
                                                        removedCount++
                                                    } else {
                                                        // Test still in progress - keep progress bar (keyed by testKey, not row index)
                                                        updatedRowsInProgress[normalizedTestKey] = {
                                                            progress: progressValue,
                                                            text: progressInfo.text || "Processing",
                                                            testKey: normalizedTestKey,
                                                            mode: progressInfo.mode || ""
                                                        }
                                                        keptCount++
                                                        foundRow = true
                                                    }
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if (!foundRow) {
                                    // Test key not found in reloaded data - might have been removed
                                    // Only remove if finished, otherwise keep it (might just be a matching issue)
                                    if (progressValue >= 100) {
                                        removedCount++
                                    } else {
                                        // Keep it even if not found (matching might fail but process is still running)
                                        keptCount++
                                        // Keep with normalized testKey (rowsInProgress is keyed by testKey)
                                        updatedRowsInProgress[normalizedTestKey] = progressInfo
                                    }
                                }
                            }
                            
                            // Update rowsInProgress with only the tests that are still running
                            tableViewContainer.rowsInProgress = updatedRowsInProgress
                        } else {
                            // No model available - clear all progress bars only if no active progress bars
                            if (!hasActiveProgressBars) {
                                tableViewContainer.rowsInProgress = {}
                            }
                        }
                    } else {
                        // No active progress bars - clear all progress bars
                        if (!hasActiveProgressBars && tableViewContainer.rowsInProgress && Object.keys(tableViewContainer.rowsInProgress).length > 0) {
                            tableViewContainer.rowsInProgress = {}
                        }
                    }
                }
            }
            onErrorOccurred: function(errorMsg) {
                tableViewContainer.errorMessage = errorMsg
                tableViewContainer.isLoading = false
                errorDialog.show(errorMsg)
            }
        }
        
        Connections {
            target: typeof xmlDataModel !== "undefined" && xmlDataModel ? xmlDataModel : null
            enabled: typeof xmlDataModel !== "undefined" && xmlDataModel !== null && xmlDataModel !== undefined
            
            Component.onCompleted: {
                // Connections initialized
            }
                onLoadingStarted: {
                    Logger.info("Loading XML data...")
                    tableViewContainer.isLoading = true
                    tableViewContainer.errorMessage = ""
                }
            onLoadingFinished: function(success, count) {
                tableViewContainer.isLoading = false
                if (!success) {
                    tableViewContainer.errorMessage = "Failed to load data. " + count + " files processed."
                } else {
                    tableViewContainer.errorMessage = ""
                    // Reset unsaved changes flag when data is loaded
                    hasUnsavedChanges = false
                    // Clear selection when data is reloaded (row indices may have changed)
                    if (tableComponent && tableComponent.tableView) {
                        tableComponent.tableView.selection.clear()
                        tableComponent.tableView.currentRow = -1
                    }
                    tableViewContainer.clearSelectedRowsArray()
                    
                    // After reload, check which progress bars should remain
                    // Preserve progress bars if there are any with progress < 100% (still active)
                    var hasActiveProgressBars = false
                    var allProgressBarsFinished = true
                    if (tableViewContainer.rowsInProgress) {
                        var progressKeys = Object.keys(tableViewContainer.rowsInProgress)
                        if (progressKeys.length > 0) {
                            for (var checkIdx = 0; checkIdx < progressKeys.length; checkIdx++) {
                                var checkProgressInfo = tableViewContainer.rowsInProgress[progressKeys[checkIdx]]
                                var progressValue = checkProgressInfo ? (checkProgressInfo.progress || 0) : 0
                                if (progressValue < 100 && progressValue >= 0) {
                                    hasActiveProgressBars = true
                                    allProgressBarsFinished = false
                                    break
                                }
                            }
                            // If all progress bars are finished (>= 100%), clear them all
                            if (!hasActiveProgressBars && allProgressBarsFinished) {
                                tableViewContainer.rowsInProgress = {}
                                // Also clear the global progress indicator
                                tableViewContainer.processingProgress = -1
                                tableViewContainer.processingMessage = ""
                                tableViewContainer.isTestProcessRunning = false
                            }
                        }
                    }
                    if (hasActiveProgressBars && tableViewContainer.rowsInProgress && Object.keys(tableViewContainer.rowsInProgress).length > 0) {
                        var rowsInProgressObj = tableViewContainer.rowsInProgress
                        var rowKeys = Object.keys(rowsInProgressObj)
                        var updatedRowsInProgress = {}
                        var removedCount = 0
                        var keptCount = 0
                        
                        // Iterate through all rows in the new data to find matching test keys
                        var proxyModel = tableComponent ? tableComponent.proxyModelInstance : null
                        if (xmlDataModel && proxyModel) {
                            var totalRows = proxyModel.count
                            
                            for (var i = 0; i < rowKeys.length; i++) {
                                // rowKeys are now testKeys (rowsInProgress is keyed by testKey)
                                var testKey = rowKeys[i]
                                var progressInfo = rowsInProgressObj[testKey]
                                if (!progressInfo) {
                                    // No progress info - remove it
                                    removedCount++
                                    continue
                                }
                                
                                // Normalize testKey for comparison
                                var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                                var foundRow = false
                                var rowStatus = ""
                                progressValue = progressInfo.progress || 0  // Reuse variable from outer scope (line 302)
                                
                                // Search for this testKey in the reloaded data
                                for (var newRow = 0; newRow < totalRows; newRow++) {
                                    if (proxyModel) {
                                            var sourceRow = proxyModel.mapProxyRowToSource(newRow)
                                        if (sourceRow >= 0 && xmlDataModel) {
                                            var rowTestKey = xmlDataModel.getTestKey(sourceRow)
                                            // Normalize test keys for comparison
                                            var normalizedRowTestKey = (rowTestKey || "").replace(/\\/g, "/").replace(/\/+$/, "")
                                            
                                            if (normalizedRowTestKey === normalizedTestKey ||
                                                normalizedTestKey.indexOf(normalizedRowTestKey) >= 0 ||
                                                normalizedRowTestKey.indexOf(normalizedTestKey) >= 0) {
                                                // Found matching test
                                                var rowData = proxyModel.get(newRow)
                                                if (rowData) {
                                                    rowStatus = rowData.status || ""
                                                    // Only keep progress bar if progress < 100% (test not finished)
                                                    // If progress >= 100%, remove progress bar and show status from XML
                                                    var isFinished = (progressValue >= 100)
                                                    
                                                    if (isFinished) {
                                                        removedCount++
                                                    } else {
                                                        // Test still in progress - keep progress bar (keyed by testKey, not row index)
                                                        updatedRowsInProgress[normalizedTestKey] = {
                                                            progress: progressValue,
                                                            text: progressInfo.text || "Processing",
                                                            testKey: normalizedTestKey,
                                                            mode: progressInfo.mode || ""
                                                        }
                                                        keptCount++
                                                        foundRow = true
                                                    }
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if (!foundRow) {
                                    // Test key not found in reloaded data - might have been removed
                                    // Only remove if finished, otherwise keep it (might just be a matching issue)
                                    if (progressValue >= 100) {
                                        removedCount++
                                    } else {
                                        // Keep it even if not found (matching might fail but process is still running)
                                        keptCount++
                                        // Keep with normalized testKey (rowsInProgress is keyed by testKey)
                                        updatedRowsInProgress[normalizedTestKey] = progressInfo
                                    }
                                }
                            }
                            
                            // Update rowsInProgress with only the tests that are still running
                            tableViewContainer.rowsInProgress = updatedRowsInProgress
                        } else {
                            // No model available - clear all progress bars only if no active progress bars
                            if (!hasActiveProgressBars) {
                                tableViewContainer.rowsInProgress = {}
                            }
                        }
                    } else {
                        // No active progress bars - clear all progress bars
                        if (!hasActiveProgressBars && tableViewContainer.rowsInProgress && Object.keys(tableViewContainer.rowsInProgress).length > 0) {
                            tableViewContainer.rowsInProgress = {}
                        }
                    }
                }
            }
            onErrorOccurred: function(errorMsg) {
                tableViewContainer.errorMessage = errorMsg
                tableViewContainer.isLoading = false
                errorDialog.show(errorMsg)
            }
        }
        
        // Connections for test runner
            Connections {
                target: testerRunner ? testerRunner : null
                enabled: testerRunner !== null && testerRunner !== undefined
                onOutputLine: function(line, isError) {
                    // Log all test runner output lines in real-time
                    if (isError) {
                        Logger.error("[freeDView_tester] " + line)
                    } else {
                        Logger.info("[freeDView_tester] " + line)
                    }
                }
                onRunStarted: function(mode) {
                    Logger.info("Test runner started: " + mode)
                    tableViewContainer.isLoading = true
                    // Only reset progress indicator for test processes (not Phase 4)
                    // Phase 4 runs in parallel and shouldn't affect the progress indicator
                    if (mode !== "prepare-ui") {
                        tableViewContainer.processingProgress = -1  // Reset progress
                        tableViewContainer.processingMessage = ""
                    }
                    tableViewContainer.testRunnerStatus = "Running freeDView_tester (" + mode + ")... This may take a while."
                    // Track if test process is running (exclude Phase 4/prepare-ui)
                    tableViewContainer.isTestProcessRunning = (mode !== "prepare-ui")
                
                // Only initialize progress bars for test processes (not Phase 4)
                // Phase 4 runs in parallel and should not clear existing progress bars
                if (mode !== "prepare-ui") {
                    // Mark all selected rows as in progress (keyed by testKey, not row index)
                    var rowsInProgressObj = {}
                    var proxyModel = tableComponent ? tableComponent.proxyModelInstance : null
                    for (var i = 0; i < tableViewContainer.selectedRows.length; i++) {
                        var row = tableViewContainer.selectedRows[i]
                        if (row >= 0 && proxyModel) {
                            var rowData = proxyModel.get(row)
                            if (rowData) {
                                // Get test key for this row
                                var sourceRow = proxyModel.mapProxyRowToSource(row)
                                var testKey = ""
                                if (xmlDataModel && sourceRow >= 0) {
                                    testKey = xmlDataModel.getTestKey(sourceRow) || ""
                                }
                                
                                // Normalize testKey for consistent matching
                                if (testKey) {
                                    testKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")
                                }
                                
                                // Initialize progress for this test (keyed by testKey, not row index)
                                if (testKey) {
                                    rowsInProgressObj[testKey] = {
                                        progress: 0,
                                        text: "Starting...",
                                        testKey: testKey,
                                        mode: mode
                                    }
                                }
                            }
                        }
                    }
                    tableViewContainer.rowsInProgress = rowsInProgressObj
                }
            }
            onProgressUpdated: function(percentage, message) {
                // This is overall progress (for backward compatibility and global status)
                tableViewContainer.processingProgress = percentage
                tableViewContainer.processingMessage = message
            }
            onTestProgressUpdated: function(testKey, percentage, message) {
                // This is per-test progress - update only the matching test (keyed by testKey)
                var rowsInProgressObj = tableViewContainer.rowsInProgress
                
                // Extract phase info from message if available
                var phaseText = "Processing"
                if (message.indexOf("Cancelled") >= 0 || message.indexOf("cancelled") >= 0) {
                    phaseText = "Cancelled"
                } else if (message.indexOf("Phase") >= 0) {
                    var phaseMatch = message.match(/Phase\s*(\d+)/i)
                    if (phaseMatch) {
                        phaseText = "Phase " + phaseMatch[1]
                    }
                } else if (message.indexOf("Starting") >= 0) {
                    phaseText = "Starting..."
                } else if (message.indexOf("Completed") >= 0 || message.indexOf("completed") >= 0) {
                    // If percentage is 100, this means finished - use "Finished" instead of "Completed"
                    phaseText = (percentage >= 100) ? "Finished" : "Completed"
                } else if (message.indexOf("Processing") >= 0) {
                    phaseText = "Processing"
                }
                
                // Normalize testKey for comparison (ensure forward slashes, trim)
                var normalizedTestKey = testKey.replace(/\\/g, "/").replace(/\/+$/, "")  // Remove trailing slashes
                
                // Update the test that matches this testKey (rowsInProgress is now keyed by testKey)
                var found = false
                if (rowsInProgressObj.hasOwnProperty(normalizedTestKey)) {
                    // Direct match - update progress
                    rowsInProgressObj[normalizedTestKey].progress = percentage
                    // If percentage is 100, always use "Finished" text instead of phaseText
                    rowsInProgressObj[normalizedTestKey].text = (percentage >= 100) ? "Finished" : phaseText
                    found = true
                } else {
                    // Try fuzzy match (partial match) for backwards compatibility
                    var testKeys = Object.keys(rowsInProgressObj)
                    for (var i = 0; i < testKeys.length; i++) {
                        var key = testKeys[i]
                        if (key === normalizedTestKey || 
                            normalizedTestKey.indexOf(key) >= 0 ||
                            key.indexOf(normalizedTestKey) >= 0) {
                            // Match found - update this test's progress
                            rowsInProgressObj[key].progress = percentage
                            rowsInProgressObj[key].text = (percentage >= 100) ? "Finished" : phaseText
                            found = true
                            break
                        }
                    }
                }
                
                
                // Force update by creating new object (triggers bindings)
                var newRowsInProgress = {}
                var allKeys = Object.keys(rowsInProgressObj)
                for (var j = 0; j < allKeys.length; j++) {
                    newRowsInProgress[allKeys[j]] = rowsInProgressObj[allKeys[j]]
                }
                tableViewContainer.rowsInProgress = newRowsInProgress
            }
            onRunFinished: function(success, mode, exitCode, stdOut, stdErr) {
                tableViewContainer.isLoading = false
                
                // Log test runner completion
                if (success) {
                    Logger.info("Test runner completed successfully: " + mode + " (exit code: " + exitCode + ")")
                    if (stdOut && stdOut !== "") {
                        Logger.info("Test runner output:\n" + stdOut)
                    }
                } else {
                    Logger.error("Test runner failed: " + mode + " (exit code: " + exitCode + ")")
                    if (stdErr && stdErr !== "") {
                        Logger.error("Test runner error output:\n" + stdErr)
                    }
                }
                
                // Clear test process flag only if it was a test process (not Phase 4)
                if (mode !== "prepare-ui") {
                    // Check if there are still any active progress bars
                    var hasActiveProgress = false
                    var rowsInProgressObj = tableViewContainer.rowsInProgress
                    var rowKeys = Object.keys(rowsInProgressObj)
                    for (var i = 0; i < rowKeys.length; i++) {
                        var rowKey = rowKeys[i]
                        if (rowsInProgressObj[rowKey] && rowsInProgressObj[rowKey].progress < 100 && rowsInProgressObj[rowKey].progress >= 0) {
                            hasActiveProgress = true
                            break
                        }
                    }
                    // Only clear progress indicator and flag if no active progress bars remain
                    if (!hasActiveProgress) {
                        tableViewContainer.processingProgress = -1  // Reset progress (hides indicator)
                        tableViewContainer.processingMessage = ""
                        tableViewContainer.isTestProcessRunning = false
                    } else {
                        // Keep processingProgress and processingMessage unchanged so indicator stays visible
                    }
                }
                
                // Skip all progress bar handling for Phase 4 (prepare-ui) - it doesn't affect test processes
                if (mode === "prepare-ui") {
                } else {
                    // DON'T update all rows to completion here - individual tests complete via "Successfully completed comparison for:"
                    // Only update rows that are still in progress (not yet completed individually)
                    // This prevents completed tests from being overwritten when another test finishes
                    rowsInProgressObj = tableViewContainer.rowsInProgress  // Reuse variable from outer scope
                    rowKeys = Object.keys(rowsInProgressObj)  // Reuse variable from outer scope
                    if (rowKeys.length > 0) {
                    // Only update rows that haven't reached 100% or error state yet
                    var hasIncompleteRows = false
                    for (i = 0; i < rowKeys.length; i++) {  // Reuse variable from outer scope
                        rowKey = rowKeys[i]  // Reuse variable from outer scope
                        if (rowsInProgressObj[rowKey]) {
                            var currentProgress = rowsInProgressObj[rowKey].progress
                            // Only update if not already completed (100) or error (-1) or cancelled
                            if (currentProgress < 100 && currentProgress >= 0) {
                                if (success) {
                                    rowsInProgressObj[rowKey].progress = 100
                                    rowsInProgressObj[rowKey].text = "Finished"
                                } else {
                                    rowsInProgressObj[rowKey].progress = -1
                                    rowsInProgressObj[rowKey].text = "ERROR"
                                }
                                hasIncompleteRows = true
                            }
                        }
                    }
                    
                    // Only update and start timer if we actually updated something
                    if (hasIncompleteRows) {
                        var finalRowsInProgress = {}
                        for (var j = 0; j < rowKeys.length; j++) {
                            finalRowsInProgress[rowKeys[j]] = rowsInProgressObj[rowKeys[j]]
                        }
                        tableViewContainer.rowsInProgress = finalRowsInProgress
                    }
                    
                        // Clear rowsInProgress after a short delay to show final state (2 seconds)
                        // This allows users to see the "Finish" or "ERROR" state before clearing
                        // Access progressClearTimer through tableComponent
                        if (tableComponent && tableComponent.progressClearTimer) {
                            tableComponent.progressClearTimer.start()
                        }
                    }
                }
                
                if (success) {
                    tableViewContainer.testRunnerStatus = "freeDView_tester (" + mode + ") completed successfully. Refreshing data..."
                    // Clear run_on_test_list after successful run (optional - user can also leave it)
                    // Only clear from freeDView_tester.ini (run_on_test_list is not used in tableview_test.ini)
                    // Skip clearing for prepare-ui mode (Phase 4 only) since it doesn't use run_on_test_list
                    if (mode !== "prepare-ui" && iniReader) {
                        var testerPath = iniReader.freeDViewTesterPath
                        if (testerPath) {
                            var testerIniPath = testerPath + "/freeDView_tester.ini"
                            if (Qt.platform.os === "windows") {
                                testerIniPath = testerIniPath.replace(/\//g, "\\")
                            }
                            iniReader.updateRunOnTestListInFile(testerIniPath, "")  // Clear from freeDView_tester.ini
                        }
                    }
                    // Reload data after successful run - this will trigger table refresh
                    // Use Qt.callLater to ensure the UI has processed the completion first
                    Qt.callLater(function() {
                        if (iniReader && iniReader.isValid && xmlDataModel) {
                            // Clear all progress bars before reloading - they will be removed when data reloads
                            // The onLoadingFinished handler will check and remove finished progress bars
                            xmlDataModel.loadData(iniReader.setTestResultsPath, "", iniReader.setTestPath)
                        }
                    })
                    // Reset status message after 5 seconds
                    if (tableComponent && tableComponent.statusMessageTimer) {
                        tableComponent.statusMessageTimer.interval = 5000
                        tableComponent.statusMessageTimer.start()
                    }
                } else {
                    var errorMsg = "freeDView_tester (" + mode + ") failed with exit code " + exitCode
                    if (stdErr) {
                        errorMsg += "\n\nError output:\n" + stdErr
                    }
                    errorDialog.show(errorMsg)
                    tableViewContainer.testRunnerStatus = "freeDView_tester (" + mode + ") failed"
                    // Clear error status after 10 seconds
                    if (tableComponent && tableComponent.statusMessageTimer) {
                        tableComponent.statusMessageTimer.interval = 10000
                        tableComponent.statusMessageTimer.start()
                    }
                }
            }
        }
        

}
