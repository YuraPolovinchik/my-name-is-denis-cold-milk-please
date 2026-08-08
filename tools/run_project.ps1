param(
    [ValidateSet("Game", "Editor", "Tests")]
    [string]$Mode = "Game"
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Invoke-NativeCaptured {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    # Windows PowerShell wraps every line written to stderr by a native
    # process in NativeCommandError. With ErrorActionPreference=Stop even a
    # harmless Godot shutdown warning aborts the launcher before we can read
    # the real process exit code.
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $CapturedOutput = @(& $FilePath @ArgumentList 2>&1)
        $CapturedExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($null -eq $CapturedExitCode) {
        $CapturedExitCode = 0
    }
    return [PSCustomObject]@{
        Output = $CapturedOutput
        ExitCode = [int]$CapturedExitCode
    }
}

function Write-NativeOutput {
    param([object[]]$Lines)
    $Lines | ForEach-Object { Write-Host $_ }
}

$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ToolsDir "..")).Path
$GodotDir = Join-Path $ToolsDir "godot\4.4-stable"
$EditorExe = Join-Path $GodotDir "Godot_v4.4.1-stable_win64.exe"
$ConsoleExe = Join-Path $GodotDir "Godot_v4.4.1-stable_win64_console.exe"
$ProjectFile = Join-Path $ProjectRoot "project.godot"

if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    throw "project.godot was not found in: $ProjectRoot"
}

if (-not (Test-Path -LiteralPath $EditorExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $ConsoleExe -PathType Leaf)) {
    Write-Host "Godot 4.4.1 is not installed yet. Starting automatic installer..." -ForegroundColor Yellow
    & (Join-Path $ToolsDir "install_godot.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Godot installer returned exit code $LASTEXITCODE."
    }
}

# Run from the project directory and pass '.' to Godot. This avoids the Windows
# command-line bug caused by a quoted absolute path ending in a backslash and
# also works when parent folders contain spaces or Cyrillic characters.
Push-Location -LiteralPath $ProjectRoot
try {
    # A freshly extracted source project has no .godot import cache. Build it
    # once before headless tests so bundled WAV assets are available on the
    # very first launch as well as on later runs.
    Write-Host "Preparing bundled assets..." -ForegroundColor Cyan
    $ImportResult = Invoke-NativeCaptured $ConsoleExe @("--headless", "--editor", "--language", "en", "--path", ".", "--quit")
    $ImportOutput = $ImportResult.Output
    $ImportCode = $ImportResult.ExitCode
    Write-NativeOutput $ImportOutput
    if ($ImportCode -ne 0) {
        Write-Host "Godot could not import the bundled project assets." -ForegroundColor Red
        exit 2
    }

    switch ($Mode) {
        "Game" {
            Write-Host "Checking project scripts before launch..." -ForegroundColor Cyan
            $PreflightResult = Invoke-NativeCaptured $ConsoleExe @("--headless", "--language", "en", "--path", ".", "--", "--run-foundation-tests")
            $PreflightOutput = $PreflightResult.Output
            $PreflightCode = $PreflightResult.ExitCode
            $PreflightText = ($PreflightOutput | Out-String)
            Write-NativeOutput $PreflightOutput
            if ($PreflightCode -ne 0 -or $PreflightText -notmatch "DENIS_FOUNDATION_TESTS_OK") {
                Write-Host "" 
                Write-Host "Preflight failed. The game was not started." -ForegroundColor Red
                Write-Host "Expected marker: DENIS_FOUNDATION_TESTS_OK" -ForegroundColor Yellow
                exit 2
            }
            Write-Host "Project check passed. Starting the game..." -ForegroundColor Green
            $GameResult = Invoke-NativeCaptured $EditorExe @("--language", "en", "--path", ".")
            Write-NativeOutput $GameResult.Output
            $Code = $GameResult.ExitCode
        }
        "Editor" {
            $EditorResult = Invoke-NativeCaptured $EditorExe @("--editor", "--language", "en", "--path", ".")
            Write-NativeOutput $EditorResult.Output
            $Code = $EditorResult.ExitCode
        }
        "Tests" {
            $TestResult = Invoke-NativeCaptured $ConsoleExe @("--headless", "--language", "en", "--path", ".", "--", "--run-foundation-tests")
            Write-NativeOutput $TestResult.Output
            $Code = $TestResult.ExitCode
        }
    }
}
finally {
    Pop-Location
}

if ($null -eq $Code) { $Code = 0 }
exit $Code
