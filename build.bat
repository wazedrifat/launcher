@echo off
echo Building Launcher App for Windows...
echo.

echo Checking Flutter installation...
flutter --version
if %errorlevel% neq 0 (
    echo Error: Flutter is not installed or not in PATH
    pause
    exit /b 1
)

echo.
echo Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo Error: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo Building Windows app...
flutter build windows --release
if %errorlevel% neq 0 (
    echo Error: Build failed
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo Executable location: build\windows\runner\Release\launcher.exe
echo.
echo You can now run the launcher app from the build directory.
pause
