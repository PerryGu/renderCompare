/**
 * @file TooltipManager.qml
 * @brief Centralized tooltip management component
 * 
 * Eliminates code duplication by providing a single point for tooltip routing
 * to the appropriate component based on the current page.
 */

import QtQuick 2.0
import Constants 1.0

Item {
    id: tooltipManager
    
    // Component references
    property var tableViewComponent: null
    property var swipeViewComponent: null
    
    /**
     * @brief Get the current page index from SwipeView
     * @return Current page index (0=table, 1=3-window, 2=single-window), or -1 if unavailable
     */
    function getCurrentPage() {
        if (swipeViewComponent && swipeViewComponent.swipeView_id) {
            return swipeViewComponent.swipeView_id.currentIndex
        }
        return -1
    }
    
    /**
     * @brief Set tooltip text on the appropriate component for the current page
     * @param text - Tooltip text to display
     */
    function setTooltip(text) {
        if (!text) return
        
        var currentPage = getCurrentPage()
        
        if (currentPage === Constants.pageTable) {
            // Page 0: Table view - use Tableview status bar
            if (tableViewComponent && tableViewComponent.setTooltip) {
                tableViewComponent.setTooltip(text)
            }
        } else if (currentPage === Constants.pageThreeWindow || currentPage === Constants.pageSingleWindow) {
            // Pages 1 or 2: Image views - update InfoHeaders
            if (swipeViewComponent && swipeViewComponent.setInfoHeaderTooltip) {
                swipeViewComponent.setInfoHeaderTooltip(text)
            }
        } else {
            // Fallback: try both components
            if (swipeViewComponent && swipeViewComponent.setInfoHeaderTooltip) {
                swipeViewComponent.setInfoHeaderTooltip(text)
            }
            if (tableViewComponent && tableViewComponent.setTooltip) {
                tableViewComponent.setTooltip(text)
            }
        }
    }
    
    /**
     * @brief Clear tooltip text on the appropriate component for the current page
     */
    function clearTooltip() {
        var currentPage = getCurrentPage()
        
        if (currentPage === Constants.pageTable) {
            // Page 0: Table view - clear Tableview status bar
            if (tableViewComponent && tableViewComponent.clearTooltip) {
                tableViewComponent.clearTooltip()
            }
        } else if (currentPage === Constants.pageThreeWindow || currentPage === Constants.pageSingleWindow) {
            // Pages 1 or 2: Image views - clear InfoHeaders
            if (swipeViewComponent && swipeViewComponent.clearInfoHeaderTooltip) {
                swipeViewComponent.clearInfoHeaderTooltip()
            }
        } else {
            // Fallback: try Tableview (most common)
            if (tableViewComponent && tableViewComponent.clearTooltip) {
                tableViewComponent.clearTooltip()
            }
        }
    }
}
