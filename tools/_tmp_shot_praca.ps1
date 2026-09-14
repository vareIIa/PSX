$ErrorActionPreference = "Continue"
$root = "C:\Users\Administrator\Documents\Codes\Games\PSX"
$godot = Join-Path $root ".tools\Godot_v4.7.2-stable_win64_console.exe"
$outdir = Join-Path $root "captures\praca_matriz\_sessao_praca_visual"
New-Item -ItemType Directory -Force -Path $outdir | Out-Null
Set-Location $root
function Shot($name, $extra) {
  $out = Join-Path $outdir $name
  Write-Host "=== $name ==="
  $args = @("--path","game","--") + $extra + @("--shot=$out","--shot-frame=200","--shot-quit")
  & $godot @args 2>&1 | Select-Object -Last 15
  Write-Host "exists=$(Test-Path $out) size=$((Get-Item $out -EA SilentlyContinue).Length)"
}
Shot "after_eixo.png" @("--ir-para=270,-40,271,-51","--fog=denso","--pular-abertura")
Shot "after_ver_praca.png" @("--ver-praca")
