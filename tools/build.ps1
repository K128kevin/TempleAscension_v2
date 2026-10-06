<#
.SYNOPSIS
  Pulls the latest main and builds Temple Ascension on Windows (tools/build.sh's
  counterpart): builds\TempleAscension-Windows.zip and, unless -SkipMac,
  builds\TempleAscension-macOS.zip.

.DESCRIPTION
  Godot 4.7.2 and its export templates are kept in .tools (not in git). If they
  are missing they are downloaded there once from the Godot releases on GitHub
  (the templates are about 1 GB). Pass -Godot or set GODOT_BIN to use a Godot
  console executable you already have.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\build.ps1
  powershell -ExecutionPolicy Bypass -File tools\build.ps1 -SkipPull -SkipMac
#>
param(
  [string]$Godot = $env:GODOT_BIN,
  [switch]$SkipPull,
  [switch]$SkipMac
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # (Invoke-WebRequest is far slower with its progress bar.)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$Version = "4.7.2"
$Release = "https://github.com/godotengine/godot/releases/download/$Version-stable"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host $text -ForegroundColor Red; exit 1 }

# --- Latest main ---------------------------------------------------------------
if (-not $SkipPull) {
  Step "Pulling the latest main"
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git is not on PATH." }
  if (git status --porcelain --untracked-files=no) { Fail "There are uncommitted changes; commit or discard them first (or pass -SkipPull)." }
  git fetch origin main
  if ($LASTEXITCODE -ne 0) { Fail "git fetch failed." }
  git checkout main
  if ($LASTEXITCODE -ne 0) { Fail "Could not switch to main." }
  git pull --ff-only origin main
  if ($LASTEXITCODE -ne 0) { Fail "git pull failed (has local main diverged from origin?)." }
}

# --- Godot and its export templates ---------------------------------------------
$Tools = Join-Path $Root ".tools"
New-Item -ItemType Directory -Force $Tools | Out-Null
if (-not $Godot) {
  $Godot = Join-Path $Tools "godot\Godot_v$Version-stable_win64_console.exe"
  if (-not (Test-Path $Godot)) {
    Step "Downloading Godot $Version"
    $zip = Join-Path $Tools "godot.zip"
    Invoke-WebRequest "$Release/Godot_v$Version-stable_win64.exe.zip" -OutFile $zip
    Expand-Archive $zip (Join-Path $Tools "godot") -Force
    Remove-Item $zip
  }
}
if (-not (Test-Path $Godot)) { Fail "Godot not found at $Godot. Pass -Godot or set GODOT_BIN to the Godot $Version console executable." }

# export_presets.cfg points at these two templates in .tools\templates.
$Templates = Join-Path $Tools "templates"
$Needed = @("windows_release_x86_64.exe", "macos.zip")
if ($Needed | Where-Object { -not (Test-Path (Join-Path $Templates $_)) }) {
  Step "Downloading the Godot $Version export templates (about 1 GB, once)"
  New-Item -ItemType Directory -Force $Templates | Out-Null
  $tpz = Join-Path $Tools "templates.tpz"
  Invoke-WebRequest "$Release/Godot_v$Version-stable_export_templates.tpz" -OutFile $tpz
  $archive = [System.IO.Compression.ZipFile]::OpenRead($tpz)
  try {
    foreach ($name in $Needed) {
      $entry = $archive.Entries | Where-Object { $_.FullName -eq "templates/$name" }
      if (-not $entry) { Fail "templates/$name is not in the downloaded templates." }
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Templates $name), $true)
    }
  } finally { $archive.Dispose() }
  Remove-Item $tpz
}

function Run-Godot([string[]]$arguments) {
  & $Godot @arguments
  if ($LASTEXITCODE -ne 0) { Fail "Godot failed: $($arguments -join ' ')" }
}

# --- Build -----------------------------------------------------------------------
$Builds = Join-Path $Root "builds"
$WinDir = Join-Path $Builds "windows"
$WinZip = Join-Path $Builds "TempleAscension-Windows.zip"
$MacZip = Join-Path $Builds "TempleAscension-macOS.zip"
if (Test-Path $WinDir) { Remove-Item -Recurse -Force $WinDir }
foreach ($old in @($WinZip, $MacZip)) { if (Test-Path $old) { Remove-Item -Force $old } }
New-Item -ItemType Directory -Force $WinDir, (Join-Path $Root "test-results") | Out-Null

Step "Importing assets"
Run-Godot @("--headless", "--path", ".", "--editor", "--import", "--quit")

Step "Exporting Windows"
Run-Godot @("--headless", "--path", ".", "--export-release", "Windows", "builds/windows/TempleAscension.exe")
if (-not (Test-Path (Join-Path $WinDir "TempleAscension.exe"))) { Fail "The Windows export produced no TempleAscension.exe." }

# What ships beside the game: the debug launcher, the readme, the asset list
# and every licence.
Copy-Item "tools\Debug Mode.bat" $WinDir
Copy-Item README.md, docs\ASSETS.md $WinDir
$Licenses = Join-Path $WinDir "licenses"
New-Item -ItemType Directory -Force $Licenses | Out-Null
Copy-Item "assets\licenses\*" $Licenses -Recurse
Copy-Item "assets\models\character\*License.txt" $Licenses
Compress-Archive -Path $WinDir -DestinationPath $WinZip

if (-not $SkipMac) {
  Step "Exporting macOS"
  Run-Godot @("--headless", "--path", ".", "--export-release", "macOS", "builds/TempleAscension-macOS.zip")
  if (-not (Test-Path $MacZip)) { Fail "The macOS export produced no zip." }
  # The extras are added into Godot's zip as it is: unpacking and re-zipping it
  # here would lose the app's executable permissions.
  $zip = [System.IO.Compression.ZipFile]::Open($MacZip, "Update")
  try {
    function Add-Entry($file, $name, $mode = 420) {  # 420 = 0644, 493 = 0755
      $entry = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $name)
      $entry.ExternalAttributes = ((0x8000 -bor $mode) -shl 16)
    }
    Add-Entry (Resolve-Path "tools\Debug Mode.command") "Debug Mode.command" 493
    Add-Entry (Resolve-Path README.md) "README.md"
    Add-Entry (Resolve-Path docs\ASSETS.md) "ASSETS.md"
    Get-ChildItem "assets\licenses" -Recurse -File | ForEach-Object {
      $relative = $_.FullName.Substring((Resolve-Path "assets\licenses").Path.Length + 1) -replace "\\", "/"
      Add-Entry $_.FullName "licenses/$relative"
    }
    Get-ChildItem "assets\models\character\*License.txt" | ForEach-Object { Add-Entry $_.FullName "licenses/$($_.Name)" }
  } finally { $zip.Dispose() }
}

Step "Done"
Write-Host "Windows: $WinZip"
if (-not $SkipMac) { Write-Host "macOS:   $MacZip" }
Write-Host "Run it:  builds\windows\TempleAscension.exe"
