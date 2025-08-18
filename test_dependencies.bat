@echo off
echo Testing Flutter Dependencies...
echo.

echo 1. Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found or not in PATH
    pause
    exit /b 1
)

echo.
echo 2. Checking Flutter doctor...
flutter doctor
if %errorlevel% neq 0 (
    echo ERROR: Flutter doctor failed
    pause
    exit /b 1
)

echo.
echo 3. Testing pub get with verbose output...
flutter pub get --verbose
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    echo.
    echo Common solutions:
    echo - Check internet connection
    echo - Clear Flutter cache: flutter clean
    echo - Update Flutter: flutter upgrade
    echo - Check pubspec.yaml syntax
    pause
    exit /b 1
)

echo.
echo 4. Checking dependency tree...
flutter pub deps
if %errorlevel% neq 0 (
    echo WARNING: Could not show dependency tree
)

echo.
echo 5. Testing basic Flutter build...
flutter analyze
if %errorlevel% neq 0 (
    echo WARNING: Code analysis found issues
    echo This is normal for new projects
)

echo.
echo Dependencies test completed!
echo If you see any errors above, please fix them before building.
pause
