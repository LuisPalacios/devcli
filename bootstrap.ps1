#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Lang = "es-ES",

    [Parameter()]
    [switch]$Help
)

# Variables básicas para bootstrap
$REPO_URL = "https://github.com/LuisPalacios/devcli.git"
$BRANCH = "main"
$CURRENT_USER = $env:USERNAME
$SETUP_DIR = "$env:USERPROFILE\.devcli"

# Función de log minimalista
function Write-Log {
    param([string]$Message)
    Write-Host "[bootstrap] $Message" -ForegroundColor Cyan
}

# Función de ayuda
function Show-Help {
    $helpText = @"
CLI Setup - Configuración automatizada de entorno CLI para Windows

Uso: Ejecutar desde PowerShell con política de ejecución apropiada

OPCIONES:
  -Lang LOCALE          Configurar idioma (ej: en-US, es-ES)
  -Help                 Mostrar esta ayuda

EJEMPLOS:
  # Instalación con idioma por defecto (español)
  iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")

  # Instalación con idioma inglés
  iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Lang en-US"

IDIOMAS SOPORTADOS:
  es-ES (español, por defecto)
  en-US (inglés)

REQUISITOS:
  - Windows 11 (recomendado) o Windows 10
  - PowerShell 5.1 o superior
  - winget disponible
"@
    Write-Host $helpText
}

# Procesar argumentos
if ($Help) {
    Show-Help
    exit 0
}

# Validar formato de locale
if ($Lang -notmatch '^[a-z]{2}-[A-Z]{2}$') {
    Write-Error "Formato de locale inválido. Usa formato: ll-CC (Ejemplo: es-ES, en-US)"
    exit 1
}

# Detección de sistema operativo
function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    $isWindows10OrLater = ($version.Major -eq 10 -and $version.Build -ge 10240) -or ($version.Major -gt 10)

    if (-not $isWindows10OrLater) {
        Write-Error "❌ Windows 10 o superior requerido"
        exit 1
    }

    $isWindows11 = $version.Build -ge 22000
    return @{
        IsWindows11 = $isWindows11
        Version = $version
        Build = $version.Build
    }
}

# Verificar si se ejecuta como administrador
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Verificar herramientas necesarias
function Test-Prerequisites {
    # Verificar winget
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "❌ winget no está disponible. Instala App Installer desde Microsoft Store" -ErrorAction Stop
    }

    # Verificar git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Instalando git con winget..."
        try {
            winget install Git.Git --silent --accept-package-agreements --accept-source-agreements
            # Refrescar PATH usando método más eficiente de PowerShell 7
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        }
        catch {
            Write-Error "❌ No se pudo instalar git automáticamente" -ErrorAction Stop
        }
    }
}

# Función principal
function main {
    Write-Log "Iniciando configuración CLI para Windows..."

    $windowsInfo = Test-WindowsVersion
    $isAdmin = Test-Administrator

    Write-Log "Windows 11: $($windowsInfo.IsWindows11) | Admin: $isAdmin | Usuario: $CURRENT_USER"
    Write-Log "Idioma: $Lang"

    # Verificar prerequisitos
    Test-Prerequisites

    # Clonar o actualizar repositorio
    Write-Log "Preparando repositorio..."
    if (Test-Path $SETUP_DIR) {
        try {
            Push-Location $SETUP_DIR
            git reset --hard HEAD *>$null
            git clean -fd *>$null
            git pull *>$null
            Pop-Location
        }
        catch {
            Write-Warning "Error actualizando repositorio, clonando de nuevo..."
            Remove-Item $SETUP_DIR -Recurse -Force -ErrorAction SilentlyContinue
            git clone --branch $BRANCH $REPO_URL $SETUP_DIR *>$null
        }
    }
    else {
        git clone --branch $BRANCH $REPO_URL $SETUP_DIR *>$null
    }

    if (-not (Test-Path $SETUP_DIR)) {
        Write-Error "❌ Error clonando repositorio"
        exit 1
    }

    # Establecer variables de entorno para los scripts
    $env:SETUP_LANG = $Lang
    $env:SETUP_DIR = $SETUP_DIR
    $env:CURRENT_USER = $CURRENT_USER

    # Ejecutar scripts de instalación
    Push-Location "$SETUP_DIR\install"

    Write-Log "Ejecutando scripts de instalación:"
    $scripts = Get-ChildItem "*.ps1" | Where-Object { $_.Name -match '^\d{2}-.*\.ps1$' } | Sort-Object Name

    foreach ($script in $scripts) {
        Write-Log "▶ Ejecutando $($script.Name)..."
        try {
            & $script.FullName
        }
        catch {
            Write-Error "❌ Error ejecutando $($script.Name): $_"
            Pop-Location
            exit 1
        }
    }

    Pop-Location

    Write-Log "✅ Instalación completada"
    Write-Host ""
    Write-Host "🎉 ¡Configuración completada! Reinicia tu terminal para aplicar los cambios." -ForegroundColor Green
}

# Ejecutar función principal
main