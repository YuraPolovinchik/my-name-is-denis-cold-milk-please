param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$ProjectRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    (Get-Location).Path
} else {
    (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
$OutputDir = Join-Path $ProjectRoot "assets\payment_altar\textures"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function New-Atlas {
    param(
        [string]$Name,
        [string[]]$Lines,
        [System.Drawing.Color]$Primary,
        [System.Drawing.Color]$Secondary,
        [bool]$PaperBackground = $false
    )
    $bitmap = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($PaperBackground) {
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 214, 197, 153))
        $stainBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28, 88, 48, 26))
        for ($i = 0; $i -lt 40; $i++) {
            $x = ($i * 137) % 980
            $y = ($i * 223) % 980
            $graphics.FillEllipse($stainBrush, $x, $y, 30 + ($i % 6) * 12, 18 + ($i % 5) * 9)
        }
        $stainBrush.Dispose()
    } else {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }
    $fonts = @(
        (New-Object System.Drawing.Font "Arial", 54, ([System.Drawing.FontStyle]::Bold)),
        (New-Object System.Drawing.Font "Arial", 37, ([System.Drawing.FontStyle]::Bold)),
        (New-Object System.Drawing.Font "Arial", 25, ([System.Drawing.FontStyle]::Regular)),
        (New-Object System.Drawing.Font "Arial", 18, ([System.Drawing.FontStyle]::Bold))
    )
    $brushA = New-Object System.Drawing.SolidBrush $Primary
    $brushB = New-Object System.Drawing.SolidBrush $Secondary
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $column = $i % 3
        $row = [Math]::Floor($i / 3)
        $x = 34 + $column * 326 + (($i * 29) % 34)
        $y = 35 + $row * 126 + (($i * 17) % 28)
        $font = $fonts[$i % $fonts.Count]
        $brush = if (($i % 3) -eq 0) { $brushB } else { $brushA }
        $angle = -8 + (($i * 7) % 17)
        $graphics.TranslateTransform($x, $y)
        $graphics.RotateTransform($angle)
        $graphics.DrawString($Lines[$i], $font, $brush, 0, 0)
        if (($i % 5) -eq 2) {
            $pen = New-Object System.Drawing.Pen $Secondary, 5
            $graphics.DrawLine($pen, 0, 25, 285, 14)
            $pen.Dispose()
        }
        $graphics.ResetTransform()
    }
    $path = Join-Path $OutputDir ($Name + ".png")
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $brushA.Dispose()
    $brushB.Dispose()
    foreach ($font in $fonts) { $font.Dispose() }
    $graphics.Dispose()
    $bitmap.Dispose()
    Write-Host "Generated $path"
}

$MainPhrases = @(
    "THE ПЛАТЕЖ", "МЫ ЖДЁМ", "THE ПЛАТЕЖ ГРЯДЁТ",
    "ОН БЫЛ ОБЕЩАН", "ДЕНЬ 100", "ЕЩЁ НЕМНОГО",
    "СЕГОДНЯ?", "ЗАВТРА?", "В ОБРАБОТКЕ",
    "ОЖИДАЙТЕ", "ПЕРЕНЕСЁН", "THE ПЛАТЕЖ",
    "СРЕДСТВА СКОРО ПОСТУПЯТ", "ГДЕ ДЕНЬГИ", "THE ПЛАТЕЖ НЕ ЗАБЫЛ",
    "МЫ НЕ ЗАБЫЛИ", "THE ПЛАТЕЖ", "НЕ СПРАШИВАЙ БУХГАЛТЕРИЮ",
    "ОЖИДАЙТЕ", "THE ПЛАТЕЖ ВИДИТ ВСЁ", "ДЕНЬ 100"
)
$SmallPhrases = @(
    "THE ПЛАТЕЖ", "В ОБРАБОТКЕ", "ОЖИДАЙТЕ",
    "ПЕРЕНЕСЁН", "THE ПЛАТЕЖ", "СЕГОДНЯ?",
    "МЫ ЖДЁМ", "ЗАВТРА?", "THE ПЛАТЕЖ",
    "УТОЧНЯЕМ ИНФОРМАЦИЮ", "ЕЩЁ НЕМНОГО", "THE ПЛАТЕЖ",
    "ОН БЫЛ ОБЕЩАН", "ОЖИДАЙТЕ", "ГДЕ ДЕНЬГИ",
    "THE ПЛАТЕЖ", "ПЕРЕНЕСЁН", "МЫ НЕ ЗАБЫЛИ",
    "THE ПЛАТЕЖ", "ДЕНЬ 100", "В ОБРАБОТКЕ"
)
$Tallies = @(
    "I I I I", "ДЕНЬ 87", "THE ПЛАТЕЖ",
    "I I I I", "ДЕНЬ 92", "ОЖИДАЙТЕ",
    "I I I I", "ДЕНЬ 96", "ПЕРЕНЕСЁН",
    "I I I I", "ДЕНЬ 99", "THE ПЛАТЕЖ",
    "I I I I", "ДЕНЬ 100", "СЕГОДНЯ ТОЧНО",
    "I I I I", "ЕЩЁ НЕМНОГО", "THE ПЛАТЕЖ"
)
$PaperNotes = @(
    "ПЛАТЁЖ В ОБРАБОТКЕ", "ОЖИДАЙТЕ ДО КОНЦА НЕДЕЛИ", "ПЕРЕНЕСЕНО",
    "СРЕДСТВА БУДУТ ЗАЧИСЛЕНЫ", "УТОЧНЯЕМ ИНФОРМАЦИЮ", "ДЕНЬ 100",
    "THE ПЛАТЕЖ", "ВОТ ТЕПЕРЬ ТОЧНО", "СТАТУС: ОЖИДАЕТСЯ",
    "СЕГОДНЯ?", "ЗАВТРА?", "НЕ СПРАШИВАЙ БУХГАЛТЕРИЮ"
)

