###############################################################################
# Render Compare - Qt/QML Application
# Project Configuration File
###############################################################################

# Removed examples.pri dependency - it was used when this was part of Qt examples
# Now using standalone project configuration

# Application version (semantic versioning: MAJOR.MINOR.PATCH)
VERSION = 1.0.0

# Make version available in C++ code
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

QT += core
QT += xml
QT += gui
QT += widgets
QT += qml
QT += quick
QT += quickcontrols2
QT += charts
QT += concurrent

###############################################################################
# Source Files - All C++ source files are located in src/ directory
###############################################################################
SOURCES += src/main.cpp \
           src/inireader.cpp \
           src/sortfilterproxymodel.cpp \
           src/xmldatamodel.cpp \
           src/xmldataloader.cpp \
           src/freeDView_tester_runner.cpp \
           src/imageloadermanager.cpp

HEADERS += \
    src/inireader.h \
    src/sortfilterproxymodel.h \
    src/xmldatamodel.h \
    src/xmldataloader.h \
    src/freeDView_tester_runner.h \
    src/imageloadermanager.h

# Add src directory to include path so headers can be found
INCLUDEPATH += src

###############################################################################
# Resource Files
###############################################################################
RESOURCES += \
    resources.qrc

# Note: The INI file (renderCompare.ini) should be kept in the project root directory.
# The C++ code has a fallback mechanism that will find it automatically in multiple locations:
# 1. Same directory as executable (for deployment)
# 2. One directory up from executable (build directory)
# 3. Project root (for development)
# This way there's only one source of truth (project root), and no build-time copying is needed.

OTHER_FILES += \
    qml/CircularProgressbar.qml \
    qml/ImageFileAB.qml \
    qml/ImageFileC.qml \
    qml/ImageFileD.qml \
    qml/ImageItem.qml \
    qml/InfoHeader.qml \
    qml/Main.qml \
    qml/MainTableViewHeader.qml \
    qml/MultiButton.qml \
    qml/ReloadedAllImages.qml \
    qml/TheSwipeView.qml \
    qml/TopLayout_one.qml \
    qml/TopLayout_three.qml \
    qml/TopLayout_zero.qml \
    qml/TimelineChart.qml \
    qml/TableviewDialogs.qml \
    qml/TableviewHandlers.qml \
    qml/TableviewTable.qml \
    qml/Theme.qml \
    qml/Constants.qml \
    qml/Logger.qml \
    qml/LogWindow.qml \
    qml/MenuBar.qml \
    qml/TooltipManager.qml \
    qml/ErrorDialog.qml \
    qml/DoubleBufferedImage.qml \
    qml/PlaybackSpeedMenu.qml

# DISTFILES section removed - files are now properly organized in their respective directories
# and tracked through RESOURCES, SOURCES, HEADERS, and OTHER_FILES sections above

