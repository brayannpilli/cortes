# Instala Cortes en otro PC con Windows para poder publicarlo desde ahí (mismo link fijo).
# Uso, en PowerShell (Windows + R → powershell):
#   irm https://brayannpilli.github.io/cortes/instalar.ps1 -OutFile "$env:TEMP\instalar-cortes.ps1"
#   powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar-cortes.ps1"
# Opcional: CORTES_DEST cambia la carpeta y CORTES_SIN_PREGUNTAS=1 no pide la clave ni crea el acceso directo (pruebas).
# Se puede volver a ejecutar: salta lo que ya está instalado y actualiza la app.
# Continue: en Windows PowerShell 5.1, "Stop" convierte en error cualquier aviso que un programa escriba por stderr.
$ErrorActionPreference = "Continue"
$Repo = "brayannpilli/virocut-clon"
$Dest = if ($env:CORTES_DEST) { $env:CORTES_DEST } else { Join-Path ([Environment]::GetFolderPath("Desktop")) "Cortes" }
$SinPreguntas = $env:CORTES_SIN_PREGUNTAS -eq "1"

function Paso($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Refrescar-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function Tiene($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Instalar($id, $cmd) {
  if ($cmd -and (Tiene $cmd)) { Write-Host "  $id ya está."; return }
  Write-Host "  Instalando $id..."
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  Refrescar-Path
}

if (-not (Tiene "winget")) { Write-Host "Falta winget (App Installer de Microsoft Store). Instálalo y vuelve a ejecutar."; return }

Paso "Programas (Git, GitHub CLI, Node, Python, ffmpeg, Cloudflare)"
Instalar "Git.Git" "git"
Instalar "GitHub.cli" "gh"
Instalar "OpenJS.NodeJS.LTS" "node"
Instalar "Python.Python.3.13" "py"
Instalar "Gyan.FFmpeg" "ffmpeg"
if (-not (Test-Path "C:\Program Files (x86)\cloudflared\cloudflared.exe")) { Instalar "Cloudflare.cloudflared" $null } else { Write-Host "  Cloudflare.cloudflared ya está." }
Refrescar-Path
foreach ($c in "git", "gh", "node", "npm", "py", "ffmpeg") {
  if (-not (Tiene $c)) { Write-Host "No se encontró '$c' tras instalar. Cierra esta ventana, abre una nueva y vuelve a ejecutar." -ForegroundColor Red; return }
}

Paso "Cuenta de GitHub (para bajar la app y actualizar el link fijo)"
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "  Se abrirá el navegador: entra con la cuenta brayannpilli y autoriza."
  gh auth login --hostname github.com --git-protocol https --web
  if ($LASTEXITCODE -ne 0) { Write-Host "No se completó el inicio de sesión en GitHub." -ForegroundColor Red; return }
}
gh auth setup-git | Out-Null

Paso "App en $Dest"
if (Test-Path (Join-Path $Dest ".git")) {
  git -C $Dest pull --ff-only
} else {
  gh repo clone $Repo $Dest
}
Set-Location $Dest

Paso "Paquetes de Python (yt-dlp, Whisper, OpenCV)"
py -3 -m pip install --user -q -U yt-dlp faster-whisper "opencv-python-headless<5"

Paso "Paquetes de Node"
npm ci --no-audit --no-fund

Paso "Configuración (.env)"
if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  $key = if ($SinPreguntas) { "" } else { Read-Host "  Pega tu clave de Gemini (Enter para seguir sin IA)" }
  if ($key.Trim()) { (Get-Content ".env") -replace '^GEMINI_API_KEY=.*', "GEMINI_API_KEY=$($key.Trim())" | Set-Content ".env" -Encoding utf8 }
} else { Write-Host "  .env ya existe; se deja como está." }

if (-not $SinPreguntas) {
Paso "Acceso directo en el escritorio"
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Cortes en línea.lnk"
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = Join-Path $Dest "Cortes en linea.cmd"
$s.WorkingDirectory = $Dest
$s.Save()
}

Write-Host ""
Write-Host "Listo. Doble clic en «Cortes en línea» del escritorio para publicar la app desde este PC." -ForegroundColor Green
Write-Host "El link fijo https://brayannpilli.github.io/cortes pasará a apuntar a este equipo."
