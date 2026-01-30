/**
 * @file TopLayout_zero.qml
 * @brief Page 0: Main table view for event selection and management
 * 
 * This is the first page (index 0) of the application's swipe view, displaying
 * a table of all available event sets. Users can:
 * - Browse and search through events
 * - Filter by FreeDView version
 * - Select events to compare (double-click to open)
 * - Edit event metadata (sport type, stadium, category, notes)
 * - Launch FreeDView tester for rendering
 * - Toggle visibility of "Not Rendered" events
 * 
 * Key features:
 * - FreeDView version filtering via combo box
 * - Global search across all columns
 * - Row selection and double-click to open event
 * - Context menus for editing cell values
 * - Progress bars for rendering status
 * - Integration with C++ backend (XmlDataModel, IniReader, TesterRunner)
 */

import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.3
import QtQuick.Controls.Styles 1.2
import QtQml 2.2

Rectangle {
    id: zero_id
    anchors.fill: parent
    focus: true  // Enable keyboard focus for Ctrl+F handling
    
    // Reference to mainItem (set by parent TheSwipeView)
    property var mainItem: null
    
    // Keyboard shortcuts
    Keys.onPressed: {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
            // Focus the upper search field in MainTableViewHeader
            if (mainHeader_id) {
                mainHeader_id.focusSearchField()
            }
            event.accepted = true
        }
    }
    
    // Try to fill comboBox when component is ready
    Component.onCompleted: {
        // Wait a bit for everything to initialize, then try to fill comboBox
        Qt.callLater(function() {
            if (xmlDataModel && xmlDataModel.rowCount > 0) {
                fillFDVComboBox()
            }
        })
    }

    property int startFrame: 0
    property int endFrame: 0
    property real minVal: 0.0
    property real maxVal: 0.0
    property var frameList_frame: []
    property var frameList_val: []
    property var outputAllPathList: []
    property var outputPathList: []
    property real frameUnderThreshold: 1.00
    property var xmlPathList: []
    property var eventNameList: []
    property var eventSetList: []
    property var sportTypeList: []
    property var stadiumNameList: []
    property var categoryNameList: []
    property string renderStatus: ""
    property string id_val: ""
    property string eventName: ""
    property string stadiumName: ""
    property string sportType: ""
    property string categoryName: ""
    property int numberOfFrames: 0
    property int frame_index: 0
    property var numberOfFrames_list: []
    property var minFramVal_list: []
    property var minFram_list: []
    property var numberOfFrameUnder_list: []
    property var notesList: []
    property string notes: ""
    property var origList: []
    property var sortList: []
    property string origFreeDViewName: ""
    property string testFreeDViewName: ""
    property int numberOfItem: 0
    property string notesInputText: "undefined"
    property var notesListArray: []
    property string notesString: ""
    property var listModelComboBoxId
    property var comboBoxList: []
    property int selectedComboBoxIndex: 0
    property var freeDViewVer_list: []
    property var freeDViewSingleVer_list: []
    property var renderStatusList: []
    property var newRenderStatusList: []
    property int displayHideNoRendered: 0
    property int selectedFreeDViewVerIndex: 0
    property string selectedFreeDViewName: ""
    property var styleData
    property var imageIconSourceList: []
    property string imageIconSource: "/images/v2.png"
    property var iconProgressBarSwitch
    property var iconLoaderId
    property string origFreeDView: ""
    property string testFreeDView: ""
    property var eventValidToRenderList: []
    property var eventIndexValidToRenderList: []
    property var progressBarLoaderList: []
    property var endEventSetProcessList: []
    property var endEventSetStatusProcessList: []
    property var comboBoxLoaderList: []
    property var textFieldLoaderList: []
    property var thumbnailPathList: []
    property bool imageVisCol: false
    property bool allRowsProgressBar: false


    //-- The table View ---------------
    Rectangle {
        id:modelViewHold_id
        anchors.top: parent.top
        anchors.topMargin: 34  // Reduced by 20% then another 15% (from 50 to 40 to 34) to make header bar thinner
        anchors.bottom: parent.bottom
        anchors.left:parent.left
        anchors.right:parent.right


        //=== Load tableview.qml ===========================================================================
        Loader {
            id: tableViewLoader
            anchors.fill: parent
            source: "qrc:/qml/TableviewHandlers.qml"
            onLoaded: {
                // Set reference in mainItem for tooltip access
                if (item && typeof mainItem !== "undefined" && mainItem) {
                    mainItem.tableViewComponent = item
                }
                // If data is already loaded, fill comboBox immediately
                if (item && xmlDataModel && xmlDataModel.rowCount > 0) {
                    fillFDVComboBox()
                }
                
                // Connect signals using JavaScript (avoids QML static analysis issues)
                if (item) {
                    // Connect rowDoubleClicked signal
                    item.rowDoubleClicked.connect(function(rowIndex) {
                        // rowIndex is the SOURCE model row index (already mapped from proxy in tableview.qml)
                        // Set the selected row in the table view
                        if (tableViewLoader.item) {
                            tableViewLoader.item.selectedRowIndex = rowIndex
                        }
                        // Open the selected set using the source model row index
                        // This index directly corresponds to the index in m_frameData array
                        openSelectedSet(rowIndex)
                    })
                    
                    // Connect dataLoaded signal
                    item.dataLoaded.connect(function() {
                        fillFDVComboBox()
                    })
                }
            }
        }
    }

    //*************************************

    //-- Calling Main header (info header)of table View  ---------------
    Rectangle {
        id:mainTableViewHeader_id
        anchors.left:parent.left
        anchors.right:parent.right
        anchors.top: parent.top
        anchors.topMargin: 10  // Add space at the top
        anchors.bottom:modelViewHold_id.top

        MainTableViewHeader {
            id: mainHeader_id
            mainHeader_frameUnderThreshold: frameUnderThreshold
            tableViewLoaderRef: tableViewLoader  // Pass tableViewLoader reference for tooltip access
            mainItemRef: mainItem  // Pass mainItem reference for log window access
            // Connect version selection signal to comboBoxFDVSelected function
            onVersionSelected: {
                comboBoxFDVSelected(index)
            }
            
            // Connect search text to proxyModel filter via Tableview's headerSearchText property
            onSearchTextChanged: {
                if (tableViewLoader.item) {
                    tableViewLoader.item.headerSearchText = searchText
                }
            }
        }
    }




    /**
     * @brief Select all rows that are valid for rendering
     * 
     * Iterates through all rows and selects those that are not yet rendered
     * and are valid for rendering. Creates progress bars for selected rows
     * and adds them to the rendering queue.
     */
    function selectAllRows()
    {
        for (var i = 0; i < renderStatusList.length; i++){

            //-- if the row(evant) is already rendered do nothing else create the progressBar ----------
            if (renderStatusList[i] === "false" || renderStatusList[i] === "Not Compare" || renderStatusList[i] === "compare_proc"  || renderStatusList[i] === "render_proc" || renderStatusList[i] === "error_proc")
            {

                var result = checkIfEventValidToRendert(i)
                if (result === true)
                {
                    //-- turn On progressBar --------------------
                    progressBarLoader_id.visible = true

                    //-- turn OFF icons --------------------
                    iconLoader_id.visible = false

                    //-- append to list selected events -----------
                    eventValidToRenderList.push(eventSetList[i])

                    //-- append the loader progressBar to list ------
                    progressBarLoaderList.push(progressBarLoader_id)
                    eventIndexValidToRenderList.push(i)
                    var setGet = "set"
                    xmlread.saveProgressbarsIndex(eventIndexValidToRenderList, selectedFreeDViewName, setGet)
                }
            }
        }
    }



    /**
     * @brief Open event folder in Windows Explorer
     * 
     * Opens the specified event's folder in Windows Explorer. Only works
     * if the event has been rendered (status is not "Not Render").
     * 
     * @param row - Row index in the table
     * @param openIn - Which folder to open (e.g., "source", "test", "diff", "alpha")
     */
    function openInExplorer(row, openIn)
    {
        if (row !== -1) {
            if (renderStatusList[row] !== "Not Render"){
                xmlread.openInExplorer(row, openIn, selectedFreeDViewName)
            }
        }
    }


    /**
     * @brief Launch FreeDView application for the selected event
     * 
     * Opens the event in the FreeDView application if a "testMe.json" file exists.
     * 
     * @param row - Row index in the table
     * @param freedviewName - FreeDView version name to use
     */
    function launchFreeDView(row, freeDViewName)
    {
        if (row !== -1)
        {
            xmlread.launchFreedView(row, selectedFreeDViewName, freeDViewName)
        }
    }

    /**
     * @brief Populate combo box with available folder options
     * 
     * Called when user right-clicks on a cell to edit. Retrieves available
     * folder names from the C++ backend and populates the combo box dropdown.
     * 
     * @param column - Column index being edited
     * @param row - Row index being edited
     * @param val - Current value in the cell
     */
    function fillComboBox(column, row, val)
    {
        if (row !== -1)
        {
            comboBoxList = xmlread.fillComboBox(val, column, row)
        }
    }

    /**
     * @brief Handle combo box selection for editing cell values
     * 
     * Called when user selects an item from the combo box dropdown.
     * Updates the cell value in the XML data model and refreshes the table.
     * 
     * @param val - Selected combo box index (0 = no selection)
     * @param column - Column index being edited
     * @param row - Row index being edited
     * @param newName - New value to set (if creating/renaming)
     */
    function comboBoxSelected(val, column, row, newName)
    {
        if (val !== 0){
            if (newName !== ""){
                xmlread.update_sport_stadium_category(column, row, newName)
                setMinFrameValue(frameUnderThreshold, false)
            }
        }
    }

    /**
     * @brief Create or edit notes in the Notes column
     * 
     * Updates the Notes column for a specific row. After updating, the table
     * view is refreshed and scrolled to show the updated row.
     * 
     * @param column - Column index (should be Notes column)
     * @param row - Row index to update
     * @param text - New notes text
     */
    function creatNewCB(column, row, text)
    {
        xmlread.update_sport_stadium_category(column, row, text)
        //-- to rebuild tabe view ------------
        setMinFrameValue(frameUnderThreshold, false)

        //-- set position of the table view on Row ---------------
        listView_compareResult_id.positionViewAtRow(row, ListView.Center )
    }


    /**
     * @brief Populate the FreeDView version combo box with available versions
     * 
     * Retrieves all unique FreeDView version directory names from the XML data model
     * and populates the combo box in the main header. This allows users to filter
     * the table view by specific FreeDView version comparisons.
     * 
     * The version list is extracted from directory names that contain "_VS_" pattern,
     * which indicates a comparison between two FreeDView versions.
     */
    function fillFDVComboBox()
    {
        //-- get list of all freeDViewVer from xmlDataModel --------------------
        if (!xmlDataModel) {
            return
        }
        
        var freeDViewVer = xmlDataModel.getFreeDViewVerList()
        freeDViewVer_list = []
        
        // Add "All Render Versions" as the first (default) option
        freeDViewVer_list.push("All Render Versions")
        
        if (freeDViewVer) {
            for (var i = 0; i < freeDViewVer.length; i++){
                freeDViewVer_list.push(String(freeDViewVer[i]))
            }
        }

        if (mainHeader_id) {
            mainHeader_id.fillComboBox(freeDViewVer_list)
        }
    }

    /**
     * @brief Handle FreeDView version selection from combo box
     * 
     * When a user selects a FreeDView version from the combo box, this function:
     * 1. Parses the version string to extract orig and test FreeDView names
     * 2. Reloads the XML data model filtered by the selected version
     * 3. Updates the table view to show only events from that version comparison
     * 
     * @param currentSelected - Index of the selected item in the combo box
     */
    function comboBoxFDVSelected(currentSelected)
    {
        eventValidToRenderList = []
        progressBarLoaderList = []
        
        if (!freeDViewVer_list || currentSelected < 0 || currentSelected >= freeDViewVer_list.length) {
            return
        }
        
        selectedFreeDViewName = freeDViewVer_list[currentSelected]
        
        // Handle "All Render Versions" option (index 0) - clear filter to show all tests
        if (currentSelected === 0 || selectedFreeDViewName === "All Render Versions") {
            // Clear filter to show all tests
            if (tableViewLoader.item && tableViewLoader.item.proxyModel) {
                tableViewLoader.item.proxyModel.renderVersionFilter = ""
            }
            selectedFreeDViewVerIndex = 0
            return
        }
        
        // Skip separator items
        if (selectedFreeDViewName === "-------- New FreeDView Ver --------" ||
            selectedFreeDViewName === "-------- FreeDView Exist in the events and in the main folder --------" ||
            selectedFreeDViewName === "-------- FreeDView Exist only in the events --------") {
            return
        }

        if (selectedFreeDViewName !== undefined && selectedFreeDViewName !== "")
        {
            var splitName = selectedFreeDViewName.split("_VS_")
            if (splitName.length >= 2) {
                origFreeDView = splitName[0]
                testFreeDView = splitName[1]
            }
            selectedFreeDViewVerIndex = currentSelected
            
            // Apply render version filter to proxyModel
            // This will filter the table to show only tests that belong to the selected render version
            if (tableViewLoader.item && tableViewLoader.item.proxyModel) {
                tableViewLoader.item.proxyModel.renderVersionFilter = selectedFreeDViewName
            }
        } else {
            // Clear filter to show all tests
            if (tableViewLoader.item && tableViewLoader.item.proxyModel) {
                tableViewLoader.item.proxyModel.renderVersionFilter = ""
            }
        }
    }


    /**
     * @brief Add or edit notes in the Notes column
     * 
     * Updates the Notes column for a specific row and refreshes the table view.
     * 
     * @param column - Column index (should be Notes column)
     * @param row - Row index to update
     * @param val - New notes text
     */
    function addNotesText(column, row, val)
    {
        if (row !== -1) {
            xmlread.inPut_nots(column, row, val)
            setMinFrameValue(frameUnderThreshold, false)

            //-- set position of the table view on Row ---------------
            listView_compareResult_id.positionViewAtRow(row, ListView.Center )
        }
    }

    /**
     * @brief Handle table header click events for sorting and column actions
     * 
     * Implements a "click 4 times" pattern for different column actions:
     * - Status column: Toggle show/hide "No Rendered" events (4 clicks)
     * - Other columns: Sort by that column (4 clicks)
     * - ID column: Toggle thumbnail image visibility (4 clicks)
     * 
     * The 4-click pattern prevents accidental sorting when users are just
     * trying to resize columns or interact with the header.
     * 
     * @param styleData - Style data object containing column information (value = column name)
     */
    function headerClicked(styleData)
    {
        if (styleData.value === "Status"){
            numberOfItem ++
            if (numberOfItem === 4  )
            {
                displayHideNoRendered()
                numberOfItem = 0
            }
        }
        else
        {
            if (styleData.value !== "ID"  ){
                numberOfItem ++
                if (numberOfItem === 4  )
                {
                    xmlread.sortingLists(styleData.value)
                    numberOfItem = 0

                    //-- to rebuild tabe view ------------
                    setMinFrameValue(frameUnderThreshold, false)

                    //-- calling  --------------------
                    xmlread.inPut_numberOfFrameUnder(frameUnderThreshold)
                }
            }

            //-- expose the icon- images --------
            if (styleData.value === "ID"  ){
                numberOfItem ++
                if (numberOfItem === 4  )
                {
                    if (imageVisCol === true)
                    {
                        imageVisCol = false
                    }
                    else
                    {
                        imageVisCol = true
                    }

                    numberOfItem = 0

                }
            }
        }
    }


    /**
     * @brief Filter table view based on search text input
     * 
     * Performs a global search across all columns in the table view.
     * The search is case-insensitive and uses wildcard matching.
     * 
     * Process:
     * 1. Cleans all existing lists
     * 2. Reloads INI file data
     * 3. Applies search filter to XML data model
     * 4. Rebuilds table view with filtered results
     * 5. Updates frame threshold calculations
     * 
     * @param text - Search query string (empty string shows all rows)
     */
    function searchInput(text)
    {
        if (!xmlread) {
            return
        }

        xmlread.cleanAllLists()

        xmlread.readINIFile(selectedFreeDViewVerIndex)

        //-- calling "searchInput"  ---------------------------------
        xmlread.searchInput(text)

        //-- to rebuild tabe view ------------
        setMinFrameValue(frameUnderThreshold, false)

        //-- calling  inPut_numberOfFrameUnder --------------------
                    xmlread.inPut_numberOfFrameUnder(frameUnderThreshold)
    }


    /**
     * @brief Toggle visibility of "Not Rendered" events in the table
     * 
     * Cycles through three states:
     * - 0: Show all events (default)
     * - 1: Hide "Not Rendered" events
     * - 2: Show only "Not Rendered" events
     * 
     * Each state change reloads the data model and rebuilds the table view.
     */
    function displayHideNoRendered()
    {
        if (!xmlread) {
            return
        }

        if (displayHideNoRendered === 0)
        {
            displayHideNoRendered = 1
            xmlread.inPut_display_Hide_noRendered(displayHideNoRendered)
            xmlread.cleanAllLists()
            xmlread.readINIFile(selectedFreeDViewVerIndex)
                    xmlread.inPut_numberOfFrameUnder(frameUnderThreshold)
            setMinFrameValue(frameUnderThreshold, false)
            return
        }

        if (displayHideNoRendered === 1)
        {
            displayHideNoRendered = 2
            xmlread.inPut_display_Hide_noRendered(displayHideNoRendered)
            xmlread.cleanAllLists()
            xmlread.readINIFile(selectedFreeDViewVerIndex)
                    xmlread.inPut_numberOfFrameUnder(frameUnderThreshold)
            setMinFrameValue(frameUnderThreshold, false)
            return
        }

        else
        {
            displayHideNoRendered = 0
            xmlread.inPut_display_Hide_noRendered(displayHideNoRendered)
            xmlread.cleanAllLists()
            xmlread.readINIFile(selectedFreeDViewVerIndex)
                    xmlread.inPut_numberOfFrameUnder(frameUnderThreshold)
            setMinFrameValue(frameUnderThreshold, false)
            return
        }

    }


    /**
     * @brief Set the minimum frame value threshold and update all dependent components
     * 
     * This function updates the minimum frame value used for filtering and highlighting
     * frames in the chart view. It propagates the value to:
     * - The main application component (mainItem)
     * - The swipe view component (swipeViewComponent_id) for chart updates
     * 
     * @param value - The new minimum frame value (as string or number)
     * @param minValueChang - Boolean flag indicating if the value actually changed (currently unused)
     */
    function setMinFrameValue(value, minValueChang){
        var val = parseFloat(value)
        frameUnderThreshold = value
        
        // Update min frame value in other components
        if (typeof mainItem !== "undefined" && mainItem) {
            mainItem.getMinFrameValueFromTopLayoutZero(frameUnderThreshold)
        }
        if (typeof swipeViewComponent_id !== "undefined" && swipeViewComponent_id) {
            swipeViewComponent_id.setMinFrameValue(frameUnderThreshold)
        }
    }


    /**
     * @brief Open a selected event set and load its image sequences
     * 
     * This is the main function called when a user double-clicks a row in the table.
     * It retrieves all data for the selected event set and initializes the image
     * comparison views.
     * 
     * Process:
     * 1. Validates the selected row has rendered data (status != "false")
     * 2. Retrieves frame data (start/end frames, min/max values, frame lists)
     * 3. Gets output paths for all image types (orig, test, diff, alpha)
     * 4. Extracts FreeDView version names
     * 5. Calls mainItem.openProjectUpdate() to initialize image views
     * 6. Updates info header with event metadata
     * 7. Navigates to page 1 (3-window comparison view)
     * 
     * @param value - Row index in the XML data model (0-based)
     */
    /**
     * @brief Open a selected event set and load its image sequences
     * 
     * This is the main function called when a user double-clicks a row in the table.
     * It retrieves all data for the selected event set and initializes the image
     * comparison views.
     * 
     * IMPORTANT: The 'value' parameter must be the SOURCE model row index (not proxy row index).
     * This is correctly provided by the rowDoubleClicked signal which maps proxy->source.
     * 
     * Process:
     * 1. Validates the selected row has rendered data (status != "false")
     * 2. Retrieves frame data (start/end frames, min/max values, frame lists)
     * 3. Gets output paths for all image types (orig, test, diff, alpha)
     * 4. Extracts FreeDView version names
     * 5. Calls mainItem.openProjectUpdate() to initialize image views
     * 6. Updates info header with event metadata
     * 7. Navigates to page 1 (3-window comparison view)
     * 
     * @param value - Source model row index (0-based, correctly mapped from proxy model)
     */
    function openSelectedSet(value){
        outputPathList = []
        
        // Check if xmlDataModel is available
        if (!xmlDataModel) {
            // Show error in status bar
            if (tableViewLoader.item && typeof tableViewLoader.item.setStatusMessage === "function") {
                tableViewLoader.item.setStatusMessage("Error: Data model not available", 5000)
            }
            return
        }
        
        // Validate row index is within bounds
        if (value < 0 || value >= xmlDataModel.rowCount) {
            // Show error in status bar
            if (tableViewLoader.item && typeof tableViewLoader.item.setStatusMessage === "function") {
                tableViewLoader.item.setStatusMessage("Error: Invalid row index", 5000)
            }
            return
        }
        
        // Get ALL data from the row to verify we have the right one
        var rowId = xmlDataModel.data(xmlDataModel.index(value, 0), Qt.DisplayRole)
        var eventNameItemForValidation = xmlDataModel.data(xmlDataModel.index(value, 1), Qt.DisplayRole)
        var eventName = eventNameItemForValidation ? eventNameItemForValidation.toString() : "unknown"
        
        // Get render status from model FIRST (column 8 = Status) - before trying to load data
        var statusItem = xmlDataModel.data(xmlDataModel.index(value, 8), Qt.DisplayRole)
        renderStatus = statusItem ? statusItem.toString().trim() : "false"
        
        // Check if status is "Ready" - if not, show error dialog and return early
        if (renderStatus !== "Ready") {
            var errorMessage = "Cannot load test data\n\n" +
                              "Status: " + renderStatus + "\n\n" +
                              "This test has not been completed or the results folder is missing.\n" +
                              "Please run the comparison test first."
            // Show error dialog
            if (typeof mainItem !== "undefined" && mainItem && mainItem.showError) {
                mainItem.showError(errorMessage)
            }
            // Also show in status bar for visibility
            if (tableViewLoader.item && typeof tableViewLoader.item.setStatusMessage === "function") {
                tableViewLoader.item.setStatusMessage("No data available for this test. Status: " + renderStatus, 5000)
            }
            return
        }

        // Status is "Ready" - proceed with loading data
        //-- get data from xmlDataModel for the selected row ------
        // Note: All these methods use the source model row index directly
        // which matches the index in m_frameData array
        // IMPORTANT: 'value' is the source model row index, correctly mapped from proxy model
        startFrame = xmlDataModel.getStartFrame(value)
        endFrame = xmlDataModel.getEndFrame(value)
        minVal = xmlDataModel.getMinVal(value)
        maxVal = xmlDataModel.getMaxVal(value)
        frameList_frame = xmlDataModel.getFrameList_frame(value)
        frameList_val = xmlDataModel.getFrameList_val(value)
        
        // Validate that we got valid frame data
        if (startFrame < 0 || endFrame < 0 || !frameList_frame || frameList_frame.length === 0) {
            var frameDataErrorMessage = "Cannot load test data\n\n" +
                              "No frame data available for this test.\n\n" +
                              "The compareResult.xml file may be missing or invalid.\n" +
                              "Please check that the results folder exists and contains valid data."
            // Show error dialog
            if (typeof mainItem !== "undefined" && mainItem && mainItem.showError) {
                mainItem.showError(frameDataErrorMessage)
            }
            // Also show in status bar for visibility
            if (tableViewLoader.item && typeof tableViewLoader.item.setStatusMessage === "function") {
                tableViewLoader.item.setStatusMessage("Error: No frame data available for this test", 5000)
            }
            return
        }
        
        // Get number of frames from model (column 5 = Number Of Frames)
        var numberOfFramesItem = xmlDataModel.data(xmlDataModel.index(value, 5), Qt.DisplayRole)
        var numberOfFrames = numberOfFramesItem ? parseInt(numberOfFramesItem.toString()) : 0

        //-- get output paths from xmlDataModel ------
        outputPathList = xmlDataModel.getOutputPathList(value)
        
        // Validate that we have at least some paths
        if (!outputPathList || outputPathList.length === 0 || (!outputPathList[0] && !outputPathList[1])) {
            var pathErrorMessage = "Cannot load test data\n\n" +
                              "No image paths available for this test.\n\n" +
                              "The results folder structure may be incorrect or the images may be missing.\n" +
                              "Expected paths:\n" +
                              "- Original images (A)\n" +
                              "- Test images (B)\n" +
                              "- Difference images (C)\n" +
                              "- Alpha masks (D)"
            // Show error dialog
            if (typeof mainItem !== "undefined" && mainItem && mainItem.showError) {
                mainItem.showError(pathErrorMessage)
            }
            return
        }
        
        // Additional validation: Verify the event name matches what we expect
        // This helps catch cases where row index mapping might be incorrect
        var eventNameFromModel = xmlDataModel.data(xmlDataModel.index(value, 1), Qt.DisplayRole)
        if (!eventNameFromModel || eventNameFromModel.toString() === "") {
            return
        }
        
        // Get orig and test FreeDView names directly from model (read from XML)
        origFreeDViewName = xmlDataModel.getOrigFreeDViewName(value)
        testFreeDViewName = xmlDataModel.getTestFreeDViewName(value)

        mainItem.openProjectUpdate(startFrame, endFrame, minVal, maxVal, outputPathList, frameList_frame, frameList_val, frameUnderThreshold, origFreeDViewName, testFreeDViewName)

        //-- gather info for the infoHeader -------------------
        //-- index id -- Use the actual ID from column 0, not the row index
        id_val = rowId
        //-- eventName (column 1) --
        var eventNameItemForHeader = xmlDataModel.data(xmlDataModel.index(value, 1), Qt.DisplayRole)
        eventName = eventNameItemForHeader ? eventNameItemForHeader.toString() : ""
        //-- sportType (column 2) --
        var sportTypeItem = xmlDataModel.data(xmlDataModel.index(value, 2), Qt.DisplayRole)
        sportType = sportTypeItem ? sportTypeItem.toString() : ""
        //-- stadiumName (column 3) --
        var stadiumNameItem = xmlDataModel.data(xmlDataModel.index(value, 3), Qt.DisplayRole)
        stadiumName = stadiumNameItem ? stadiumNameItem.toString() : ""
        //-- categoryName (column 4) --
        var categoryNameItem = xmlDataModel.data(xmlDataModel.index(value, 4), Qt.DisplayRole)
        categoryName = categoryNameItem ? categoryNameItem.toString() : ""

        // Access swipeViewComponent_id through parent hierarchy
        // Structure: TopLayout_zero -> Item -> SwipeView -> Rectangle (swipeViewComponent_id)
        var swipeView = parent ? (parent.parent ? parent.parent.parent : null) : null
        if (swipeView && typeof swipeView.infoHeader === "function") {
            swipeView.infoHeader(id_val, eventName, sportType, stadiumName, numberOfFrames,  minVal, frameUnderThreshold)
        } else if (typeof swipeViewComponent_id !== "undefined" && swipeViewComponent_id) {
            // Fallback: try direct reference if available
            swipeViewComponent_id.infoHeader(id_val, eventName, sportType, stadiumName, numberOfFrames,  minVal, frameUnderThreshold)
        }

        // Navigate to page 1 (the page with 3 windows showing images)
        // Use a timer to delay navigation (like the original code) to ensure images start loading first
        pageNavigationTimer.running = true
    }
    
    // Timer to navigate to page 1 after double-click (delayed to ensure images start loading)
    Timer {
        id: pageNavigationTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            // Navigate to page 1 using mainItem's changePageIndex function
            if (typeof mainItem !== "undefined" && mainItem && typeof mainItem.changePageIndex === "function") {
                mainItem.changePageIndex(1)
            } else {
                // Fallback: try to access parent SwipeView directly
                var swipeView = parent ? (parent.parent ? parent.parent.parent : null) : null
                if (swipeView && typeof swipeView.changePageIndex === "function") {
                    swipeView.changePageIndex(1)
                }
            }
        }
    }
}



