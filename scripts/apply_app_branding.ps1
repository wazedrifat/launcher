Param()
$ErrorActionPreference = 'Stop'

function Write-Info($msg){ Write-Host "[BRAND] $msg" -ForegroundColor Cyan }
function Write-Err($msg){ Write-Host "[BRAND][ERROR] $msg" -ForegroundColor Red }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$configPath = Join-Path $root 'assets/config/app_settings.json'
$destDir = Join-Path $root 'windows/runner/resources'
$destIcon = Join-Path $destDir 'app_icon.ico'

if(-not (Test-Path $configPath)){ Write-Err "Config not found: $configPath"; exit 1 }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$appIcon = $config.app_icon
if([string]::IsNullOrWhiteSpace($appIcon)){
  Write-Info 'No app_icon set in app_settings.json; keeping existing icon.'
  exit 0
}

# Resolve relative paths from repo root
$iconPath = Join-Path $root $appIcon
if(-not (Test-Path $iconPath)){
  Write-Err "Icon file not found: $iconPath"
  exit 1
}

if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Path $destDir | Out-Null }
Copy-Item -Path $iconPath -Destination $destIcon -Force
Write-Info "Icon applied: $destIcon"
Write-Info 'Rebuild with: flutter clean; flutter build windows'
