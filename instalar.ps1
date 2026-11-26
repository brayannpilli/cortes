# Instala (o actualiza) Cortes en cualquier PC con Windows. No necesita cuenta de GitHub.
# Una sola linea en PowerShell:
#   irm https://brayannpilli.github.io/cortes/instalar.ps1 | iex
# Pide solo el codigo de instalacion (lo eligio quien publica Cortes). Se puede volver a ejecutar para actualizar.
# Este archivo va sin acentos a proposito: asi funciona igual al pegarlo con irm | iex.
# Opcional: CORTES_DEST cambia la carpeta; CORTES_CODIGO y CORTES_PAQUETE sirven para pruebas sin preguntas.
$ErrorActionPreference = "Continue"
$Paquete = if ($env:CORTES_PAQUETE) { $env:CORTES_PAQUETE } else { "https://raw.githubusercontent.com/brayannpilli/cortes/main/paquete.bin" }
$Dest = if ($env:CORTES_DEST) { $env:CORTES_DEST } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "Cortes" }
$Prueba = [bool]$env:CORTES_CODIGO
$Guardado = Join-Path $env:LOCALAPPDATA "Cortes\codigo.bin"

function Paso($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Refrescar-Path { $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") }
function Tiene($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Instalar($id, $cmd) {
  if ($cmd -and (Tiene $cmd)) { Write-Host "  $id ya esta."; return }
  Write-Host "  Instalando $id..."
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  Refrescar-Path
}

function Unprotect-Bytes([byte[]]$b, [string]$pass) {
  if ($b.Length -lt 7 + 16 + 16 + 16 + 32 -or [Text.Encoding]::ASCII.GetString($b, 0, 7) -ne "CORTES1") { throw "paquete no valido" }
  $salt = $b[7..22]; $iv = $b[23..38]
  $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($pass, [byte[]]$salt, 300000, [Security.Cryptography.HashAlgorithmName]::SHA256)
  $k = $kdf.GetBytes(64)
  $hmac = New-Object Security.Cryptography.HMACSHA256(, [byte[]]$k[32..63])
  $tag = $hmac.ComputeHash($b, 0, $b.Length - 32)
  $diff = 0
  for ($i = 0; $i -lt 32; $i++) { $diff = $diff -bor ($tag[$i] -bxor $b[$b.Length - 32 + $i]) }
  if ($diff -ne 0) { return $null }  # codigo incorrecto
  $aes = [Security.Cryptography.Aes]::Create()
  $aes.Key = [byte[]]$k[0..31]; $aes.IV = [byte[]]$iv
  return , $aes.CreateDecryptor().TransformFinalBlock($b, 39, $b.Length - 39 - 32)
}

if (-not (Tiene "winget")) { Write-Host "Falta winget (App Installer de Microsoft Store). Instalalo y vuelve a ejecutar."; return }

Paso "Programas (Node, Python, ffmpeg, Cloudflare)"
Instalar "OpenJS.NodeJS.LTS" "node"
Instalar "Python.Python.3.13" "py"
Instalar "Gyan.FFmpeg" "ffmpeg"
if (Test-Path "C:\Program Files (x86)\cloudflared\cloudflared.exe") { Write-Host "  Cloudflare.cloudflared ya esta." } else { Instalar "Cloudflare.cloudflared" $null }
Refrescar-Path
foreach ($c in "node", "npm", "py", "ffmpeg") {
  if (-not (Tiene $c)) { Write-Host "No se encontro '$c' tras instalar. Cierra PowerShell, abre uno nuevo y vuelve a pegar la linea." -ForegroundColor Red; return }
}

Paso "Paquete de Cortes"
$tmp = Join-Path $env:TEMP "cortes-instalar"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null
$bin = Join-Path $tmp "paquete.bin"
if ($Paquete -match "^https?://") { Invoke-WebRequest -UseBasicParsing -Uri $Paquete -OutFile $bin } else { Copy-Item $Paquete $bin }
$bytes = [IO.File]::ReadAllBytes($bin)

$zip = $null
for ($intento = 0; $intento -lt 3 -and -not $zip; $intento++) {
  if ($Prueba) { $codigo = $env:CORTES_CODIGO }
  elseif ($intento -eq 0 -and (Test-Path $Guardado)) {
    $ss = Get-Content $Guardado | ConvertTo-SecureString
    $codigo = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
  } else {
    $ss = Read-Host "  Codigo de instalacion" -AsSecureString
    $codigo = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
  }
  Write-Host "  Abriendo el paquete..."
  $zip = Unprotect-Bytes $bytes $codigo
  if (-not $zip) { Write-Host "  Codigo incorrecto." -ForegroundColor Yellow; if ($Prueba) { break } }
}
if (-not $zip) { Write-Host "No se pudo abrir el paquete. Pide el codigo a quien publica Cortes." -ForegroundColor Red; return }
if (-not $Prueba) {
  # Se guarda cifrado para este usuario de Windows (DPAPI): las actualizaciones no lo vuelven a pedir.
  New-Item -ItemType Directory -Force (Split-Path $Guardado) | Out-Null
  ConvertTo-SecureString $codigo -AsPlainText -Force | ConvertFrom-SecureString | Set-Content $Guardado
}

Paso "App en $Dest"
$zipFile = Join-Path $tmp "app.zip"
[IO.File]::WriteAllBytes($zipFile, $zip)
$app = Join-Path $tmp "app"
Expand-Archive -Path $zipFile -DestinationPath $app -Force
$secretos = Get-Content (Join-Path $app "secretos.json") -Raw | ConvertFrom-Json
Remove-Item (Join-Path $app "secretos.json")
New-Item -ItemType Directory -Force $Dest | Out-Null
# Si Cortes esta encendido en segundo plano, se apaga antes de actualizar (luego se vuelve a abrir).
if (-not $Prueba -and (Test-Path (Join-Path $Dest "data\en-linea.pid")) -and (Test-Path (Join-Path $Dest "scripts\apagar.ps1"))) {
  Write-Host "  Apagando Cortes para actualizarlo..."
  & (Join-Path $Dest "scripts\apagar.ps1")
}
# Se copia encima: se conservan data\ (videos, clips) y node_modules\.
Copy-Item -Path (Join-Path $app "*") -Destination $Dest -Recurse -Force
Set-Location $Dest
Write-Host "  Version $($secretos.version)"

Paso "Claves"
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env" }
$lines = @(Get-Content ".env")
# HF_BIBLIOTECA_*: biblioteca en la nube (los mismos videos en todos los PCs).
foreach ($kv in @(@("GEMINI_API_KEY", $secretos.gemini), @("GROQ_API_KEY", $secretos.groq), @("HF_BIBLIOTECA_TOKEN", $secretos.hfToken), @("HF_BIBLIOTECA_REPO", $secretos.hfRepo))) {
  if ($lines -match "^$($kv[0])=") { $lines = $lines -replace "^$($kv[0])=.*", "$($kv[0])=$($kv[1])" } else { $lines += "$($kv[0])=$($kv[1])" }
}
[IO.File]::WriteAllLines((Join-Path $Dest ".env"), $lines, (New-Object Text.UTF8Encoding $false))
New-Item -ItemType Directory -Force (Join-Path $Dest "data") | Out-Null
@{ repo = $secretos.linkRepo; token = $secretos.linkToken } | ConvertTo-Json | Set-Content (Join-Path $Dest "data\link-token.json") -Encoding ascii
Write-Host "  Gemini: $(if ($secretos.gemini) { 'si' } else { 'no' })   Groq: $(if ($secretos.groq) { 'si' } else { 'no' })   Nube: $(if ($secretos.hfToken) { 'si' } else { 'no' })"

Paso "Paquetes de Python (yt-dlp, Whisper, OpenCV)"
py -3 -m pip install --user -q -U yt-dlp faster-whisper "opencv-python-headless<5" 2>$null

Paso "Paquetes de Node"
# npm.cmd y no npm: en equipos con scripts bloqueados (ExecutionPolicy) npm.ps1 no se puede ejecutar.
npm.cmd ci --no-audit --no-fund --loglevel=error
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $Dest "node_modules\.bin\tsc.cmd"))) {
  Write-Host "  Reintentando la instalacion de paquetes de Node..." -ForegroundColor Yellow
  npm.cmd install --no-audit --no-fund --loglevel=error
  if ($LASTEXITCODE -ne 0) { Write-Host "No se pudieron instalar los paquetes de Node. Revisa la conexion y vuelve a pegar la linea." -ForegroundColor Red; return }
}

