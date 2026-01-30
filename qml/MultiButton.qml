/**
 * @file MultiButton.qml
 * @brief Reusable button component with customizable appearance and states
 * 
 * A simple, reusable button component used throughout the application.
 * Supports customizable text, colors, and alignment. Provides visual feedback
 * for pressed states and can be enabled/disabled.
 * 
 * Properties:
 * - text: Button label text
 * - bgColor: Background color (default: transparent)
 * - bgColorSelected: Background color when pressed (default: blue)
 * - textColor: Text color (default: white)
 * - enabled: Whether button is clickable
 * - active: Whether button is in active state
 * - horizontalAlign: Text alignment (left, center, right)
 * 
 * Emits:
 * - clicked: Signal emitted when button is clicked
 */

import QtQuick 2.0
import Theme 1.0

Rectangle {
    id: root
    color: Theme.uiTransparent
    height: itemHeight
    width: itemWidth

    property string text
    property color bgColor: Theme.uiTransparent
    property color bgColorSelected: Theme.selectionHighlight
    property color textColor: Theme.textLight
    property alias enabled: mouseArea.enabled
    property bool active: true
    property alias horizontalAlign: text.horizontalAlignment

    signal clicked

    Rectangle {
        anchors { fill: parent; margins: 10 }
        color: mouseArea.pressed ? bgColorSelected : bgColor

        Text {
            id: text
            clip: true
            text: root.text
            anchors { fill: parent; margins: scaledMargin }
            font.pixelSize: fontSize
            color: textColor
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: mouseArea
            onClicked: root.clicked()
        }
    }
}
