/****************************************************************************
**
** @file main.cpp
** @brief Main application entry point for Render Compare
**
** This file initializes the Qt application, registers QML types, sets up
** the QML engine, and creates the main application window.
**
** Key responsibilities:
** - Initialize QApplication (required for Qt Charts)
** - Register C++ types for QML access
** - Register QML singleton types (Theme, Constants, Logger)
** - Create and configure backend services (IniReader, XmlDataModel, etc.)
** - Expose services to QML via context properties
** - Load and display Main.qml as the root component
**
****************************************************************************/

#include <QtWidgets/QApplication>
#include <QtQml/QQmlContext>
#include <QtQuick/QQuickView>
#include <QtQml/QQmlEngine>
#include <QtCore/QDir>
#include <QtQml/qqml.h>

#include "inireader.h"
#include "sortfilterproxymodel.h"
#include "xmldatamodel.h"
#include "freeDView_tester_runner.h"
#include "imageloadermanager.h"


int main(int argc, char *argv[])
{
    // Qt Charts uses Qt Graphics View Framework for drawing, therefore QApplication must be used.
    QApplication app(argc, argv);

    QQuickView viewer;

    // Add import path for QML modules (allows running without installing modules)
    // This is useful for development and deployment scenarios
#ifdef Q_OS_WIN
    QString extraImportPath(QStringLiteral("%1/../../../../%2"));
#else
    QString extraImportPath(QStringLiteral("%1/../../../%2"));
#endif
    viewer.engine()->addImportPath(extraImportPath.arg(QGuiApplication::applicationDirPath(), QString::fromLatin1("qml")));
    QObject::connect(viewer.engine(), &QQmlEngine::quit, &viewer, &QWindow::close);

    // Set application version for window title and QML access
    QString appVersion = QString::fromLatin1(APP_VERSION);
    viewer.setTitle(QStringLiteral("Render Compare v%1").arg(appVersion));

    // Register QML types - using unique module name to avoid conflicts with other projects
    qmlRegisterType<SortFilterProxyModel>("com.rendercompare", 1, 0, "SortFilterProxyModel");
    qmlRegisterType<IniReader>("com.rendercompare", 1, 0, "IniReader");
    qmlRegisterType<XmlDataModel>("com.rendercompare", 1, 0, "XmlDataModel");
    qmlRegisterType<TesterRunner>("com.rendercompare", 1, 0, "TesterRunner");
    
    // Register QML singletons for theme, constants, and logger
    qmlRegisterSingletonType(QUrl("qrc:/qml/Theme.qml"), "Theme", 1, 0, "Theme");
    qmlRegisterSingletonType(QUrl("qrc:/qml/Constants.qml"), "Constants", 1, 0, "Constants");
    qmlRegisterSingletonType(QUrl("qrc:/qml/Logger.qml"), "Logger", 1, 0, "Logger");

    // Create long-lived instances so QML keeps valid pointers
    IniReader iniReader;
    XmlDataModel xmlDataModel;
    TesterRunner testerRunner;
    ImageLoaderManager imageLoaderManager;
    
    // Limit global thread pool to prevent too many simultaneous image loads
    // This works with QtConcurrent::run to throttle concurrent operations
    // Thread count matches Constants.maxThreadCount (4) for consistency
    const int maxThreadCount = 4;  // Prevents memory issues with concurrent image loading
    QThreadPool::globalInstance()->setMaxThreadCount(maxThreadCount);

    // Read INI file and load data
    // Initially load all data (empty string = no filter), user can filter by version via comboBox
    if (iniReader.readINIFile()) {
        xmlDataModel.loadData(iniReader.setTestResultsPath(), QString(), iniReader.setTestPath());
    }

    // Expose to QML (even if INI load failed, to keep bindings valid)
    viewer.rootContext()->setContextProperty("iniReader", &iniReader);
    viewer.rootContext()->setContextProperty("xmlDataModel", &xmlDataModel);
    viewer.rootContext()->setContextProperty("testerRunner", &testerRunner);
    viewer.rootContext()->setContextProperty("imageLoaderManager", &imageLoaderManager);
    viewer.rootContext()->setContextProperty("appVersion", appVersion);
    
    // Load main QML component and configure window
    viewer.setSource(QUrl("qrc:/qml/Main.qml"));
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);
    
    // Set window background color (matches Theme.backgroundLight: #404040)
    // This color is shown briefly before QML content loads
    const QColor windowBackgroundColor(0x40, 0x40, 0x40);
    viewer.setColor(windowBackgroundColor);
    
    viewer.show();

    return app.exec();
}

