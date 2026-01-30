/**
 * @file LogWindow.qml
 * @brief Separate log window for displaying application logs
 * 
 * A separate, independent window that displays log messages from the Logger singleton.
 * Can be moved outside the main application window.
 */

import QtQuick 2.2
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import QtQuick.Window 2.2
import Theme 1.0
import Logger 1.0

Window {
    id: logWindow
    width: 800
    height: 500
    minimumWidth: 400
    minimumHeight: 300
    title: "Log Window"
    color: Theme.backgroundDark
    visible: false
    
    // Window properties
    property bool isVisible: false
    
    // Sync isVisible with window visibility (one-way to avoid binding loop)
    onVisibleChanged: {
        // Only update isVisible if it's different (avoid binding loop)
        if (isVisible !== visible) {
            isVisible = visible
        }
        // Update Logger when visibility changes
        if (Logger) {
            Logger.logWindowVisible = visible
            if (visible) {
                updateLogDisplay()
            }
        }
    }
    
    // Title bar (custom since Window doesn't have a styled title bar)
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: Theme.primaryDark
        z: 10
        
        Text {
            id: titleText
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Log Window"
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            color: Theme.textLight
        }
        
        // Close button
        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 30
            color: closeButtonMouseArea.containsMouse ? Theme.statusError : Theme.primaryDark
            
            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: Theme.fontSizeNormal
                color: Theme.textLight
            }
            
            MouseArea {
                id: closeButtonMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    logWindow.isVisible = false
                }
            }
        }
    }
    
    // Toolbar with controls
    Rectangle {
        id: toolbar
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: Theme.backgroundLight
        z: 10
        
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            
            Button {
                text: "Clear"
                height: 25
                width: 60
                onClicked: {
                    Logger.clear()
                }
                style: ButtonStyle {
                    background: Rectangle {
                        color: control.hovered ? Theme.buttonHovered : Theme.buttonDefault
                        border.color: Theme.borderDark
                        border.width: 1
                        radius: 3
                    }
                    label: Text {
                        text: control.text
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textLight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            // Separator
            Rectangle {
                width: 1
                height: 25
                color: Theme.borderDark
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Filter checkboxes
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Show:"
                        font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.textLight
            }
            
            CheckBox {
                id: filterInfo
                checked: Logger && Logger.showInfo !== undefined ? Logger.showInfo : true
                onCheckedChanged: {
                    if (Logger) Logger.showInfo = checked
                    updateLogDisplay()
                }
                style: CheckBoxStyle {
                    label: Text {
                        text: "INFO"
                        color: Theme.primaryAccent  // Green
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
            
            CheckBox {
                id: filterWarning
                checked: Logger && Logger.showWarning !== undefined ? Logger.showWarning : true
                onCheckedChanged: {
                    if (Logger) Logger.showWarning = checked
                    updateLogDisplay()
                }
                style: CheckBoxStyle {
                    label: Text {
                        text: "WARNING"
                        color: Theme.chartMark  // Yellow
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
            
            CheckBox {
                id: filterError
                checked: Logger && Logger.showError !== undefined ? Logger.showError : true
                onCheckedChanged: {
                    if (Logger) Logger.showError = checked
                    updateLogDisplay()
                }
                style: CheckBoxStyle {
                    label: Text {
                        text: "ERROR"
                        color: Theme.statusError  // Red
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
            
            CheckBox {
                id: filterDebug
                checked: Logger && Logger.showDebug !== undefined ? Logger.showDebug : true
                onCheckedChanged: {
                    if (Logger) Logger.showDebug = checked
                    updateLogDisplay()
                }
                style: CheckBoxStyle {
                    label: Text {
                        text: "DEBUG"
                        color: Theme.textMediumGray  // Gray
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }
            
            // Separator
            Rectangle {
                width: 1
                height: 25
                color: Theme.borderDark
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Entries: " + (Logger && Logger.logEntries ? Logger.logEntries.length : 0)
                        font.pixelSize: Theme.fontSizeMedium
                color: Theme.textLight
            }
        }
    }
    
    // Function to update log display
    function updateLogDisplay() {
        if (Logger && typeof Logger.getFormattedTextHTML === "function") {
            logTextArea.text = Logger.getFormattedTextHTML(0)
        } else {
            logTextArea.text = ""
        }
    }
    
    // Log content area - use TextArea for selectable, color-coded text
    Rectangle {
        id: logContentContainer
        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Theme.backgroundDark
        
        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 5
            
            // Inner Rectangle to ensure TextArea fills space
            Rectangle {
                width: scrollView.width
                height: Math.max(scrollView.height, logTextArea.implicitHeight)
                color: Theme.backgroundDark  // Match TextArea background
                
                TextArea {
                    id: logTextArea
                    anchors.fill: parent  // Fill the inner Rectangle
                    readOnly: true
                    textFormat: TextEdit.RichText  // Enable HTML formatting for colors
                    text: ""
                    font.family: "Consolas, Courier New, monospace"
                        font.pixelSize: Theme.fontSizeExtraSmall
                    selectByMouse: true  // Enable text selection
                    wrapMode: TextEdit.Wrap
                    
                    style: TextAreaStyle {
                        backgroundColor: Theme.backgroundDark
                        textColor: Theme.textLight
                        selectionColor: Theme.selectionHighlight
                    }
                    
                    // Auto-scroll to bottom when new entries are added
                    Connections {
                        target: Logger ? Logger : null
                        enabled: Logger !== null && Logger !== undefined
                        onLogEntryAdded: {
                            if (Logger && Logger.logWindowVisible) {
                                updateLogDisplay()
                                // Scroll to bottom
                                Qt.callLater(function() {
                                    if (scrollView.flickableItem) {
                                        scrollView.flickableItem.contentY = Math.max(0, scrollView.flickableItem.contentHeight - scrollView.flickableItem.height)
                                    }
                                })
                            }
                        }
                        onLogCleared: {
                            logTextArea.text = ""
                        }
                    }
                }
            }
        }
    }
    
    // Update window visibility when isVisible property changes (from external code)
    onIsVisibleChanged: {
        // Only update visible if it's different (avoid binding loop)
        if (visible !== isVisible) {
            visible = isVisible
        }
        // Logger update is handled in onVisibleChanged to avoid duplicate assignments
    }
    
    // Center window on first show and initialize
    Component.onCompleted: {
        // Center window on screen
        var screen = Qt.application.screens.length > 0 ? Qt.application.screens[0] : null
        if (screen) {
            x = (screen.width - width) / 2
            y = (screen.height - height) / 2
        }
        // Initialize Logger visibility state
        if (Logger) {
            Logger.logWindowVisible = isVisible
            // Initialize log display
            updateLogDisplay()
        }
    }
}
