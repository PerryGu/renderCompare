/**
 * @file ImageItem.qml
 * @brief Reusable image display component with zoom, pan, and image effects
 * 
 * A sophisticated image component used throughout the application for displaying
 * rendered images (original, test, difference, and alpha). Provides:
 * - Zoom and pan functionality with mouse/touch gestures
 * - Image mark synchronization across multiple views
 * - Context menu for image effects (hue, saturation, lightness, opacity)
 * - Smooth animations for zoom reset and context menu fade
 * - Double-buffered image loading via ReloadedAllImages component
 * 
 * This component is used in:
 * - TopLayout_three.qml (3-window comparison view)
 * - TopLayout_one.qml (single window view)
 * 
 * The component supports four image types:
 * - imageA: Original/expected render
 * - imageB: Test/actual render
 * - imageC: Difference visualization
 * - imageD: Alpha/mask overlay
 */

import QtQuick 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.2
import "utils.js" as Utils
import Theme 1.0
import Logger 1.0



Rectangle {
    id:imageItem_id
    anchors.fill: parent
    property string imagePathA
    property string imagePathB
    property string imagePathC
    property string imagePathD

    property string pathIndex
    property string imageType

    property real val_m_x1
    property real val_m_y1
    property real val_m_y2
    property real val_m_x2
    property real val_m_zoom1
    property real val_m_zoom2
    property real val_m_max
    property real val_m_min
    property real val_xMouse
    property real val_yMouse

    property real imageMarkMove_x
    property real imageMarkMove_y
    property var mainItemRef: null

    property real m_x1: val_m_x1
    property real m_y1: val_m_y1
    property real m_y2: val_m_y2
    property real m_x2: val_m_x2
    property real m_zoom1: val_m_zoom1
    property real m_zoom2: val_m_zoom2
    property real m_max: val_m_max
    property real m_min: val_m_min
    property real x_changed: val_xMouse
    property real y_changed: val_yMouse
    property alias imageMove_x: imageHoldId.x
    property alias imageMove_y: imageHoldId.y
    property bool contextMenuHolderVisible:false


    /**
     * @brief Set the image position (for panning)
     * @param x - X coordinate for image position
     * @param y - Y coordinate for image position
     */
    function  setImageMove(x, y){
        imageMove_x = x
        imageMove_y = y
    }

    /**
     * @brief Get the current image position
     * 
     * Retrieves the current image position and stores it in val_xMouse/val_yMouse
     * for synchronization with other images.
     */
    function  getImageMove(){
        val_xMouse = imageMove_x
        val_yMouse = imageMove_y
    }

    /**
     * @brief Handle mouse movement and synchronize with other images
     * 
     * When user drags an image, this function synchronizes the pan position
     * across all three images in the 3-window view (A, B, C). This ensures
     * all images stay aligned when panning.
     * 
     * Note: imageD (single large window) does not participate in synchronization.
     * 
     * @param x_changed - New X position
     * @param y_changed - New Y position
     */
    function mouseXYChanged(x_changed, y_changed){
        //-- send proc to other images ------------
        if (imageType != "imageD"){
            imageThree_id.updateMouseMoveVal(imageType, x_changed, y_changed)
        }
    }

    /**
     * @brief Unlock image from UI constraints to enable panning/zooming
     * 
     * Removes the anchor fill constraint, allowing the image to be moved
     * and zoomed independently of its container.
     */
    function undefinedAnchors(){
        imageHoldId.anchors.fill = undefined
    }

    /**
     * @brief Reset zoom to 1:1 and re-lock image to UI
     * 
     * Resets zoom level to 1.0 and re-applies anchor fill constraint,
     * locking the image back to its default position and size.
     */
    function resetZoomAndReDfinedAnchors(){
        imageItem_id.m_zoom2 =  1
        imageHoldId.anchors.fill = rect
    }

    /**
     * @brief Handle mouse wheel zoom and synchronize with other images
     * 
     * Called when user scrolls mouse wheel over the image. Updates zoom level
     * and synchronizes both position and zoom with other images in the 3-window view.
     * 
     * @param val - Unused parameter (legacy)
     */
    function mouseWheel(val){
        //--call getImageMove ---------
        getImageMove()
        //-- send proc mouse movment and zoom param to other images --------------
        if (imageType != "imageD"){
            imageThree_id.updateMouseMoveVal(imageType, val_xMouse, val_yMouse)
            imageThree_id.updateZoomVal(imageType, m_x1, m_y1, m_y2, m_x2, m_zoom1, m_zoom2, m_max, m_min )
        }
    }

    /**
     * @brief Start reset zoom animation
     * 
     * Initiates the animated zoom reset. Also triggers reset animation
     * on other images in the 3-window view for synchronized behavior.
     * 
     * @param val - Unused parameter (legacy)
     */
    function mousePressResetZoom(val){
        zoomAnim_Id.start()
        //-- send proc anim activition to other images --------------
        if (imageType != "imageD"){
            imageThree_id.resetZoomAnim(imageType)
        }
    }
    
    /**
     * @brief Start reset zoom animation (called from other images)
     * 
     * Called when another image in the 3-window view starts a reset animation.
     * Ensures all images reset zoom synchronously.
     */
    function resetZoomAnim(){
        zoomAnim_Id.start()
    }

    /**
     * @brief Handle zoom animation completion
     * 
     * Called when the reset zoom animation finishes. Resets zoom and anchors,
     * and synchronizes with other images.
     */
    function zoomAnimFinish(){
        resetZoomAndReDfinedAnchors()
        //-- send proc to other images ------------
        if (imageType != "imageD"){
            imageThree_id.dfinedAnchorsAndRsetZoom() }
    }

    //-- Set fade On ContextMenAnim  ----------------
    function fadeOnContextMenuAnim(){
        if (imageType == Utils.IMAGE_COMPONENT_C || imageType == Utils.IMAGE_COMPONENT_D){
            contextMenuHolderVisible = true
            fadeOnContextMenuAnim_id.start()
        }
    }

    //-- Set fade Off ContextMenAnim  ----------------
    function fadeOffContextMenuAnim(){
        if (contextMenu_id.opacity === 0.7){
            fadeOffContextMenuAnim_id.start()
            contextMenuHolderVisible = false
        }
    }

    //-- Get Image Marks visible and send to other images  -----
    function getVisibleImageMark(val){
        if (imageType != "imageD"){
            imageMark_Id.visible = val
            imageThree_id.visibleImageMark(imageType, val)
        } else {
            // For imageD (page 3), show crosshair directly
            imageMark_Id.visible = val
        }
    }

    //-- Set Image Marks visible  and send to other images  -----
    function setVisibleImageMark(val){
        imageMark_Id.visible = val
    }

    //-- Get Image Marks movment and send to other images  -----
    // - X -
    function getMoveImageMarkX(val){
        if (imageType != "imageD"){
            imageThree_id.moveImageMarkX(imageType, val)
        }
    }

    function getMoveImageMarkY(val){
        if (imageType != "imageD"){
            imageThree_id.moveImageMarkY(imageType, val)
        }
    }

    //-- Set Image Marks movment from other images  -----
    //- X -
    function setMoveImageMarkX(val){
        imageTargetMark_Id.x = val - (imageTargetMark_Id.width/2)
    }
    //- Y -
    function setMoveImageMarkY(val){
        imageTargetMark_Id.y = val -(imageTargetMark_Id.width/2)
    }

    /**
     * @brief Initialize image loading when a new project is selected
     * 
     * Called when user selects an event set. Delegates to ReloadedAllImages
     * component to create and initialize the appropriate image component.
     * 
     * @param startFrame - First frame number in sequence (0-indexed)
     * @param endFrame - Last frame number in sequence (0-indexed)
     * @param pathImageA - Base path for original images
     * @param pathImageB - Base path for test images
     * @param pathImageC - Base path for difference images
     * @param pathImageD - Base path for alpha/mask images
     */
    function startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD){
        reloadedAllImages_Id.startLoadAllImages(startFrame, endFrame, pathImageA, pathImageB, pathImageC, pathImageD)
    }
    //****************************************************************


    //-- zoom fade ON context Menue  ----------------------
    NumberAnimation{
        id: fadeOnContextMenuAnim_id
        target: contextMenu_id
        property:"opacity"
        from: 0; to: 0.7
        duration: 600
    }

    //-- zoom fade OFF context Menue  ----------------------
    NumberAnimation{
        id: fadeOffContextMenuAnim_id
        target: contextMenu_id
        property:"opacity"
        from: 0.7; to: 0
        duration: 300
    }

    //-- zoom animation param ----------------------
    ParallelAnimation{
        id:zoomAnim_Id
        onRunningChanged: {
            if (!zoomAnim_Id.running) {
                zoomAnimFinish()}
        }
        NumberAnimation{
            target: imageHoldId
            property: "x"
            from: imageMove_x; to: 0
            duration: 400
        }
        NumberAnimation{
            target: imageHoldId
            property: "y"
            from: imageMove_y; to: 0
            duration: 400
        }

        NumberAnimation{
            target: imageItem_id
            property: "m_zoom2"
            from: m_zoom2; to: 1
            duration: 400
        }
        NumberAnimation{
            target: imageItem_id
            property: "m_zoom1"
            from: m_zoom1; to: 0.5
            duration: 400
        }
        NumberAnimation{
            target: imageItem_id
            property: "m_x1"
            from: m_x1; to: 0
            duration: 400
        }
        NumberAnimation{
            target: imageItem_id
            property: "m_y1"
            from: m_y1; to: 0
            duration: 400
        }
        NumberAnimation{
            target: imageItem_id
            property: "m_x2"
            from: m_x2; to: 0
            duration: 400
        }
        NumberAnimation{
            target: imageItem_id
            property: "m_y2"
            from: m_y2; to: 0
            duration: 400
        }
    }

    Rectangle {
        id:imageBackgroundId
        anchors.fill: parent

        Rectangle {
            id: rect
            color: Theme.primaryDark
            anchors.left: leftFrameRectId.right
            anchors.right: rightFrameRectId.left
            anchors.top: topFrameRectId.bottom
            anchors.bottom: bottomFrameRectId.top

            Rectangle {
                id:imageHoldId
                anchors.fill: parent
                onXChanged: {
                    if (dragArea.drag.active){
                        mouseXYChanged(x, y)
                    }
                }
                onYChanged: {
                    if (dragArea.drag.active) {
                        mouseXYChanged(x, y)
                    }
                }

                Rectangle {
                    id: mapImage_Id
                    anchors.fill: parent
                    clip:true
                    ReloadedAllImages{ id:reloadedAllImages_Id; imagePathA:imagePathA; imagePathB:imagePathB; imagePathC:imagePathC; imagePathD:imagePathD; image_type:imageType}
                    Item{
                        id: imageMark_Id
                        visible : false
                        Image{
                            id:imageTargetMark_Id
                            source: "/images/target.png"
                            x: 0
                            y: 0
                            width: 50
                            height: 50
                        }
                    }
                }

                transform: Scale {
                    id: scaler_Id
                    origin.x: imageItem_id.m_x2
                    origin.y: imageItem_id.m_y2
                    xScale: imageItem_id.m_zoom2
                    yScale: imageItem_id.m_zoom2
                }

                PinchArea {
                    id: pinchArea
                    anchors.fill: parent
                    onPinchStarted: {
                        m_x1 = scaler_Id.origin.x
                        m_y1 = scaler_Id.origin.y
                        m_x2 = pinch.startCenter.x
                        m_y2 = pinch.startCenter.y
                        imageHoldId.x = imageHoldId.x + (imageItem_id.m_x1-imageItem_id.m_x2)*(1-imageItem_id.m_zoom1)
                        imageHoldId.y = imageHoldId.y + (imageItem_id.m_y1-imageItem_id.m_y2)*(1-imageItem_id.m_zoom1)
                    }

                    onPinchUpdated: {
                        m_zoom1 = scaler_Id.xScale
                        var dz = pinch.scale-pinch.previousScale
                        var newZoom = m_zoom1+dz
                        if (newZoom <= m_max && newZoom >= m_min) {
                            m_zoom2 = newZoom
                        }
                    }

                }

                MouseArea {
                    id: dragArea
                    hoverEnabled: true
                    anchors.fill: parent
                    drag.target: imageHoldId
                    drag.filterChildren: true
                    onEntered: {
                        getVisibleImageMark(1)
                    }
                    onExited: {
                        getVisibleImageMark(0)
                    }
                    onPositionChanged: {
                        // onPositionChanged fires on hover when hoverEnabled: true
                        // This is the correct signal for tracking mouse movement without button press
                        imageTargetMark_Id.x = mouseX - (imageTargetMark_Id.width/2)
                        imageTargetMark_Id.y = mouseY - (imageTargetMark_Id.width/2)
                        getMoveImageMarkX(mouseX)
                        getMoveImageMarkY(mouseY)
                    }
                    onMouseXChanged: {
                        // Fallback for compatibility
                        imageTargetMark_Id.x = mouseX-(imageTargetMark_Id.width/2)
                        getMoveImageMarkX(mouseX)
                    }
                    onMouseYChanged: {
                        // Fallback for compatibility
                        imageTargetMark_Id.y = mouseY-(imageTargetMark_Id.width/2)
                        getMoveImageMarkY(mouseY)
                    }

                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked:{
                        if (mouse.button == Qt.RightButton){
                            if (imageType == Utils.IMAGE_COMPONENT_C | imageType == Utils.IMAGE_COMPONENT_D){
                                Logger.debug("[UI] Image context menu opened: " + imageType)
                                contextMenu_id.x = mouseX
                                contextMenu_id.y = mouseY
                                fadeOnContextMenuAnim()
                            }

                            if (imageType == Utils.IMAGE_COMPONENT_C){
                                contextMenu_id.height = 140
                                valSliderOpa_Id.opacity = 0
                                textOpasSld_Id.opacity = 0
                            }
                            if (imageType == Utils.IMAGE_COMPONENT_D){
                                contextMenu_id.height = 180
                                valSliderOpa_Id.opacity = 1
                                textOpasSld_Id.opacity = 1
                            }
                        }

                        if (mouse.button === Qt.LeftButton){
                            fadeOffContextMenuAnim()
                            mousePressResetZoom()
                            //contextMenuHolder_id.contextMenu_id.opacity = 0
                            contextMenu_id.opacity = 0
                        }

                        if (mouse.button === Qt.MiddleButton){
                            if (imageType === Utils.IMAGE_COMPONENT_D){
                                Logger.info("[UI] Image D switched (middle-click)")
                                reloadedAllImages_Id.imageSwitchOnTypeD()
                                imageOne_id.changeFreeDViewVer_text()
                            }
                        }
                    }

                    onWheel: {
                        undefinedAnchors()
                        imageItem_id.m_x1 = scaler_Id.origin.x
                        imageItem_id.m_y1 = scaler_Id.origin.y
                        imageItem_id.m_zoom1 = scaler_Id.xScale
                        imageItem_id.m_x2 = mouseX
                        imageItem_id.m_y2 = mouseY

                        var newZoom
                        if (wheel.angleDelta.y > 0) {
                            newZoom = imageItem_id.m_zoom1+0.1
                            if (newZoom <= imageItem_id.m_max) {
                                imageItem_id.m_zoom2 = newZoom
                            } else {
                                imageItem_id.m_zoom2 = imageItem_id.m_max
                            }
                        } else {
                            newZoom = imageItem_id.m_zoom1-0.1
                            if (newZoom >= imageItem_id.m_min) {
                                imageItem_id.m_zoom2 = newZoom
                            } else {
                                imageItem_id.m_zoom2 = imageItem_id.m_min
                            }
                        }
                        imageHoldId.x = imageHoldId.x + (imageItem_id.m_x1-imageItem_id.m_x2)*(1-imageItem_id.m_zoom1)
                        imageHoldId.y = imageHoldId.y + (imageItem_id.m_y1-imageItem_id.m_y2)*(1-imageItem_id.m_zoom1)

                        mouseWheel()

                    }
                }
            }
        }

        //-- create the floating manue to modify Hue / Lig / Sat of the deff image -------------
        Item {
            id: contextMenuHolder_id
            anchors.fill: imageBackgroundId
            visible : contextMenuHolderVisible

            Rectangle {
                id: contextMenu_id
                x:x
                y:100
                width: 120
                height: 180
                border.color: Theme.primaryDark
                border.width: 2
                radius: 10
                opacity: 0

                gradient:  Gradient {
                    GradientStop { position: 0; color: Theme.gradientTop }
                    GradientStop { position: 1; color: Theme.gradientBottom }
                }

                MouseArea {
                    id: contextMenuDragArea_id
                    hoverEnabled: true
                    anchors.fill: parent
                    drag.target: contextMenu_id
                    drag.filterChildren: true}


                // --- Hue sld -----------------
                Text {
                    id: hueText
                    text:"Hue"
                    color: Theme.chartMark
                    font.pixelSize: Theme.fontSizeSmall
                    x:10
                    y:10
                }
                MouseArea {
                    anchors.fill: hueText
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                            imageItem_id.mainItemRef.setTooltip("Adjust hue (color tone)")
                        }
                    }
                    onExited: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                            imageItem_id.mainItemRef.clearTooltip()
                        }
                    }
                }

                Slider {
                    id:valSliderHue_Id
                    Accessible.role: Accessible.Slider
                    value: 1.0
                    minimumValue: -1.0
                    maximumValue: 1.0
                    updateValueWhileDragging :true
                    width: parent.width -20
                    x:10
                    y:30
                    style: SliderStyle {
                        handle: Item {
                            Rectangle {
                                id:handleHue_Id
                                color: Theme.chartMark
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                radius: 30
                            }
                        }
                    }

                    onValueChanged: {
                        Logger.debug("[UI] Image " + imageType + " hue changed: " + valSliderHue_Id.value.toFixed(2))
                        imageItem_id.hueSlider(valSliderHue_Id.value)
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        onEntered: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                                imageItem_id.mainItemRef.setTooltip("Adjust hue (color tone)")
                            }
                        }
                        onExited: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                                imageItem_id.mainItemRef.clearTooltip()
                            }
                        }
                    }
                }

                // --- Lightness sld -----------------
                Text {
                    id: ligText
                    text:"Lig"
                    color: Theme.chartMark
                    font.pixelSize: Theme.fontSizeSmall
                    x:10
                    y:50
                }
                MouseArea {
                    anchors.fill: ligText
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                            imageItem_id.mainItemRef.setTooltip("Adjust lightness (brightness)")
                        }
                    }
                    onExited: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                            imageItem_id.mainItemRef.clearTooltip()
                        }
                    }
                }
                Slider {
                    id:valSliderLight_Id
                    Accessible.role: Accessible.Slider
                    value: 0.15
                    minimumValue: -1.0
                    maximumValue: 1.0
                    updateValueWhileDragging :true
                    width: parent.width -20
                    x:10
                    y:70
                    style: SliderStyle {
                        handle: Item {
                            Rectangle {
                                id:handleLight_Id
                                color: Theme.chartMark
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                radius: 30
                            }
                        }
                    }

                    onValueChanged: {
                        Logger.debug("[UI] Image " + imageType + " lightness changed: " + valSliderLight_Id.value.toFixed(2))
                        imageItem_id.lightSlider(valSliderLight_Id.value)
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        onEntered: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                                imageItem_id.mainItemRef.setTooltip("Adjust lightness (brightness)")
                            }
                        }
                        onExited: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                                imageItem_id.mainItemRef.clearTooltip()
                            }
                        }
                    }
                }

                //-- Saturation sld -----------------
                Text {
                    id: satText
                    text:"Sat"
                    color: Theme.chartMark
                    font.pixelSize: Theme.fontSizeSmall
                    x:10
                    y:90
                }
                MouseArea {
                    anchors.fill: satText
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                            imageItem_id.mainItemRef.setTooltip("Adjust saturation (color intensity)")
                        }
                    }
                    onExited: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                            imageItem_id.mainItemRef.clearTooltip()
                        }
                    }
                }
                Slider {
                    id:valSliderSat_Id
                    Accessible.role: Accessible.Slider
                    value: 0.5
                    minimumValue: -1.0
                    maximumValue: 1.0
                    updateValueWhileDragging :true
                    width: parent.width -20
                    x:10
                    y:110
                    style: SliderStyle {
                        handle: Item {
                            Rectangle {
                                id:handleSat_Id
                                color: Theme.chartMark
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                radius: 30
                            }
                        }
                    }

                    onValueChanged: {
                        Logger.debug("[UI] Image " + imageType + " saturation changed: " + valSliderSat_Id.value.toFixed(2))
                        imageItem_id.saturationSlider(valSliderSat_Id.value)
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        onEntered: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                                imageItem_id.mainItemRef.setTooltip("Adjust saturation (color intensity)")
                            }
                        }
                        onExited: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                                imageItem_id.mainItemRef.clearTooltip()
                            }
                        }
                    }
                }

                //-- Opasety sld -----------------
                Text {
                    id:textOpasSld_Id
                    text:"Op"
                    color: Theme.chartMark
                    font.pixelSize: Theme.fontSizeSmall
                    x:10
                    y:132
                    opacity: 0
                }
                MouseArea {
                    anchors.fill: textOpasSld_Id
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    enabled: textOpasSld_Id.opacity > 0
                    onEntered: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                            imageItem_id.mainItemRef.setTooltip("Adjust opacity (transparency)")
                        }
                    }
                    onExited: {
                        if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                            imageItem_id.mainItemRef.clearTooltip()
                        }
                    }
                }
                Slider {
                    id:valSliderOpa_Id
                    Accessible.role: Accessible.Slider
                    value: 0.5
                    minimumValue: 0
                    maximumValue: 1.0
                    updateValueWhileDragging :true
                    width: parent.width -20
                    x:10
                    y:152
                    opacity: 0
                    style: SliderStyle {
                        handle: Item {
                            Rectangle {
                                id:handleOpa_Id
                                color: Theme.chartMark
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                radius: 30
                            }
                        }
                    }

                    onValueChanged: {
                        Logger.debug("[UI] Image " + imageType + " opacity changed: " + valSliderOpa_Id.value.toFixed(2))
                        imageItem_id.opacitySlider(valSliderOpa_Id.value)
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        enabled: valSliderOpa_Id.opacity > 0
                        onEntered: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.setTooltip === "function") {
                                imageItem_id.mainItemRef.setTooltip("Adjust opacity (transparency)")
                            }
                        }
                        onExited: {
                            if (imageItem_id.mainItemRef && typeof imageItem_id.mainItemRef.clearTooltip === "function") {
                                imageItem_id.mainItemRef.clearTooltip()
                            }
                        }
                    }
                }
            }
        }

        //-- create background to the image windows -----------
        Rectangle {
            id:topFrameRectId
            color: Theme.primaryDark
            height:100
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
        }

        Rectangle {
            id:bottomFrameRectId
            color: Theme.primaryDark
            height:100
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

        }
        Rectangle {
            id:leftFrameRectId
            color: Theme.primaryDark
            width:35
            anchors.bottom: parent.bottom
            anchors.top: parent.top
        }

        Rectangle {
            id:rightFrameRectId
            color: Theme.primaryDark
            width:100
            anchors.bottom: parent.bottom
            anchors.top: parent.top
            anchors.left:parent.right
            anchors.leftMargin: -25
        }
    }


    /**
     * @brief Update frame index for the image display
     * 
     * Called when user scrubs the timeline. Delegates to ReloadedAllImages
     * component to update the displayed frame.
     * 
     * @param frameIndex - 4-digit padded frame string (e.g., "0001", "0002")
     */
    function indexUpdate(frameIndex){
        reloadedAllImages_Id.indexUpdate(frameIndex)
    }

    /**
     * @brief Update hue slider value for image effects
     * @param val - Hue value (-1.0 to 1.0)
     */
    function hueSlider(val){
        reloadedAllImages_Id.hueSlider(val)
    }

    /**
     * @brief Update lightness slider value for image effects
     * @param val - Lightness value (-1.0 to 1.0)
     */
    function lightSlider(val){
        reloadedAllImages_Id.lightSlider(val)
    }

    /**
     * @brief Update saturation slider value for image effects
     * @param val - Saturation value (-1.0 to 1.0)
     */
    function saturationSlider(val){
        reloadedAllImages_Id.saturationSlider(val)
    }

    /**
     * @brief Update opacity slider value for image effects
     * @param val - Opacity value (0.0 to 1.0)
     */
    function opacitySlider(val){
        reloadedAllImages_Id.opacitySlider(val)
    }

}










