$ErrorActionPreference = 'Continue'
$files = @('loungeSofa.glb','chairDesk.glb','bedDouble.glb','table.glb','pottedPlant.glb','toaster.glb','lampRoundFloor.glb','bookcaseOpen.glb')
foreach ($f in $files) {
	$p = Join-Path 'assets\furniture' $f
	if (-not (Test-Path $p)) { Write-Output ("MISS " + $f); continue }
	$bytes = [IO.File]::ReadAllBytes($p)
	$txt = [Text.Encoding]::ASCII.GetString($bytes)
	$names = [regex]::Matches($txt, '"name":"([^"]{1,40})"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique -First 14
	Write-Output ("=== " + $f)
	Write-Output ($names -join ", ")
}
