###############################################################################
# Render Compare - Test Project
# Qt Test Framework Configuration
###############################################################################

TEMPLATE = app
TARGET = tests
CONFIG += console
CONFIG -= app_bundle
CONFIG += c++11

# Qt modules required for tests
QT += core
QT += xml
QT += testlib
QT += concurrent
QT += gui  # Required for QImage, QPixmap in ImageLoaderManager tests
# Note: QML/Quick modules removed - tests don't need SortFilterProxyModel

# Application version (same as main project)
VERSION = 1.0.0

# Add src directory to include path
INCLUDEPATH += ../src
INCLUDEPATH += .

# Source files from main project (needed for testing)
# Note: SortFilterProxyModel removed - tests don't use it and it requires QML interfaces
SOURCES += ../src/inireader.cpp \
           ../src/imageloadermanager.cpp \
           ../src/xmldatamodel.cpp \
           ../src/xmldataloader.cpp

HEADERS += ../src/inireader.h \
           ../src/imageloadermanager.h \
           ../src/xmldatamodel.h \
           ../src/xmldataloader.h

# Test source files
# Note: Individual test files no longer have QTEST_MAIN - using shared main()
SOURCES += tests_main.cpp \
           unit/test_imageloadermanager.cpp \
           unit/test_inireader.cpp \
           unit/test_xmldatamodel.cpp

# Output directory
DESTDIR = $$PWD/../bin
OBJECTS_DIR = $$PWD/../build/tests
MOC_DIR = $$PWD/../build/tests
RCC_DIR = $$PWD/../build/tests
UI_DIR = $$PWD/../build/tests

# Ensure MOC files are generated properly
CONFIG += moc
CONFIG += warn_on

# Note: QML interfaces not needed - SortFilterProxyModel removed from tests

# Create build directory if it doesn't exist
!exists($$OBJECTS_DIR) {
    system(mkdir -p $$OBJECTS_DIR)
}
!exists($$MOC_DIR) {
    system(mkdir -p $$MOC_DIR)
}

# Disable warnings for test files (Qt Test generates some warnings)
QMAKE_CXXFLAGS += -Wno-unused-parameter

###############################################################################
# Test Configuration
###############################################################################

# Enable test coverage (optional - requires gcov/lcov)
# CONFIG += coverage

# Output test results to file
# QMAKE_POST_LINK += $$quote($$QMAKE_COPY $$shell_path($$[QT_INSTALL_BINS]/qttest) $$shell_path($$DESTDIR)/qttest)