New-Atlas "wall_text_atlas" $MainPhrases ([System.Drawing.Color]::FromArgb(220, 28, 23, 25)) ([System.Drawing.Color]::FromArgb(225, 126, 42, 47))
New-Atlas "wall_text_small" $SmallPhrases ([System.Drawing.Color]::FromArgb(205, 205, 194, 171)) ([System.Drawing.Color]::FromArgb(220, 116, 36, 42))
New-Atlas "wall_text_tallies" $Tallies ([System.Drawing.Color]::FromArgb(215, 38, 32, 34)) ([System.Drawing.Color]::FromArgb(225, 132, 43, 48))
New-Atlas "paper_notes_atlas" $PaperNotes ([System.Drawing.Color]::FromArgb(255, 46, 34, 30)) ([System.Drawing.Color]::FromArgb(255, 125, 38, 43)) $true

$symbolBitmap = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$symbolGraphics = [System.Drawing.Graphics]::FromImage($symbolBitmap)
$symbolGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$symbolGraphics.Clear([System.Drawing.Color]::Transparent)
$symbolPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 196, 180, 151)), 26
$redPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 132, 43, 48)), 18
$symbolGraphics.DrawEllipse($symbolPen, 115, 115, 794, 794)
$symbolGraphics.DrawArc($redPen, 205, 205, 614, 614, -50, 290)
$arrow = @(
    (New-Object System.Drawing.Point 752, 220),
    (New-Object System.Drawing.Point 842, 244),
    (New-Object System.Drawing.Point 782, 315)
)
$symbolGraphics.DrawLines($redPen, $arrow)
$symbolFont = New-Object System.Drawing.Font "Arial", 245, ([System.Drawing.FontStyle]::Bold)
$dotFont = New-Object System.Drawing.Font "Arial", 95, ([System.Drawing.FontStyle]::Bold)
$symbolBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 206, 191, 160))
$symbolGraphics.DrawString("₽", $symbolFont, $symbolBrush, 350, 290)
$symbolGraphics.DrawString("• • •", $dotFont, $symbolBrush, 315, 645)
$symbolGraphics.DrawString("THE ПЛАТЕЖ", (New-Object System.Drawing.Font "Arial", 42, ([System.Drawing.FontStyle]::Bold)), $symbolBrush, 330, 825)
$symbolPath = Join-Path $OutputDir "payment_symbol.png"
$symbolBitmap.Save($symbolPath, [System.Drawing.Imaging.ImageFormat]::Png)
$symbolBrush.Dispose()
$symbolFont.Dispose()
$dotFont.Dispose()
$symbolPen.Dispose()
$redPen.Dispose()
$symbolGraphics.Dispose()
$symbolBitmap.Dispose()
Write-Host "Generated $symbolPath"
