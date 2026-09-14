$ROOT = "C:\Users\Administrator\Documents\Codes\Games\PSX"
$GODOT = "$ROOT\.tools\Godot_v4.7.2-stable_win64_console.exe"
$OUT = "$ROOT\captures\praca_matriz\mapa"
New-Item -ItemType Directory -Force -Path $OUT | Out-Null
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
# Stay SOUTH of coreto (~z=-56). Wake-up z=-48. Never go north of -52.
$shots = @(
  @{ name="01_eixo_igreja.png"; ir="272,-48,272,-70"; frame=150 },
  @{ name="05_denso_acordar.png"; ir="272,-48,272,-70"; frame=150 },
  @{ name="09_acordar_denso.png"; ir="272,-48,272,-70"; frame=150 },
  @{ name="02_coreto.png"; ir="272,-49,272,-58"; frame=150 },
  @{ name="07_coreto_v2.png"; ir="272,-49.5,272,-57"; frame=150 },
  @{ name="08_igreja_noite.png"; ir="272,-50,272,-74"; frame=150 },
  @{ name="06_igreja_perto.png"; ir="272,-50,272,-72"; frame=150 },
  @{ name="04_lado_casas.png"; ir="260,-48,275,-55"; frame=150 },
  @{ name="03_vista_elevada.png"; ir=""; de="272,-52,16,90,-40"; frame=150 }
)
$log = Join-Path $OUT "_godot_log_v3.txt"
"" | Set-Content $log
foreach ($s in $shots) {
  $shotPath = Join-Path $OUT $s.name
  Write-Output ("SHOOT " + $s.name)
  if ($s.de) {
    & $GODOT --path "$ROOT\game" --resolution 1280x720 -- --pular-abertura --fog=denso "--de-cima=$($s.de)" "--shot=$shotPath" "--shot-frame=$($s.frame)" --shot-quit 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 4
  } else {
    & $GODOT --path "$ROOT\game" --resolution 1280x720 -- --pular-abertura --fog=denso "--ir-para=$($s.ir)" "--shot=$shotPath" "--shot-frame=$($s.frame)" --shot-quit 2>&1 | Tee-Object -FilePath $log -Append | Select-Object -Last 4
  }
  Start-Sleep -Seconds 1
  if (Test-Path $shotPath) { Write-Output ("OK size=" + (Get-Item $shotPath).Length) } else { Write-Output "MISSING $($s.name)" }
}
Write-Output "DONE"
