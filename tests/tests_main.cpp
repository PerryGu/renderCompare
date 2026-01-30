/****************************************************************************
**
** @file tests_main.cpp
** @brief Main entry point for all unit tests
**
** This file provides a single main() function that runs all test classes.
** Each test class is executed in sequence.
**
** Note: Test class implementations are included here to avoid multiple
** definition of main() from QTEST_MAIN macros.
**
****************************************************************************/

#include <QtTest/QtTest>
#include <QGuiApplication>  // Required for QPixmap operations

// Include test class implementations
// These files define the test classes but no longer have QTEST_MAIN
#include "unit/test_imageloadermanager.cpp"
#include "unit/test_inireader.cpp"
#include "unit/test_xmldatamodel.cpp"

// Main function that runs all tests
int main(int argc, char *argv[])
{
    // QGuiApplication required for QPixmap operations (used by ImageLoaderManager)
    QGuiApplication app(argc, argv);
    
    int status = 0;
    
    // Run each test class
    {
        TestImageLoaderManager test;
        status |= QTest::qExec(&test, argc, argv);
    }
    
    {
        TestIniReader test;
        status |= QTest::qExec(&test, argc, argv);
    }
    
    {
        TestXmlDataModel test;
        status |= QTest::qExec(&test, argc, argv);
    }
    
    return (status != 0) ? 1 : 0;
}
