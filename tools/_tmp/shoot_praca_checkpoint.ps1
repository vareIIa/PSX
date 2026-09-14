$ROOT = "C:\Users\Administrator\Documents\Codes\Games\PSX"
$GODOT = "$ROOT\.tools\Godot_v4.7.2-stable_win64_console.exe"
$OUT = "$ROOT\captures\praca_matriz\mapa"
New-Item -ItemType Directory -Force -Path $OUT | Out-Null
$shots = @(
  @{ name="01_eixo_igreja.png"; ir="272,-48,272,-66"; frame=140 },
  @{ name="05_denso_acordar.png"; ir="272,-48,272,-66"; frame=140 },
  @{ name="09_acordar_denso.png"; ir="272,-48,272,-66"; frame=140 },
  @{ name="02_coreto.png"; ir="272,-52,272,-58"; frame=140 },
  @{ name="07_coreto_v2.png"; ir="272,-51,272,-57"; frame=140 },
  @{ name="08_igreja_noite.png"; ir="272,-58,272,-72"; frame=140 },
  @{ name="06_igreja_perto.png"; ir="272,-62,272,-74"; frame=140 },
  @{ name="04_lado_casas.png"; ir="258,-48,272,-48"; frame=140 }
)
$log = Join-Path $OUT "_godot_log.txt"
"" | Set-Content $log
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
foreach ($s in $shots) {
  $shotPath = Join-Path $OUT $s.name
  Write-Output ("SHOOT " + $s.name)
  & $GODOT --path "$ROOT\game" --resolution 1280x720 -- --pular-abertura --fog=denso "--ir-para=$($s.ir)" "--shot=$shotPath" "--shot-frame=$($s.frame)" --shot-quit 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 6
  if (Test-Path $shotPath) { Write-Output ("OK size=" + (Get-Item $shotPath).Length) } else { Write-Output "MISSING $($s.name)" }
  Start-Sleep -Seconds 1
}
# elevated last
$shotPath = Join-Path $OUT "03_vista_elevada.png"
Write-Output "SHOOT 03_vista_elevada.png"
& $GODOT --path "$ROOT\game" --resolution 1280x720 -- --pular-abertura --fog=denso --de-cima=272,-48,18,90,-35 "--shot=$shotPath" --shot-frame=140 --shot-quit 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 6
if (Test-Path $shotPath) { Write-Output ("OK size=" + (Get-Item $shotPath).Length) } else { Write-Output "MISSING 03" }
Write-Output "DONE"
