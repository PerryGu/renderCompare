/**
 * @file PlaybackSpeedMenu.qml
 * @brief Reusable playback speed selection menu component
 * 
 * A floating popup menu that allows users to select different playback speeds
 * for frame progression during automatic playback.
 * 
 * The menu displays 5 speed options:
 * - 0.25x: Very slow (400ms per frame)
 * - 0.5x: Slow (200ms per frame)
 * - 1x (Normal): Default speed (100ms per frame)
 * - 2x: Fast (50ms per frame)
 * - 3x: Very fast (33ms per frame)
 * 
 * Usage:
 * ```qml
 * PlaybackSpeedMenu {
 *     id: playbackSpeedMenu
 *     playbackSpeed: parent.playbackSpeed
 *     onSpeedSelected: function(speed) {
 *         parent.playbackSpeed = speed
 *     }
 * }
 * ```
 */

import QtQuick 2.7
import QtQuick.Controls 2.0
import Theme 1.0
import Constants 1.0

Popup {
    id: playbackSpeedMenu
    
    property int playbackSpeed: Constants.playbackSpeedNormal  // Current playback speed (in ms per frame)
    
    signal speedSelected(int speed)  // Emitted when user selects a speed
    
    width: Constants.playbackSpeedMenuWidth  // Menu width in pixels
    height: Constants.playbackSpeedMenuHeight  // Menu height in pixels
    modal: true  // Blocks interaction with other UI elements when open
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside  // Closes when pressing Escape or clicking outside

    // Menu background styling - matches the floating menu style (Hue/Lig/Sat menu)
    background: Rectangle {
        border.color: Theme.primaryDark  // Dark blue border
        border.width: 2  // Border thickness
        radius: 10  // Rounded corners
        gradient: Gradient {
            // Dark gray gradient from lighter to darker
            GradientStop { position: 0; color: Theme.gradientTop }  // Top: lighter gray
            GradientStop { position: 1; color: Theme.gradientBottom }  // Bottom: darker gray
        }
    }

    // Container for all menu items
    Column {
        anchors.fill: parent  // Fill the entire popup area
        anchors.margins: 8  // 8px margin on all sides
        spacing: 4  // 4px spacing between items

        // Menu item: 0.25x speed (very slow - 400ms per frame)
        Rectangle {
            width: parent.width  // Width of column (respects menu margins)
            height: Constants.menuItemHeight  // Item height
            // Semi-transparent orange background when selected, transparent when not
            color: playbackSpeed === Constants.playbackSpeedVerySlow ? Theme.overlayChartMark : Theme.uiTransparent
            anchors.left: parent.left  // Align to left edge of column
            y: 2  // Vertical position from top

            // Click handler - sets playback speed to 400ms and closes menu
            // Speed label text
            Text {
                text: "0.25x"
                color: Theme.chartMark  // Orange/gold text color
                font.pixelSize: Theme.fontSizeSmall
                anchors.left: parent.left
                anchors.leftMargin: 10  // 10px left margin
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    playbackSpeedMenu.speedSelected(Constants.playbackSpeedVerySlow)  // 0.25x speed (4x slower than normal)
                    playbackSpeedMenu.close()
                }
            }
        }

        // Menu item: 0.5x speed (slow - 200ms per frame)
        Rectangle {
            width: parent.width  // Width of column (respects menu margins)
            height: Constants.menuItemHeight
            color: playbackSpeed === Constants.playbackSpeedSlow ? Theme.overlayChartMark : Theme.uiTransparent
            anchors.left: parent.left  // Align to left edge of column
            y: 26  // Positioned below 0.25x item

            Text {
                text: "0.5x"
                color: Theme.chartMark
                font.pixelSize: Theme.fontSizeSmall
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    playbackSpeedMenu.speedSelected(Constants.playbackSpeedSlow)  // 0.5x speed (2x slower than normal)
                    playbackSpeedMenu.close()
                }
            }
        }

        // Menu item: 1x speed (normal/default - 100ms per frame)
        Rectangle {
            width: parent.width  // Width of column (respects menu margins)
            height: Constants.menuItemHeight
            color: playbackSpeed === Constants.playbackSpeedNormal ? Theme.overlayChartMark : Theme.uiTransparent
            anchors.left: parent.left  // Align to left edge of column
            y: 50  // Positioned below 0.5x item

            Text {
                text: "1x (Normal)"  // Default playback speed
                color: Theme.chartMark
                font.pixelSize: Theme.fontSizeSmall
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    playbackSpeedMenu.speedSelected(Constants.playbackSpeedNormal)  // 1x speed (normal/default)
                    playbackSpeedMenu.close()
                }
            }
        }

        // Menu item: 2x speed (fast - 50ms per frame)
        Rectangle {
            width: parent.width  // Width of column (respects menu margins)
            height: Constants.menuItemHeight
            color: playbackSpeed === Constants.playbackSpeedFast ? Theme.overlayChartMark : Theme.uiTransparent
            anchors.left: parent.left  // Align to left edge of column
            y: 74  // Positioned below 1x item

            Text {
                text: "2x"
                color: Theme.chartMark
                font.pixelSize: Theme.fontSizeSmall
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    playbackSpeedMenu.speedSelected(Constants.playbackSpeedFast)  // 2x speed (2x faster than normal)
                    playbackSpeedMenu.close()
                }
            }
        }

        // Menu item: 3x speed (very fast - 33ms per frame)
        Rectangle {
            width: parent.width  // Width of column (respects menu margins)
            height: Constants.menuItemHeight
            color: playbackSpeed === Constants.playbackSpeedVeryFast ? Theme.overlayChartMark : Theme.uiTransparent
            anchors.left: parent.left  // Align to left edge of column
            y: 98  // Positioned below 2x item (last item in menu)

            Text {
                text: "3x"
                color: Theme.chartMark
                font.pixelSize: Theme.fontSizeSmall
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    playbackSpeedMenu.speedSelected(Constants.playbackSpeedVeryFast)  // 3x speed (3x faster than normal)
                    playbackSpeedMenu.close()
                }
            }
        }
    }
}
