param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ToolsDir
$Destination = Join-Path $ToolsDir "godot\4.4-stable"
$EditorExe = Join-Path $Destination "Godot_v4.4.1-stable_win64.exe"
$ConsoleExe = Join-Path $Destination "Godot_v4.4.1-stable_win64_console.exe"
$Archive = Join-Path $env:TEMP "Godot_v4.4.1-stable_win64.exe.zip"

if ((Test-Path $EditorExe) -and (Test-Path $ConsoleExe) -and -not $Force) {
    Write-Host "Godot 4.4.1 is already installed." -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$Urls = @(
    "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_win64.exe.zip",
    "https://downloads.tuxfamily.org/godotengine/4.4.1/Godot_v4.4.1-stable_win64.exe.zip"
)

function Download-File([string]$Url, [string]$Output) {
    Write-Host "Downloading Godot from:" -ForegroundColor Cyan
    Write-Host $Url
    if (Test-Path $Output) { Remove-Item $Output -Force }

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing -TimeoutSec 180
    }
    catch {
        Write-Host "Invoke-WebRequest failed, trying WebClient..." -ForegroundColor Yellow
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "DenisCoffeeHellInstaller/1.1")
        $client.DownloadFile($Url, $Output)
    }

    if (-not (Test-Path $Output)) { throw "Download did not create a file." }
    $length = (Get-Item $Output).Length
    if ($length -lt 10000000) { throw "Downloaded file is too small ($length bytes)." }
}

$Downloaded = $false
$Errors = @()
foreach ($Url in $Urls) {
    try {
        Download-File $Url $Archive
        $Downloaded = $true
        break
    }
    catch {
        $Errors += "${Url}: $($_.Exception.Message)"
        Write-Host "Mirror failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $Downloaded) {
    Write-Host "Could not download Godot 4.4.1." -ForegroundColor Red
    Write-Host "Tried:" -ForegroundColor Red
    $Errors | ForEach-Object { Write-Host " - $_" }
    Write-Host "You can download the Standard Windows build manually from the official Godot 4.4.1 release and extract it to:" -ForegroundColor Yellow
    Write-Host $Destination -ForegroundColor Yellow
    exit 1
}

Write-Host "Extracting..." -ForegroundColor Cyan
Get-ChildItem -Path $Destination -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
Expand-Archive -Path $Archive -DestinationPath $Destination -Force

if (-not (Test-Path $EditorExe)) {
    $FoundEditor = Get-ChildItem -Path $Destination -Filter "Godot_v4.4.1-stable_win64.exe" -Recurse | Select-Object -First 1
    if ($FoundEditor) { Copy-Item $FoundEditor.FullName $EditorExe -Force }
}
if (-not (Test-Path $ConsoleExe)) {
    $FoundConsole = Get-ChildItem -Path $Destination -Filter "Godot_v4.4.1-stable_win64_console.exe" -Recurse | Select-Object -First 1
    if ($FoundConsole) { Copy-Item $FoundConsole.FullName $ConsoleExe -Force }
}

if (-not (Test-Path $EditorExe)) { throw "Godot editor executable was not found after extraction." }
if (-not (Test-Path $ConsoleExe)) { throw "Godot console executable was not found after extraction." }

Remove-Item $Archive -Force -ErrorAction SilentlyContinue
Write-Host "Godot 4.4.1 installed successfully." -ForegroundColor Green
Write-Host "Location: $Destination"
exit 0
