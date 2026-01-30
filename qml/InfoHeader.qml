/**
 * @file InfoHeader.qml
 * @brief Information header displaying event metadata and frame statistics
 * 
 * This component displays event information above the image views on pages 1 and 2.
 * Shows:
 * - Event ID, name, sport type, stadium name
 * - Number of frames in the sequence
 * - Minimum frame value
 * - Frame threshold value
 * - Filtered point count (frames below threshold)
 * 
 * The header also provides a tooltip area that displays detailed information
 * when hovering over chart points. There are two instances of this component:
 * - One for page 1 (3-window view)
 * - One for page 2 (single window view)
 * Both share the same chart component and need synchronized tooltips.
 */

import QtQuick 2.2
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.2
import Theme 1.0


Rectangle {
       id:infoHeader_id
       color: Theme.primaryAccent
       anchors.top: parent.top
       anchors.left: parent.left
       anchors.right: parent.right
       anchors.bottom: parent.bottom
       anchors.bottomMargin: parent.height - 84  // Extended to 84px to align with image windows start (hides white stripe)
       z:1

       property string id_val
       property string eventName_val
       property string stadiumName_val
       property string sportType_val
       property int numberOfFrames_val
       property real minVal_val
       property real frameUnderThreshold: 1.00
       property int filteredPointCount_val: 0
       property var mainItemRef: null
       property bool isPage3: false
       
       property string tooltipText: ""
       property bool tooltipActive: false
       
       /**
        * @brief Set tooltip text in info bar
        * 
        * Updates the tooltip text displayed in the info bar at the top of the view.
        * Used to show contextual information when hovering over buttons or controls.
        * 
        * @param text - Tooltip text to display
        */
       function setTooltip(text) {
           tooltipText = text
           tooltipActive = true
       }
       
       /**
        * @brief Clear tooltip text
        * 
        * Removes the tooltip text from the info bar.
        */
       function clearTooltip() {
           tooltipText = ""
           tooltipActive = false
       }

       /**
        * @brief Set minimum frame value threshold
        * 
        * Updates the threshold value used for filtering scatter points in the chart.
        * Only frames with values below this threshold are highlighted.
        * 
        * @param value - Threshold value (0.0 to 1.0)
        */
       function setMinFrameValue(value){
           frameUnderThreshold = value
       }

       /**
        * @brief Set minimum frame value and propagate to SwipeView
        * 
        * Updates the threshold value and also propagates it to the SwipeView
        * component to keep all views synchronized.
        * 
        * @param value - Threshold value (0.0 to 1.0)
        */
       function setMinFrameValueFromSwipeView(value){
           frameUnderThreshold = value
           setMinFrameValueFromListModel(value)
       }

       //-- input text for - frameUnderThreshold -----------------------------------------------------------
       Rectangle {
           id: frameUnderThresholdTextIn_id
           anchors.right: parent.right
           anchors.rightMargin: 27
           y: 15
           z:1
           width: 120
           height: 25
           color: Theme.primaryAccent
           
           // MouseArea for tooltip when hovering over the entire control (pages 2 and 3)
           MouseArea {
               anchors.fill: parent
               hoverEnabled: true
               acceptedButtons: Qt.NoButton  // Don't interfere with button/input interactions
               propagateComposedEvents: true
               z: -1  // Place behind other elements to not affect visual rendering
               onEntered: {
                   if (mainItemRef && typeof mainItemRef.setTooltip === "function") {
                       mainItemRef.setTooltip("Add \\ Subtract Val to display in Chart Render ver  incompatibility")
                   }
               }
               onExited: {
                   if (mainItemRef && typeof mainItemRef.clearTooltip === "function") {
                       mainItemRef.clearTooltip()
                   }
               }
           }

           Item {
               anchors.left: parent.left
               width: 25
               y:0
               height: 25
               
               MouseArea {
                   anchors.fill: parent
                   hoverEnabled: true
                   acceptedButtons: Qt.NoButton  // Don't interfere with button clicks
                   onEntered: {
                       if (mainItemRef && typeof mainItemRef.setTooltip === "function") {
                           mainItemRef.setTooltip("Increase threshold value (+0.01)")
                       }
                   }
                   onExited: {
                       if (mainItemRef && typeof mainItemRef.clearTooltip === "function") {
                           mainItemRef.clearTooltip()
                       }
                   }
               }
               
               Button{
                   id:plusBtn_id
                   anchors.fill: parent
                   Text {
                       anchors.centerIn: parent
                       text: "+"
                       font.pixelSize: Theme.fontSizeNormal
                       font.pointSize: Theme.fontSizeLarge
                       color: Theme.primaryDark///"#25ae88"
                   }

                   style: ButtonStyle {
                       background: Rectangle {
                           implicitWidth: 25
                           implicitHeight: 25
                           color: Theme.primaryAccent
                       }
                   }

                   onClicked: {
                       var currentVal = parseFloat(frameUnderThreshold)
                       if (isNaN(currentVal)) currentVal = 1.0
                       var newValue = Math.min(1.0, currentVal + 0.01)
                       newValue = Math.round(newValue * 100) / 100
                       setMinFrameValueFromSwipeView(newValue)
                   }
               }
           }

               //-- create the Text Input  ---------------------
           Rectangle {
               id: numberInput_id
               anchors.left: parent.left
               anchors.leftMargin: 29  // 25 (button width) + 4 (margin)
               anchors.right: parent.right
               anchors.rightMargin: 29  // 25 (button width) + 4 (margin)
               y:0
               height: 25
               TextField {
                   id: textI_id
                   anchors.fill: parent
                   font.pixelSize: Theme.fontSizeSmall
                   font.pointSize: Theme.fontSizeSmall
                   verticalAlignment: Text.AlignVCenter
                   horizontalAlignment: Text.AlignHCenter
                   text: {
                       var val = parseFloat(frameUnderThreshold)
                       return isNaN(val) ? "1.00" : val.toFixed(2)
                   }
                   inputMethodHints: Qt.ImhDigitsOnly
                   onEditingFinished: {
                       var newValue = parseFloat(text)
                       if (!isNaN(newValue)) {
                           var clampedValue = Math.max(0.0, Math.min(1.0, newValue))
                           clampedValue = Math.round(clampedValue * 100) / 100
                           setMinFrameValueFromSwipeView(clampedValue)
                       } else {
                           var val = parseFloat(frameUnderThreshold)
                           text = isNaN(val) ? "1.00" : val.toFixed(2)
                       }
                   }

                   Connections {
                       target: infoHeader_id
                       onFrameUnderThresholdChanged: {
                           var val = parseFloat(frameUnderThreshold)
                           textI_id.text = isNaN(val) ? "1.00" : val.toFixed(2)
                       }
                   }

                   style: TextFieldStyle {
                       textColor: Theme.textDark
                       background: Rectangle {
                           color: Theme.primaryAccent//"#0e2639"
                       }
                   }
               }
           }
           //-- button - subtract values from TextInput --------
           Item {
               anchors.right: parent.right
               width: 25
               y:0
               height: 25
               
               MouseArea {
                   anchors.fill: parent
                   hoverEnabled: true
                   acceptedButtons: Qt.NoButton  // Don't interfere with button clicks
                   onEntered: {
                       if (mainItemRef && typeof mainItemRef.setTooltip === "function") {
                           mainItemRef.setTooltip("Decrease threshold value (-0.01)")
                       }
                   }
                   onExited: {
                       if (mainItemRef && typeof mainItemRef.clearTooltip === "function") {
                           mainItemRef.clearTooltip()
                       }
                   }
               }
               
               Button{
                   id:minusBtn_id
                   anchors.fill: parent
                   Text {
                       anchors.centerIn: parent
                       text: "-"
                       font.pixelSize: Theme.fontSizeExtraLarge
                       font.pointSize: Theme.fontSizeExtraLarge
                       color: Theme.primaryDark
                   }

                   style: ButtonStyle {
                       background: Rectangle {
                           implicitWidth: 25
                           implicitHeight: 25
                           color: Theme.primaryAccent
                       }
                   }

                   onClicked: {
                       var currentVal = parseFloat(frameUnderThreshold)
                       if (isNaN(currentVal)) currentVal = 1.0
                       var newValue = Math.max(0.0, currentVal - 0.01)
                       newValue = Math.round(newValue * 100) / 100
                       setMinFrameValueFromSwipeView(newValue)
                   }
               }
           }
       }

       Text{
            id: infoText
            text: "  id: " + id_val + "     |     EventName: " + eventName_val + "     |     Sport Type: " + sportType_val + "     |     Stadium Name: " + stadiumName_val + "     |     Total Number Frames: " + numberOfFrames_val + "     |     MinVal: " + minVal_val + "     |     Num of frames under: " + filteredPointCount_val
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: frameUnderThresholdTextIn_id.left
            anchors.rightMargin: 10
            height: parent.height / 2
            font.pointSize: Theme.fontSizeExtraSmall
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
        
        // Tooltip text line - appears below the info line
        Text{
            id: tooltipTextDisplay
            text: {
                if (tooltipActive && tooltipText !== "") {
                    return tooltipText
                }
                return ""
            }
            anchors.top: infoText.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.leftMargin: 10  // Move a few pixels to the right to align with text above
            anchors.right: frameUnderThresholdTextIn_id.left
            anchors.rightMargin: 10
            height: infoText.height  // Same height as info line
            font.pointSize: Theme.fontSizeExtraSmall
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            // No color specified - uses default text color to match infoText above
        }
        
        // MouseArea for tooltip when hovering over info bar text area (page 3 only)
        MouseArea {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: frameUnderThresholdTextIn_id.left
            anchors.bottom: parent.bottom
            hoverEnabled: true
            acceptedButtons: Qt.NoButton  // Don't interfere with any interactions
            propagateComposedEvents: true
            onEntered: {
                // Only show this tooltip on page 3
                if (isPage3 && mainItemRef && typeof mainItemRef.setTooltip === "function") {
                    mainItemRef.setTooltip("Pressing the right button in the main window to the menu")
                }
            }
            onExited: {
                if (mainItemRef && typeof mainItemRef.clearTooltip === "function") {
                    mainItemRef.clearTooltip()
                }
            }
        }

    }

