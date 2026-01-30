/**
 * @file ErrorDialog.qml
 * @brief Reusable error dialog component for displaying error messages to users
 * 
 * A non-modal dialog that displays error messages in a user-friendly format.
 * Can be shown from anywhere in the application by calling the show() function.
 */

import QtQuick 2.6
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.2
import Theme 1.0

Rectangle {
    id: errorDialog
    visible: false
    anchors.fill: parent
    color: Theme.overlayDark  // Semi-transparent black overlay
    z: 10000  // Ensure it appears above all other content
    
    /**
     * @brief Show error dialog with message
     * 
     * Displays the error dialog with the specified error message.
     * The dialog appears as a modal overlay above all other content.
     * 
     * @param errorMessage - Error message text to display (empty strings are ignored)
     */
    function show(errorMessage) {
        if (errorMessage && errorMessage !== "") {
            errorText.text = errorMessage
            errorDialog.visible = true
        }
    }
    
    /**
     * @brief Hide error dialog
     * 
     * Closes the error dialog and makes it invisible.
     * Can be called programmatically or is triggered by user clicking Close or Escape.
     */
    function hide() {
        errorDialog.visible = false
    }
    
    // Close dialog when clicking on overlay
    MouseArea {
        anchors.fill: parent
        onClicked: errorDialog.hide()
    }
    
    // Dialog box
    Rectangle {
        id: dialogBox
        width: Math.min(500, parent.width - 40)
        height: Math.min(200, parent.height - 40)
        anchors.centerIn: parent
        color: Theme.backgroundDark
        border.color: Theme.chartMark  // Orange border (matches error theme)
        border.width: 2
        radius: 5
        
        Column {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10
            
            Text {
                id: errorTitle
                text: "Error"
                font.bold: true
                font.pixelSize: Theme.fontSizeDialogTitle
                color: Theme.chartMark  // Orange text (matches error theme)
            }
            
            Text {
                id: errorText
                width: dialogBox.width - 30
                text: ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.textLight
                wrapMode: Text.WordWrap
            }
            
            Item {
                width: parent.width
                height: 30
                
                Button {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Close"
                    width: 80
                    height: 30
                    
                    style: ButtonStyle {
                        background: Rectangle {
                            color: control.pressed ? Theme.primaryAccent : Theme.backgroundLight
                            border.color: Theme.chartMark
                            border.width: 1
                            radius: 3
                        }
                        label: Text {
                            text: control.text
                            color: Theme.textLight
                            font.pixelSize: Theme.fontSizeMedium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    onClicked: errorDialog.hide()
                }
            }
        }
    }
    
    // Close dialog with Escape key
    Keys.onEscapePressed: {
        errorDialog.hide()
    }
    
    // Focus handling to enable keyboard shortcuts
    Component.onCompleted: {
        errorDialog.focus = true
    }
}
