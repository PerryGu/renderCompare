import QtQuick 2.2
import Theme 1.0

// DoubleBufferedImage - Reusable component for smooth image transitions
// This component implements double-buffering to prevent flicker during image changes.
// It maintains two image buffers and swaps them when new images are ready.
//
// Usage:
//   DoubleBufferedImage {
//       id: imageDisplay
//       onImageReady: { // optional callback }
//   }
//   imageDisplay.updateImage("file:///path/to/image.jpg")
Item {
    id: root
    
    // Public API
    property alias fillMode: buffer1Image.fillMode
    property bool showLoadingText: false
    property string loadingText: "Loading Images!"
    
    // Expose image sources for effects (e.g., HueSaturation)
    readonly property string currentImageSource: frontBuffer === 1 ? buffer1Source : buffer2Source
    readonly property var currentImage: frontBuffer === 1 ? buffer1Image : buffer2Image
    
    property int frontBuffer: 1
    property int backBuffer: 2
    property string buffer1Source: ""
    property string buffer2Source: ""
    property string requestedFrame: ""
    
    signal imageReady()
    signal imageError(string source)
    
    /**
     * @brief Update the displayed image using double-buffering
     * 
     * Loads a new image into the back buffer while keeping the current image
     * visible in the front buffer. When the new image finishes loading, the
     * buffers are swapped automatically. This prevents flicker and provides
     * smooth transitions during rapid frame scrubbing.
     * 
     * The function tracks the requested frame to prevent stale images from
     * being displayed if the user scrubs faster than images can load.
     * 
     * @param imagePath - Full file path to the image (file:/// URL format)
     */
    function updateImage(imagePath) {
        requestedFrame = imagePath
        
        // Double-buffering: Load new image into back buffer (without clearing front buffer)
        if (frontBuffer === 1) {
            // Currently showing buffer 1, load new image into buffer 2
            buffer2Source = imagePath
            // Keep buffer1Source unchanged so old image stays visible
        } else {
            // Currently showing buffer 2, load new image into buffer 1
            buffer1Source = imagePath
            // Keep buffer2Source unchanged so old image stays visible
        }
    }
    
    // Loading indicator
    Text {
        id: loadingTextItem
        text: root.loadingText
        anchors.centerIn: parent
        font.family: "Helvetica"
        font.pointSize: Theme.fontSizeMedium
        color: Theme.statusError
        visible: root.showLoadingText && 
                 (buffer1Image.status !== Image.Ready && buffer1Image.status !== Image.Null) && 
                 (buffer2Image.status !== Image.Ready && buffer2Image.status !== Image.Null)
        z: 20
    }
    
    // Buffer 1 - keeps its image until new one is ready
    Rectangle {
        id: buffer1
        anchors.fill: parent
        color: Theme.uiTransparent
        z: frontBuffer === 1 ? 2 : 1
        
        Image {
            id: buffer1Image
            anchors.fill: parent
            source: buffer1Source
            fillMode: Image.PreserveAspectFit
            asynchronous: false  // Synchronous for immediate display during scrubbing
            cache: false  // Disable cache - we're loading directly from disk each time
            
            // When buffer 1 finishes loading and it's the back buffer, swap to front
            // Only swap if this is still the most recently requested frame (prevents stale swaps during scrubbing)
            onStatusChanged: {
                if (status === Image.Ready && frontBuffer === 2 && buffer1Source !== "" && buffer1Source === requestedFrame) {
                    // New image in buffer 1 is ready AND it's still the most recent request, swap it to front
                    frontBuffer = 1
                    backBuffer = 2
                    root.imageReady()
                } else if (status === Image.Error) {
                    root.imageError(buffer1Source)
                }
            }
        }
    }
    
    // Buffer 2 - keeps its image until new one is ready
    Rectangle {
        id: buffer2
        anchors.fill: parent
        color: Theme.uiTransparent
        z: frontBuffer === 2 ? 2 : 1
        
        Image {
            id: buffer2Image
            anchors.fill: parent
            source: buffer2Source
            fillMode: Image.PreserveAspectFit
            asynchronous: false  // Synchronous for immediate display during scrubbing
            cache: false  // Disable cache - we're loading directly from disk each time
            
            // When buffer 2 finishes loading and it's the back buffer, swap to front
            // Only swap if this is still the most recently requested frame (prevents stale swaps during scrubbing)
            onStatusChanged: {
                if (status === Image.Ready && frontBuffer === 1 && buffer2Source !== "" && buffer2Source === requestedFrame) {
                    // New image in buffer 2 is ready AND it's still the most recent request, swap it to front
                    frontBuffer = 2
                    backBuffer = 1
                    root.imageReady()
                } else if (status === Image.Error) {
                    root.imageError(buffer2Source)
                }
            }
        }
    }
}

