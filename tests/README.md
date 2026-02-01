-NoNewline

# Render Compare - Test Suite

This directory contains the automated test suite for Render Compare.

## Overview

The test suite uses **Qt Test Framework** to verify that the application's core functionality works correctly. Tests are organized by type and component.

## Directory Structure

```
tests/
├── unit/                    # Unit tests for individual components
│   ├── test_imageloadermanager.cpp
│   ├── test_inireader.cpp
│   └── test_xmldatamodel.cpp
├── tests.pro                # Test project configuration
└── README.md               # This file
```

## Building Tests

### Prerequisites
- Qt 5.12+ or Qt 6.x installed
- qmake available in PATH
- C++ compiler (MSVC, MinGW, GCC, or Clang)

### Build Steps

1. **Navigate to tests directory**:
   ```bash
   cd tests
   ```

2. **Generate Makefile**:
   ```bash
   qmake tests.pro
   ```

3. **Build tests**:
   ```bash
   make          # Linux/Mac
   nmake         # Windows (MSVC)
   mingw32-make  # Windows (MinGW)
   ```

4. **Run tests**:
   ```bash
   ./tests       # Linux/Mac
   tests.exe     # Windows
   ```

## Running Tests

### Run All Tests
```bash
./tests
```

### Run Specific Test Class
```bash
./tests TestImageLoaderManager
```

### Verbose Output
```bash
./tests -v2
```

### Output to File
```bash
./tests -o test_results.txt
```

## Test Coverage

### Current Tests

#### ImageLoaderManager Tests
- ✅ Image path construction
- ✅ Cache functionality
- ✅ Cache eviction (LRU)
- ✅ Frame number formatting
- ✅ Path validation
- ✅ Preloading functionality

#### IniReader Tests
- ✅ INI file discovery
- ✅ INI file parsing
- ✅ Path resolution (absolute/relative)
- ✅ Error handling
- ✅ XML file discovery

#### XmlDataModel Tests
- ✅ Model initialization
- ✅ Row/column management
- ✅ Column width ratios
- ✅ Cell updates
- ✅ Data access methods
- ✅ Test key extraction

### Planned Tests

- [ ] Integration tests (component interaction)
- [ ] QML component tests (UI components)
- [ ] Performance tests
- [ ] Error handling tests

## Writing New Tests

### Test Class Structure

```cpp
#include <QtTest/QtTest>
#include "../src/yourclass.h"

class TestYourClass : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();    // Called once before all tests
    void cleanupTestCase(); // Called once after all tests
    void init();            // Called before each test
    void cleanup();         // Called after each test

    void testYourFunction();
};

void TestYourClass::initTestCase()
{
    // Setup that applies to all tests
}

void TestYourClass::testYourFunction()
{
    // Your test code
    QVERIFY(condition);     // Verify condition is true
    QCOMPARE(actual, expected);  // Compare values
}

QTEST_MAIN(TestYourClass)
#include "test_yourclass.moc"
```

### Test Macros

- `QVERIFY(condition)` - Fails if condition is false
- `QCOMPARE(actual, expected)` - Compares two values
- `QVERIFY2(condition, message)` - Fails with message
- `QSKIP(message)` - Skip this test
- `QFAIL(message)` - Force test to fail

### Best Practices

1. **Isolate Tests**: Each test should be independent
2. **Use Temporary Files**: Use `QTemporaryDir` for file operations
3. **Clean Up**: Always clean up resources in `cleanup()`
4. **Test Edge Cases**: Test invalid inputs, boundary conditions
5. **Test Both Success and Failure**: Test both happy path and error cases

## Continuous Integration

### GitHub Actions (Example)

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Qt
        # ... install Qt ...
      - name: Build Tests
        run: |
          cd tests
          qmake tests.pro
          make
      - name: Run Tests
        run: ./tests
```

## Test Results

### Successful Test Run
```
********* Start testing of TestImageLoaderManager *********
Config: Using QtTest library 5.15.2
PASS   : TestImageLoaderManager::initTestCase()
PASS   : TestImageLoaderManager::testGetImageFilePath()
PASS   : TestImageLoaderManager::testCacheFunctionality()
PASS   : TestImageLoaderManager::cleanupTestCase()
Totals: 4 passed, 0 failed, 0 skipped
********* Finished testing of TestImageLoaderManager *********
```

### Failed Test
```
FAIL!  : TestImageLoaderManager::testGetImageFilePath()
   Actual   : ""
   Expected : (contains "0001")
   Loc: [test_imageloadermanager.cpp(45)]
```

## Troubleshooting

### Tests Won't Build
- Verify Qt is installed and qmake is in PATH
- Check that all source files are included in `tests.pro`
- Ensure include paths are correct

### Tests Fail
- Check test output for specific error messages
- Verify test data files exist
- Check that temporary directories are created correctly

### Missing Dependencies
- Ensure all required Qt modules are in `tests.pro` (QT += ...)
- Check that source files from main project are included

## Contributing

When adding new features:
1. Write tests first (TDD - Test-Driven Development)
2. Implement the feature
3. Ensure all tests pass
4. Add tests for edge cases

## Resources

- [Qt Test Framework Documentation](https://doc.qt.io/qt-5/qttest-index.html)
- [Qt Test Tutorial](https://doc.qt.io/qt-5/qttest-tutorial.html)
- [Best Practices for Qt Test](https://doc.qt.io/qt-5/qttest-best-practices.html)
