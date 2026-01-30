/**
 * @file MenuBar.qml
 * @brief Application menu bar with Tools menu
 * 
 * Standard Windows-style menu bar with Tools menu containing log window toggle.
 */

import QtQuick 2.2
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import Theme 1.0
import Logger 1.0

Rectangle {
    id: menuBar
    height: 25
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    color: Theme.primaryDark
    z: 1000  // Ensure menu bar is on top
    clip: false  // Don't clip children (menu dropdown)
    
    // Property to control log window visibility
    property bool logWindowVisible: false
    
    // Signal to notify parent when log window visibility changes
    signal logWindowVisibilityChanged(bool visible)
    
    // Signal to show/hide the tools menu (handled by parent Main.qml)
    signal showMenu()
    
    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0
        
        // Tools menu
        Rectangle {
            id: toolsMenuButton
            width: 60
            height: parent.height
            color: toolsMenuMouseArea.containsMouse ? Theme.buttonHovered : Theme.primaryDark
            border.color: Theme.uiTransparent
            
            // Property to track if menu is open (for visual feedback)
            property bool menuOpen: false
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "Tools"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.textLight
            }
            
            MouseArea {
                id: toolsMenuMouseArea
                anchors.fill: parent
                hoverEnabled: true
                z: 10  // Ensure it's above other elements
                onClicked: {
                    showMenu()  // Emit signal to parent (Main.qml) to toggle menu
                    mouse.accepted = true  // Accept the event to prevent propagation
                }
            }
        }
    }
    
    // Tools menu is now handled by parent (Main.qml) to avoid Loader clipping issues
}
