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