if (-not $Prueba) {
  Paso "IA local opcional (Ollama)"
  if (Tiene "ollama") { Write-Host "  Ollama ya esta." }
  else {
    Write-Host "  Ollama es un respaldo gratis cuando Gemini esta saturado. Descarga unos 3,7 GB (programa + modelo qwen3:4b)."
    $r = Read-Host "  Instalar Ollama? (s/N)"
    if ($r -match "^[sSyY]") {
      Instalar "Ollama.Ollama" "ollama"
      if (Tiene "ollama") { Write-Host "  Descargando el modelo qwen3:4b..."; ollama pull qwen3:4b }
    }
  }
}

if (-not $Prueba) {
  Paso "Accesos directos (escritorio y arranque con Windows)"
  $desk = [Environment]::GetFolderPath("Desktop")
  $sh = New-Object -ComObject WScript.Shell
  # Cortes en linea (sin ventana), Apagar Cortes y arranque oculto al iniciar sesion.
  & (Join-Path $Dest "scripts\accesos.ps1")
  $s = $sh.CreateShortcut((Join-Path $desk "Actualizar Cortes.lnk"))
  $s.TargetPath = "powershell.exe"
  $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "irm https://brayannpilli.github.io/cortes/instalar.ps1 | iex; Read-Host ''Enter para cerrar''"'
  $s.Save()
}
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Listo. Cortes funciona sin ventana y arranca solo al iniciar Windows." -ForegroundColor Green
Write-Host "Para apagarlo: 'Apagar Cortes' en el escritorio. Para encenderlo: 'Cortes en linea'."
Write-Host "Link fijo: https://brayannpilli.github.io/cortes"
