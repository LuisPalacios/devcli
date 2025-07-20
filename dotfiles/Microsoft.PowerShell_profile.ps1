#
# Fichero $PROFILE:
# C:\Users\<usuario>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#

# ==================================================================
# Añado Ctrl-D para emular el funcionamiento de Linux
# ==================================================================
#
Set-PSReadlineKeyHandler -Key ctrl+d -Function ViExit

# ==================================================================
# Cambio el alias interno de rm a uno mas complejo (rm y rm -fr)
# ==================================================================
#
if (Get-Alias rm -ErrorAction SilentlyContinue) {
    Remove-Item Alias:rm -Force
}
function rm {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [String[]] $Args
    )

    if ($Args -contains "-fr") {
        # Remueve el parámetro -fr del arreglo de argumentos
        $targets = $Args | Where-Object { $_ -ne "-fr" }

        # Ejecuta el borrado recursivo y forzado
        Remove-Item -LiteralPath $targets -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        # Ejecuta borrado estándar
        Remove-Item -LiteralPath $Args -ErrorAction SilentlyContinue
    }
}

# ==================================================================
# Cambio el alias interno de ls a lsd https://github.com/lsd-rs/lsd
# ==================================================================
#
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force
}
function ls {
    lsd --group-directories-first @args
}

# ==================================================================
# Cambio de cd a zoxide https://github.com/ajeetdsouza/zoxide
# ==================================================================
#
if (Get-Alias cd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cd -Force
}
function cd {
    zoxide @args
}

# ==================================================================
# Elimino el alias a where para evitar conflictos con where.exe
# ==================================================================
#
if (Get-Alias where -ErrorAction SilentlyContinue) {
    Remove-Item Alias:where -Force
}

# ==================================================================
# Alias para nano, editor de texto en consola que
# viene con Git para Windows
# ==================================================================
#
function nano {
    # Buscar la ruta de git.exe en el sistema
    $gitPath = & where.exe git.exe 2>$null | Select-Object -First 1

    if (-not $gitPath) {
        Write-Error "Git no está instalado o no está en el PATH."
        return
    }

    # Asumir que nano.exe está en usr\bin\ dentro de la raíz de Git
    $gitRoot = Split-Path -Parent $gitPath
    $nanoPath = Join-Path $gitRoot "..\usr\bin\nano.exe" | Resolve-Path -ErrorAction SilentlyContinue

    if (-not $nanoPath) {
        Write-Error "nano.exe no encontrado en la instalación de Git."
        return
    }

    # Ejecutar nano.exe con todos los argumentos
    & $nanoPath @Args
}

# ==================================================================
# Alias para htop, que es un monitor de sistema interactivo
# Utiliza 'btm' (bottom) como alternativa en Windows
# ==================================================================
#
function htop {
    $btm = Get-Command btm -ErrorAction SilentlyContinue

    if ($btm) {
        & $btm @Args
    } else {
        Write-Warning "'btm' (bottom) no está instalado. Puedes instalarlo con 'scoop install bottom'"
    }
}

# ==================================================================
# 🔧 Carga automática de posh-git (autocompletado y estado Git)
# ==================================================================

if (-not (Get-Module -ListAvailable -Name posh-git)) {
    try {
        Write-Host "Instalando posh-git..." -ForegroundColor Yellow
        Install-Module posh-git -Scope CurrentUser -Force -AllowClobber
    }
    catch {
        Write-Warning "No se pudo instalar posh-git: $_"
    }
}

# ==================================================================
# Importa posh-git para integración con Git (autocompletado, estado, etc.)
# ==================================================================
try {
    Import-Module posh-git -ErrorAction Stop
}
catch {
    Write-Warning "No se pudo importar posh-git: $_"
}

# Ejecuto oh-my-posh para personalizar el prompt de PowerShell
#
oh-my-posh init pwsh --config ~/.luispa.omp.json | Invoke-Expression

# ==================================================================
# 🔮 Predicción inteligente PSReadLine
# ==================================================================

# Requiere PSReadLine 2.1+ (PowerShell 7.2+ recomendado)
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# ==================================================================
# ⚙️ Configuración de variables de entorno críticas
# ==================================================================

# Variables de entorno críticas para lsd, oh-my-posh y colores
$envVarsToSet = @()

# Verificar OMP_OS_ICON (icono del OS para oh-my-posh)
if (-not [Environment]::GetEnvironmentVariable("OMP_OS_ICON", "User")) {
    try {
        setx OMP_OS_ICON "🪟" >$null 2>&1
        $envVarsToSet += "OMP_OS_ICON"
        Write-Host "✅ Variable OMP_OS_ICON configurada" -ForegroundColor Green
    }
    catch {
        Write-Warning "No se pudo configurar OMP_OS_ICON: $_"
    }
}

# Verificar LS_COLORS (colores para lsd y directorios)
if (-not [Environment]::GetEnvironmentVariable("LS_COLORS", "User")) {
    try {
        $lsColors = "fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32:*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32:*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31:*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31:*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31:*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35:*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35:*.dl=01;35:*.gl=01;35:*.wmv=01;35"
        setx LS_COLORS $lsColors >$null 2>&1
        $envVarsToSet += "LS_COLORS"
        Write-Host "✅ Variable LS_COLORS configurada" -ForegroundColor Green
    }
    catch {
        Write-Warning "No se pudo configurar LS_COLORS: $_"
    }
}

# Mostrar mensaje importante si se configuraron variables
if ($envVarsToSet.Count -gt 0) {
    Write-Host ""
    Write-Host "🔄 " -NoNewline -ForegroundColor Yellow
    Write-Host "IMPORTANTE: " -NoNewline -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Variables de entorno configuradas: " -NoNewline -ForegroundColor Yellow
    Write-Host ($envVarsToSet -join ", ") -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠️  Para que los cambios surtan efecto, necesitas " -NoNewline -ForegroundColor Yellow
    Write-Host "REINICIAR WINDOWS" -ForegroundColor Red -BackgroundColor Black
    Write-Host "   y abrir una nueva sesión de PowerShell después del reinicio." -ForegroundColor Yellow
    Write-Host ""
}

