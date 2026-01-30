/**
 * @file CircularProgressbar.qml
 * @brief Circular progress indicator for displaying rendering progress
 * 
 * A circular progress bar component used in table rows to show rendering
 * progress for individual events. Displays:
 * - Progress percentage as a circular arc
 * - Phase name in the center (e.g., "Processing", "Finished", "ERROR")
 * - Color-coded states (orange for in-progress, green for finished, red for error)
 * 
 * The component uses Canvas for drawing the circular arc and automatically
 * updates when progress values change. It's designed to be embedded in
 * table cells to provide visual feedback during batch rendering operations.
 */

import QtQml 2.2
import QtQuick 2.7
import Theme 1.0

Item {
    anchors.fill: parent
    
    property int currentValue: 0  // Progress value (0-100)
    property string progressText: "Processing"  // Text to display in center
    property bool isActive: false  // Whether progress bar should be visible
    
    // Colors
    property color primaryColor: Theme.chartMark  // Background arc color
    property color secondaryColor: Theme.primaryAccent  // Progress arc color
    property color textColor: Theme.statusErrorAlt  // Text color
    
    visible: isActive && currentValue >= 0 && currentValue <= 100
    
    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        
        property real centerWidth: width / 2
        property real centerHeight: height / 2
        property real radius: Math.min(canvas.width, canvas.height) / 2 - 4  // Leave some margin
        
        property real minimumValue: 0
        property real maximumValue: 100
        
        // Start at 12 o'clock (top of circle)
        property real angleOffset: -Math.PI / 2
        
        // Bind to parent's properties for reactivity
        // Note: These will always have values since parent Item defines them with defaults
        property real currentValue: parent ? parent.currentValue : 0
        property color primaryColor: parent ? parent.primaryColor : Theme.chartMark
        property color secondaryColor: parent ? parent.secondaryColor : Theme.primaryAccent
        
        // Calculate angle for progress arc (0 to 2*PI based on currentValue)
        property real angle: (currentValue - minimumValue) / (maximumValue - minimumValue) * 2 * Math.PI
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onCurrentValueChanged: requestPaint()
        onPrimaryColorChanged: requestPaint()
        onSecondaryColorChanged: requestPaint()
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.save();
            
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            // Draw background circle (lighter gray)
            ctx.beginPath();
            ctx.lineWidth = 3;
            ctx.strokeStyle = Theme.backgroundLightGray;
            ctx.arc(canvas.centerWidth,
                    canvas.centerHeight,
                    canvas.radius,
                    0,
                    2*Math.PI);
            ctx.stroke();
            
            // Draw background arc (from progress to end - shows remaining)
            ctx.beginPath();
            ctx.lineWidth = 3;
            ctx.strokeStyle = primaryColor;
            ctx.arc(canvas.centerWidth,
                    canvas.centerHeight,
                    canvas.radius,
                    angleOffset + angle,
                    angleOffset + 2*Math.PI);
            ctx.stroke();
            
            // Draw progress arc (from start to progress - shows completed)
            ctx.beginPath();
            ctx.lineWidth = 3;
            ctx.strokeStyle = secondaryColor;
            ctx.arc(canvas.centerWidth,
                    canvas.centerHeight,
                    canvas.radius,
                    angleOffset,
                    angleOffset + angle);
            ctx.stroke();
            
            ctx.restore();
        }
        
        // Text in center
        // Note: parent here is Canvas, parent.parent is the root Item with progressText property
        Text {
            id: progressText_id
            anchors.centerIn: parent
            // Directly reference root Item's progressText (parent.parent because Text -> Canvas -> Item)
            text: parent.parent ? (parent.parent.progressText || "Processing") : "Processing"
            font.pointSize: Theme.fontSizeTiny
            font.bold: true
            // Directly reference root Item's textColor
            color: parent.parent ? (parent.parent.textColor || Theme.statusErrorAlt) : Theme.statusErrorAlt
            width: Math.max(0, (parent ? parent.width : 0) - 8)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
        }
    }
    
    // Update progress value
    function setValue(value) {
        currentValue = Math.max(0, Math.min(100, value))
        // Don't modify progressText here - let the binding handle it
        // Only update colors for visual feedback
        if (value >= 99) {
            // When finished, trigger repaint (colors/text handled by bindings)
            canvas.requestPaint()
        } else if (value < 0) {
            // Error state
            progressText = "ERROR"
            textColor = Theme.statusErrorAlt
            primaryColor = Theme.statusErrorAlt
            secondaryColor = Theme.statusErrorAlt
            canvas.requestPaint()
        } else {
            // Reset colors for in-progress (but don't change text - let binding handle it)
            if (textColor !== Theme.statusErrorAlt) textColor = Theme.statusErrorAlt
            if (primaryColor !== Theme.chartMark) primaryColor = Theme.chartMark
            if (secondaryColor !== Theme.primaryAccent) secondaryColor = Theme.primaryAccent
            canvas.requestPaint()
        }
    }
    
    // Update progress text (phase name)
    function setText(txtValue) {
        if (txtValue === "Finish" || txtValue === "Finished") {
            progressText = "Finished"  // Always show "Finished" for completion
            textColor = Theme.statusSuccessAlt
            primaryColor = Theme.statusSuccessAlt
            secondaryColor = Theme.statusSuccessAlt
        } else if (txtValue === "ERROR") {
            progressText = "ERROR"
            textColor = Theme.statusErrorAlt
            primaryColor = Theme.statusErrorAlt
            secondaryColor = Theme.statusErrorAlt
        } else {
            progressText = txtValue
            textColor = Theme.statusErrorAlt  // Red/orange for in-progress
        }
        // Force Text element to update by triggering a repaint
        canvas.requestPaint()
        // Also ensure the Text element gets notified of the change
        if (progressText_id) {
            progressText_id.text = progressText
        }
    }
    
    // Reset to initial state
    function reset() {
        currentValue = 0
        progressText = "Processing"
        textColor = Theme.statusErrorAlt
        primaryColor = Theme.chartMark
        secondaryColor = Theme.primaryAccent
        isActive = true
        canvas.requestPaint()
    }
}
