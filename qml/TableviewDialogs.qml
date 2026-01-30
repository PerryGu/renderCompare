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
 * @file TableviewDialogs.qml
 * @brief Dialog components for Table View
 * 
 * Contains all dialog components used in the table view:
 * - ErrorDialog: Displays error messages
 * - EditDialog: Allows editing cell values
 * - ConfirmationDialog: Confirms test runner actions
 */

import QtQuick 2.2
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.2
import com.rendercompare 1.0
import Theme 1.0
import Logger 1.0

Item {
    id: dialogsContainer
    anchors.fill: parent
    // Items don't block mouse events by default in QML
    // Only MouseAreas block events, and those are already conditionally enabled
    
    // Properties to receive references from parent
    property var tableViewContainer: null
    property var proxyModelInstance: null
    // xmlDataModel, iniReader, testerRunner are context properties (available globally)
    // Don't declare them as local properties to avoid shadowing
    property var statusBarText: null
    property var statusMessageTimer: null
    property bool hasUnsavedChanges: false
    property var mapTableViewColumnToModelColumn: null  // Function reference
    
    // Expose dialogs so they can be accessed from outside
    property alias errorDialog: errorDialog
    property alias editDialog: editDialog
    property alias confirmationDialog: confirmationDialog

    // Custom error message dialog (compatible with QtQuick.Controls 1.2)
    Rectangle {
        id: errorDialog
        visible: false
        anchors.fill: parent
        color: Theme.overlayDark  // Semi-transparent overlay
        z: 10002  // Very high z-order to ensure it's on top
        
        Rectangle {
            id: dialogBox
            width: 400
            height: 150
            anchors.centerIn: parent
            border.color: Theme.borderDark  // Dark blue border (matches floating menu)
            border.width: 2  // Border thickness
            radius: 10  // Rounded corners (matches floating menu)
            
            // Dark gray gradient background (matches floating menu)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.gradientTop }  // Top: lighter gray
                GradientStop { position: 1; color: Theme.gradientBottom }  // Bottom: darker gray
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                Text {
                    id: errorTitle
                    text: "Error"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeDialogTitle
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                Text {
                    id: errorText
                    width: dialogBox.width - 30
                    text: ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.chartMark  // Orange text (matches floating menu)
                    wrapMode: Text.WordWrap
                }
                
                Item {
                    width: parent.width
                    height: 30
                    
                    Button {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: "OK"
                        onClicked: errorDialog.visible = false
                        
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
                                color: Theme.chartMark  // Orange text
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
        
        /**
         * @brief Show error dialog with message
         * 
         * Displays an error message in the error dialog overlay.
         * 
         * @param message - Error message text to display
         */
        function show(message) {
            errorText.text = message
            visible = true
        }
    }
    
    // Edit dialog for editing cell values
    Rectangle {
        id: editDialog
        visible: false
        anchors.fill: parent
        color: Theme.overlayDark  // Semi-transparent black overlay (matches error dialog)
        z: 10003  // Very high z-order to ensure it's on top
        
        /**
         * @brief Show edit dialog for a specific cell
         * 
         * Opens the edit dialog to allow user to edit a cell value.
         * The dialog is pre-populated with the current cell value.
         * 
         * @param rowIndex - Row index in the proxy model
         * @param columnIndex - Column index in the TableView (not model column)
         * @param columnTitle - Display name of the column being edited
         * @param currentValue - Current value in the cell
         */
        function show(rowIndex, columnIndex, columnTitle, currentValue) {
            editDialogRowIndex = rowIndex
            editDialogColumnIndex = columnIndex
            editDialogTitle.text = "Edit: " + columnTitle
            editDialogTextField.text = currentValue
            editDialog.visible = true
            Qt.callLater(function() {
                editDialogTextField.forceActiveFocus()
                editDialogTextField.selectAll()
            })
        }
        
        property int editDialogRowIndex: -1
        property int editDialogColumnIndex: -1
        
        Rectangle {
            id: editDialogBox
            width: 500
            height: 180
            anchors.centerIn: parent
            border.color: Theme.borderDark  // Dark blue border (matches floating menu)
            border.width: 2  // Border thickness
            radius: 10  // Rounded corners (matches floating menu)
            z: 1  // Above the background MouseArea
            
            // Dark gray gradient background (matches floating menu)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.gradientTop }  // Top: lighter gray
                GradientStop { position: 1; color: Theme.gradientBottom }  // Bottom: darker gray
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    id: editDialogTitle
                    text: "Edit"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeDialogTitle
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                TextField {
                    id: editDialogTextField
                    width: parent.width
                    font.pixelSize: Theme.fontSizeSmall
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            editDialog.onSaveClicked()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            editDialog.visible = false
                            event.accepted = true
                        }
                    }
                    
                    style: TextFieldStyle {
                        textColor: Theme.chartMark  // Orange text
                        background: Rectangle {
                            color: Theme.buttonDefault  // Dark background for input field
                            border.color: Theme.borderDark  // Dark blue border
                            border.width: 1
                            radius: 4
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    spacing: 10
                    
                    Item {
                        width: parent.width - 200
                        height: 1
                    }
                    
                    Button {
                        text: "Cancel"
                        onClicked: editDialog.visible = false
                        
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
                                color: Theme.chartMark  // Orange text
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    Button {
                        text: "Save"
                        onClicked: editDialog.onSaveClicked()
                        
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
                                color: Theme.chartMark  // Orange text
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
        
        // Background MouseArea to close dialog when clicking outside
        // Must be after editDialogBox in code order so buttons receive clicks first
        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: editDialog.visible  // Only intercept events when dialog is visible
            onPressed: {
                // Check if click is inside the dialog box
                var clickPos = mapToItem(editDialogBox, mouse.x, mouse.y)
                // If click is inside dialog box, don't accept the event so buttons can handle it
                if (clickPos.x >= 0 && clickPos.x <= editDialogBox.width &&
                    clickPos.y >= 0 && clickPos.y <= editDialogBox.height) {
                    mouse.accepted = false
                }
            }
            onClicked: {
                // Only close if clicking outside the dialog box
                var clickPos = mapToItem(editDialogBox, mouse.x, mouse.y)
                if (clickPos.x < 0 || clickPos.x > editDialogBox.width ||
                    clickPos.y < 0 || clickPos.y > editDialogBox.height) {
                    editDialog.visible = false
                }
            }
        }
        
        /**
         * @brief Handle save button click in edit dialog
         * 
         * Saves the edited cell value to the XML data model and automatically
         * saves the changes to uiData.xml file. Maps proxy model row/column
         * indices to source model indices before updating.
         */
        function onSaveClicked() {
            if (editDialogRowIndex >= 0 && editDialogColumnIndex >= 0) {
                var newValue = editDialogTextField.text
                
                // Map proxy model row to source model row
                var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(editDialogRowIndex) : -1
                if (sourceRow < 0) {
                    Logger.error("[TableviewDialogs] Failed to map row index")
                    errorDialog.show("Failed to map row index")
                    return
                }
                
                // Map TableViewColumn index to model column index
                var modelColumnIndex = -1
                if (mapTableViewColumnToModelColumn) {
                    modelColumnIndex = mapTableViewColumnToModelColumn(editDialogColumnIndex)
                }
                if (modelColumnIndex < 0) {
                    Logger.error("[TableviewDialogs] Invalid column index")
                    errorDialog.show("Invalid column index")
                    return
                }
                
                // Update the model
                // Access context property directly (it's available globally)
                var model = typeof xmlDataModel !== "undefined" ? xmlDataModel : null
                
                if (model) {
                    var success = model.updateCell(sourceRow, modelColumnIndex, newValue)
                    if (success) {
                        // Refresh the proxy model to reflect changes
                        if (proxyModelInstance) {
                            proxyModelInstance.invalidate()
                        }
                        
                        // Auto-save to XML file
                        // Access context property directly if not passed
                        var reader = iniReader
                        if (!reader && typeof iniReader !== "undefined") {
                            reader = iniReader
                        }
                        
                        if (reader && reader.isValid) {
                            var resultsPath = reader.setTestResultsPath
                            if (resultsPath) {
                                var saveSuccess = model.saveToXml(resultsPath)
                                if (saveSuccess) {
                                    hasUnsavedChanges = false
                                    if (statusBarText) {
                                        statusBarText.text = "Changes saved successfully to uiData.xml"
                                    }
                                    // Reset status message after 3 seconds
                                    if (statusMessageTimer) {
                                        statusMessageTimer.start()
                                    }
                                } else {
                                    hasUnsavedChanges = true
                                    errorDialog.show("Failed to save changes to uiData.xml")
                                }
                            } else {
                                hasUnsavedChanges = true
                                errorDialog.show("Invalid results path. Please check your INI file.")
                            }
                        } else {
                            hasUnsavedChanges = true
                            errorDialog.show("INI file not loaded. Cannot save changes.")
                        }
                        
                        editDialog.visible = false
                    } else {
                        // Show error
                        Logger.error("[TableviewDialogs] Failed to update cell value")
                        errorDialog.show("Failed to update cell value")
                    }
                } else {
                    Logger.error("[TableviewDialogs] xmlDataModel is null or undefined")
                    errorDialog.show("Data model not available. Cannot save changes.")
                }
            }
        }
    }
    
    // Confirmation dialog for running freeDView_tester commands
    Rectangle {
        id: confirmationDialog
        visible: false
        anchors.fill: parent
        color: Theme.overlayDark  // Semi-transparent overlay
        z: 10004  // Very high z-order to ensure it's on top
        
        /**
         * @brief Show confirmation dialog for running all phases
         * 
         * Displays a confirmation dialog asking user to confirm running
         * all phases (1-4) of freeDView_tester for selected rows.
         * Shows the number of selected tests in the message.
         */
        function showRunAll() {
            // Use all selected rows instead of single rowIndex
            confirmationDialogMode = "all"
            var selectedCount = tableViewContainer && tableViewContainer.selectedRows ? tableViewContainer.selectedRows.length : 0
            confirmationDialogTitle.text = "Run All Phases"
            confirmationDialogMessage.text = "This will run all phases (1-4) of freeDView_tester for " + 
                (selectedCount === 1 ? "this test" : selectedCount + " selected tests") + ".\n\n" +
                "This process may take a long time. Phase 4 will run automatically after Phase 3 completes.\n\n" +
                "Do you want to continue?"
            confirmationDialog.visible = true
        }
        
        /**
         * @brief Show confirmation dialog for running Phase 3
         * 
         * Displays a confirmation dialog asking user to confirm running
         * Phase 3 (Render Compare) for selected rows. Phase 4 will run
         * automatically after Phase 3 completes.
         * 
         * Shows the number of selected tests in the message.
         */
        function showRunPhase3() {
            // Use all selected rows instead of single rowIndex
            confirmationDialogMode = "phase3"
            var selectedCount = tableViewContainer && tableViewContainer.selectedRows ? tableViewContainer.selectedRows.length : 0
            confirmationDialogTitle.text = "Run Phase 3"
            confirmationDialogMessage.text = "This will run Phase 3 (Render Compare) for " + 
                (selectedCount === 1 ? "this test" : selectedCount + " selected tests") + ".\n\n" +
                "Phase 4 will run automatically after Phase 3 completes to update uiData.xml.\n\n" +
                "This process may take a long time.\n\n" +
                "Do you want to continue?"
            confirmationDialog.visible = true
        }
        
        property string confirmationDialogMode: ""
        
        Rectangle {
            id: confirmationDialogBox
            width: 500
            height: 220
            anchors.centerIn: parent
            border.color: Theme.borderDark  // Dark blue border (matches floating menu)
            border.width: 2  // Border thickness
            radius: 10  // Rounded corners (matches floating menu)
            
            // Dark gray gradient background (matches floating menu)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.gradientTop }  // Top: lighter gray
                GradientStop { position: 1; color: Theme.gradientBottom }  // Bottom: darker gray
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    id: confirmationDialogTitle
                    text: "Confirm"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeDialogTitle
                    color: Theme.chartMark  // Orange text (matches floating menu)
                }
                
                Text {
                    id: confirmationDialogMessage
                    width: parent.width
                    text: ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.chartMark  // Orange text (matches floating menu)
                    wrapMode: Text.WordWrap
                }
                
                Row {
                    width: parent.width
                    spacing: 10
                    
                    Item {
                        width: parent.width - 200
                        height: 1
                    }
                    
                    Button {
                        text: "Cancel"
                        onClicked: confirmationDialog.visible = false
                        
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
                                color: Theme.chartMark  // Orange text
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    Button {
                        text: "Continue"
                        onClicked: confirmationDialog.onConfirmClicked()
                        
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
                                color: Theme.chartMark  // Orange text
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
        
        /**
         * @brief Handle confirm button click in confirmation dialog
         * 
         * Executes the confirmed action (run all phases or run Phase 3)
         * for all selected rows. Starts the freeDView_tester process
         * and shows progress indicators.
         */
        function onConfirmClicked() {
            // Check if there are selected rows
            if (!tableViewContainer || !tableViewContainer.selectedRows || tableViewContainer.selectedRows.length === 0) {
                errorDialog.show("No rows selected. Please select at least one row.")
                confirmationDialog.visible = false
                return
            }
            
            // Get tester path and INI path from iniReader
            var testerPath = iniReader ? iniReader.freeDViewTesterPath : ""
            var iniPath = iniReader ? iniReader.iniFilePath : ""
            
            if (!testerPath || testerPath === "") {
                errorDialog.show("freeDView_tester path not configured. Please set 'freeDViewTesterPath' in the INI file.")
                confirmationDialog.visible = false
                return
            }
            
            // Get test keys from ALL selected rows
            var testKeys = []
            var failedRows = []
            
            for (var i = 0; i < tableViewContainer.selectedRows.length; i++) {
                var proxyRow = tableViewContainer.selectedRows[i]
                // Map proxy model row to source model row to get test key
                var sourceRow = proxyModelInstance ? proxyModelInstance.mapProxyRowToSource(proxyRow) : -1
                if (sourceRow < 0) {
                    failedRows.push("Row " + proxyRow)
                    continue
                }
                
                // Get testKey from the selected row using the dedicated method
                var testKey = ""
                if (xmlDataModel && sourceRow >= 0) {
                    testKey = xmlDataModel.getTestKey(sourceRow) || ""
                }
                
                if (!testKey || testKey === "") {
                    failedRows.push("Row " + proxyRow)
                    continue
                }
                
                // Normalize testKey (relative path)
                var normalizedTestKey = testKey
                if (normalizedTestKey.indexOf("testSets_results") >= 0) {
                    // Extract everything after testSets_results/
                    var parts = normalizedTestKey.split("testSets_results")
                    if (parts.length > 1) {
                        normalizedTestKey = parts[parts.length - 1]
                        // Remove leading slashes/backslashes
                        normalizedTestKey = normalizedTestKey.replace(/^[\/\\]+/, "")
                    }
                }
                // Also handle Windows absolute paths (drive letter)
                if (normalizedTestKey.match(/^[A-Z]:[\/\\]/)) {
                    // Extract relative part - find testSets_results and take everything after
                    var idx = normalizedTestKey.indexOf("testSets_results")
                    if (idx >= 0) {
                        normalizedTestKey = normalizedTestKey.substring(idx + "testSets_results".length)
                        normalizedTestKey = normalizedTestKey.replace(/^[\/\\]+/, "")
                    }
                }
                // Normalize path separators to forward slashes (Python code expects this)
                normalizedTestKey = normalizedTestKey.replace(/\\/g, "/")
                
                testKeys.push(normalizedTestKey)
            }
            
            if (testKeys.length === 0) {
                var errorMsg = "Could not get testKey from any selected row"
                if (failedRows.length > 0) {
                    errorMsg += " (Failed rows: " + failedRows.join(", ") + ")"
                }
                errorMsg += ". Please ensure uiData.xml contains testKey data."
                errorDialog.show(errorMsg)
                confirmationDialog.visible = false
                return
            }
            
            // If some rows failed, warn but continue (error already shown to user)
            
            // Update freeDView_tester.ini file with run_on_test_list before running
            // Format: comma-separated list: "test1, test2, test3"
            if (iniReader && testerPath) {
                // Join test keys with comma and space
                var testKeysList = testKeys.join(", ")
                
                var testerIniPath = testerPath + "/freeDView_tester.ini"
                // Use Qt.platform.os to handle path separators correctly
                if (Qt.platform.os === "windows") {
                    testerIniPath = testerIniPath.replace(/\//g, "\\")
                }
                var updateSuccess = iniReader.updateRunOnTestListInFile(testerIniPath, testKeysList)
                if (!updateSuccess) {
                    errorDialog.show("Failed to update run_on_test_list in freeDView_tester.ini file. Command will run on all tests.")
                    // Continue anyway - the command will run on all tests
                }
            }
            
            // Run the command
            if (confirmationDialogMode === "all") {
                if (testerRunner) {
                    testerRunner.runAll(testerPath, iniPath)
                } else {
                    errorDialog.show("Test runner not available")
                }
            } else if (confirmationDialogMode === "phase3") {
                if (testerRunner) {
                    testerRunner.runCompareAndPrepare(testerPath, iniPath)
                } else {
                    errorDialog.show("Test runner not available")
                }
            }
            
            confirmationDialog.visible = false
        }
        
        // Background MouseArea to close dialog when clicking outside
        // Must be after confirmationDialogBox in code order so buttons receive clicks first
        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: confirmationDialog.visible  // Only intercept events when dialog is visible
            onPressed: {
                // Check if click is inside the dialog box
                var clickPos = mapToItem(confirmationDialogBox, mouse.x, mouse.y)
                // If click is inside dialog box, don't accept the event so buttons can handle it
                if (clickPos.x >= 0 && clickPos.x <= confirmationDialogBox.width &&
                    clickPos.y >= 0 && clickPos.y <= confirmationDialogBox.height) {
                    mouse.accepted = false
                }
            }
            onClicked: {
                // Only close if clicking outside the dialog box
                var clickPos = mapToItem(confirmationDialogBox, mouse.x, mouse.y)
                if (clickPos.x < 0 || clickPos.x > confirmationDialogBox.width ||
                    clickPos.y < 0 || clickPos.y > confirmationDialogBox.height) {
                    confirmationDialog.visible = false
                }
            }
        }
    }
}
