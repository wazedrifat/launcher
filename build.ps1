# PowerShell script to build Launcher App for Windows
param(
    [switch]$Clean,
    [switch]$Debug
)

Write-Host "Building Launcher App for Windows..." -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version
    Write-Host "Flutter version found:" -ForegroundColor Yellow
    Write-Host $flutterVersion -ForegroundColor Gray
} catch {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Clean build if requested
if ($Clean) {
    Write-Host ""
    Write-Host "Cleaning previous build..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
}

Write-Host ""
Write-Host "Building Windows app..." -ForegroundColor Yellow

# Build based on configuration
if ($Debug) {
    flutter build windows --debug
} else {
    flutter build windows --release
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green

if ($Debug) {
    Write-Host "Debug executable location: build\windows\runner\Debug\launcher.exe" -ForegroundColor Cyan
} else {
    Write-Host "Release executable location: build\windows\runner\Release\launcher.exe" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "You can now run the launcher app from the build directory." -ForegroundColor Yellow
Write-Host ""

# Check if executable exists
$buildPath = if ($Debug) { "build\windows\runner\Debug\launcher.exe" } else { "build\windows\runner\Release\launcher.exe" }
if (Test-Path $buildPath) {
    $fileSize = (Get-Item $buildPath).Length / 1MB
    Write-Host "Executable size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
}

Read-Host "Press Enter to exit"
