# ------------------------------------------------------------------
# env.ps1 - Variables y entorno compartido para scripts de instalación PowerShell
# ------------------------------------------------------------------

# Variables de entorno (definidas por bootstrap.ps1)
$script:SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$script:SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$script:CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$script:BIN_DIR = "$env:USERPROFILE\bin"

# Manejo de directorio original (heredado del bootstrap)
$script:OriginalDirectory = $env:ORIGINAL_DIRECTORY ?? $PWD.Path
$script:ShouldRestoreDirectory = $true

# Configuración de Nerd Fonts para Windows
$script:NERD_FONT_NAME = "FiraCode"
$script:NERD_FONT_FULL_NAME = "FiraCode Nerd Font"

# Directorio de archivos fuente (para herramientas locales)
$script:FILES_DIR = Join-Path $script:SETUP_DIR "files\bin"

# Función para detectar usuario actual de forma dinámica
function Get-CurrentUser {
    # Priorizar variables de entorno comunes
    if ($env:CURRENT_USER) {
        return $env:CURRENT_USER
    }
    elseif ($env:USERNAME) {
        return $env:USERNAME
    }
    else {
        return [System.Environment]::UserName
    }
}

# Actualizar usuario actual
$script:CURRENT_USER = Get-CurrentUser

# Validar entorno mínimo
function Test-Environment {
    # Verificar que estamos en Windows
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
        Write-Error "Este script solo funciona en Windows"
        return $false
    }

    # Verificar permisos de escritura en directorio de usuario
    if (-not (Test-Path $env:USERPROFILE -PathType Container)) {
        Write-Error "No se puede acceder al directorio de usuario: $env:USERPROFILE"
        return $false
    }

    return $true
}

# Exportar variables para que estén disponibles en el script que hace dot sourcing
$Global:SETUP_LANG = $script:SETUP_LANG
$Global:SETUP_DIR = $script:SETUP_DIR
$Global:CURRENT_USER = $script:CURRENT_USER
$Global:BIN_DIR = $script:BIN_DIR
$Global:OriginalDirectory = $script:OriginalDirectory
$Global:ShouldRestoreDirectory = $script:ShouldRestoreDirectory
$Global:NERD_FONT_NAME = $script:NERD_FONT_NAME
$Global:NERD_FONT_FULL_NAME = $script:NERD_FONT_FULL_NAME
$Global:FILES_DIR = $script:FILES_DIR 