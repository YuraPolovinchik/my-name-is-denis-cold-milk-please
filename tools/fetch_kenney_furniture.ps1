$ProgressPreference = 'SilentlyContinue'
# Старые PowerShell по умолчанию не умеют TLS 1.2 — включаем принудительно.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

$zip = Join-Path $env:TEMP 'kenney_furniture.zip'
$ok = $false

# 1) Парсим страницу ассета — там актуальная прямая ссылка на архив.
try {
	$page = Invoke-WebRequest -Uri 'https://kenney.nl/assets/furniture-kit' -UseBasicParsing -TimeoutSec 90
	$links = [regex]::Matches($page.Content, 'href="([^"]+\.zip)"')
	Write-Output ("PAGE HREF COUNT: " + $links.Count)
	foreach ($m in $links) {
		$hu = $m.Groups[1].Value
		if ($hu.StartsWith('/')) { $hu = 'https://kenney.nl' + $hu }
		Write-Output ("PAGE-LINK: " + $hu)
		if (-not $ok) {
			try {
				Invoke-WebRequest -Uri $hu -OutFile $zip -UseBasicParsing -TimeoutSec 300
				$len = (Get-Item $zip).Length
				Write-Output ("DOWNLOADED: " + $len)
				if ($len -gt 200000) { $ok = $true }
			} catch { Write-Output ("LINK-FAIL: " + $_.Exception.Message) }
		}
	}
	# Диагностика: любые ссылки с download
	$dlinks = [regex]::Matches($page.Content, '(href|src)="([^"]*download[^"]*)"')
	foreach ($m in $dlinks) { Write-Output ("DL-HINT: " + $m.Groups[2].Value) }
} catch {
	Write-Output ("PAGE-FAIL: " + $_.Exception.Message)
}

# 2) Прямые кандидаты, если парсинг не помог.
if (-not $ok) {
	$cands = @(
		'https://data.kenney.nl/furniture-kit/kenney_furniture-kit.zip',
		'https://data.kenney.nl/furnitureKit/furnitureKit.zip'
	)
	foreach ($u in $cands) {
		if ($ok) { break }
		try {
			Write-Output ("TRY: " + $u)
			Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 300
			if ((Get-Item $zip).Length -gt 200000) { $ok = $true }
		} catch { Write-Output ("FAIL: " + $_.Exception.Message) }
	}
}

if (-not $ok) { Write-Output 'RESULT: DOWNLOAD_FAILED'; exit 1 }

$tmp = Join-Path $env:TEMP 'kenney_furniture'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $tmp -Force

Write-Output '--- GLB FILES ---'
Get-ChildItem $tmp -Recurse -Filter *.glb | ForEach-Object { Write-Output ("GLB: " + $_.Name) }
Write-Output '--- ROOT ---'
Get-ChildItem $tmp | ForEach-Object { Write-Output ("ITEM: " + $_.Name) }
Write-Output 'RESULT: OK'
