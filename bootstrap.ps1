#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Lang = "es-ES",

    [Parameter()]
    [ValidateSet("minimal", "dev", "full")]
    [string]$Profile = "full",

    [Parameter()]
    [switch]$Help
)

# Variables básicas para bootstrap
$REPO_URL = "https://github.com/LuisPalacios/devcli.git"
$BRANCH = "main"
$CURRENT_USER = $env:USERNAME
$SETUP_DIR = "$env:USERPROFILE\.devcli"

# Guardar directorio original para restaurarlo en caso de interrupción
$script:OriginalDirectory = $PWD.Path

# Flag para controlar si debemos restaurar el directorio
$script:ShouldRestoreDirectory = $true

# Función de log minimalista
function Write-Log {
    param([string]$Message)
    Write-Host "[bootstrap] $Message" -ForegroundColor Cyan
}

# Función para restaurar directorio original
function Restore-OriginalDirectory {
    if ($script:ShouldRestoreDirectory -and $script:OriginalDirectory) {
        try {
            Set-Location $script:OriginalDirectory -ErrorAction SilentlyContinue
            Write-Log "Directorio restaurado: $script:OriginalDirectory"
        }
        catch {
            Write-Warning "No se pudo restaurar el directorio original: $script:OriginalDirectory"
        }
    }
}

# Función para manejar interrupción por Ctrl-C
function Handle-Interruption {
    Write-Host "`n❌ Operación interrumpida por el usuario" -ForegroundColor Red
    Restore-OriginalDirectory
    exit 130 # Código de salida estándar para Ctrl-C
}

# Configurar manejo de Ctrl-C
function Setup-InterruptionHandler {
    try {
        # Register-EngineEvent funciona en el proceso principal
        $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
            if ($script:ShouldRestoreDirectory) {
                Restore-OriginalDirectory
            }
        }

        # Capturar señales de cancelación
        # CancelKeyPress para Ctrl-C inmediato usando sintaxis correcta
        $null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action {
            $Event.Args[1].Cancel = $true
            Handle-Interruption
        }
    }
    catch {
        Write-Warning "No se pudo configurar el manejador de interrupciones: $_"
    }
}

# Función de ayuda
function Show-Help {
    $helpText = @"
CLI Setup - Configuración automatizada de entorno CLI para Windows

Uso: Ejecutar desde PowerShell con política de ejecución apropiada

OPCIONES:
  -Lang LOCALE          Configurar idioma (ej: en-US, es-ES)
  -Profile PROFILE      Perfil de instalación: minimal, dev, full (defecto: full)
  -Help                 Mostrar esta ayuda

PERFILES:
  minimal   Herramientas esenciales (fzf, lsd, ripgrep, bat, fd, ...)
  dev       minimal + herramientas de desarrollo (mkcert, uv, ...)
  full      Todas las herramientas (defecto)

EJEMPLOS:
  # Instalación completa con idioma por defecto (español)
  iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")

  # Instalación mínima
  iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile minimal"

  # Instalación dev con idioma inglés
  iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile dev -Lang en-US"

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

    # Verificar e instalar scoop si es necesario
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Log "Scoop no está instalado. Instalando..."
        try {
            # Configurar política de ejecución si es necesario
            $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
            if ($currentPolicy -eq "Restricted") {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-Log "Política de ejecución actualizada a RemoteSigned"
            }

            # Instalar scoop (descarga primero, ejecuta después — evita el patrón
            # download-cradle que los antivirus corporales detectan como sospechoso)
            $scoopInstaller = "$env:TEMP\scoop-install.ps1"
            Invoke-RestMethod -Uri https://get.scoop.sh -OutFile $scoopInstaller
            & $scoopInstaller
            Remove-Item $scoopInstaller -Force -ErrorAction SilentlyContinue

            # Refrescar PATH para que scoop esté disponible
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

            # Verificar instalación
            if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
                Write-Error "❌ No se pudo instalar scoop automáticamente" -ErrorAction Stop
            }
            else {
                Write-Log "✅ Scoop instalado correctamente" -ForegroundColor Green

                # Agregar bucket extras solo si no está instalado
                Write-Log "Verificando bucket extras de Scoop..."
                try {
                    $buckets = scoop bucket list | ForEach-Object { $_.Split()[0] }  # first column only
                    if ('extras' -in $buckets) {
                        Write-Log "ℹ️ El bucket extras ya está agregado" -ForegroundColor Yellow
                    }
                    else {
                        scoop bucket add extras
                        Write-Log "✅ Bucket extras agregado correctamente" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Warning "⚠️ Error al verificar o agregar el bucket extras: $_"
                }

            }
        }
        catch {
            Write-Error "❌ Error instalando scoop: $_" -ErrorAction Stop
        }
    }

    # Verificar y agregar bucket extras si scoop ya estaba instalado
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        # Verificar si el bucket extras ya está agregado
        $bucketsOutput = scoop bucket list 2>$null
        if ($bucketsOutput -and $bucketsOutput -notmatch "extras") {
            Write-Log "Agregando bucket extras de scoop..."
            try {
                scoop bucket add extras
                Write-Log "✅ Bucket extras agregado correctamente" -ForegroundColor Green
            }
            catch {
                Write-Warning "⚠️ No se pudo agregar el bucket extras: $_"
            }
        }
        else {
            Write-Log "✅ Bucket extras ya está disponible" -ForegroundColor Green
        }
    }

    # Verificar e instalar git si es necesario (con winget)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Instalando git con winget..."
        try {
            winget install Git.Git --silent --accept-package-agreements --accept-source-agreements
            # Refrescar PATH para que git esté disponible
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

            # Verificar instalación
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Error "❌ No se pudo instalar git automáticamente" -ErrorAction Stop
            }
            else {
                Write-Log "✅ Git instalado correctamente" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "❌ Error instalando git: $_" -ErrorAction Stop
        }
    }

    # Verificar e instalar pnpm - gestor de paquetes NodeJS.
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Log "Instalando pnpm con winget..."
        try {
            winget install pnpm.pnpm --silent --accept-package-agreements --accept-source-agreements
            # Refrescar PATH para que pnpm esté disponible
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

            # Verificar instalación
            if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
                Write-Error "❌ No se pudo instalar pnpm automáticamente" -ErrorAction Stop
            }
            else {
                Write-Log "✅ pnpm instalado correctamente" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "❌ Error instalando pnpm: $_" -ErrorAction Stop
        }
    }
}

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada en bootstrap: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    # Configurar manejo de interrupciones
    Setup-InterruptionHandler

    try {
        Write-Log "Iniciando configuración CLI para Windows (perfil: $Profile)..."

        $windowsInfo = Test-WindowsVersion
        $isAdmin = Test-Administrator

        # Verificar prerequisitos
        Test-Prerequisites

        # Clonar o actualizar repositorio
        Write-Log "Preparando repositorio..."
        if (Test-Path $SETUP_DIR) {
            try {
                Push-Location $SETUP_DIR
                try {
                    git reset --hard HEAD *>$null
                    git clean -fd *>$null
                    git pull *>$null
                }
                finally {
                    Pop-Location
                }
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
            Write-Error "❌ Error clonando repositorio" -ErrorAction Stop
        }

        # Establecer variables de entorno para los scripts
        $env:SETUP_LANG = $Lang
        $env:DEVCLI_PROFILE = $Profile
        $env:SETUP_DIR = $SETUP_DIR
        $env:CURRENT_USER = $CURRENT_USER
        # Pasar el directorio original a los scripts hijos
        $env:ORIGINAL_DIRECTORY = $script:OriginalDirectory

        # Ejecutar scripts de instalación
        $installDir = "$SETUP_DIR\install"
        Push-Location $installDir

        try {
            Write-Log "Ejecutando scripts de instalación desde: $installDir"
            $scripts = Get-ChildItem "*.ps1" | Where-Object { $_.Name -match '^\d{2}-.*\.ps1$' } | Sort-Object Name

            foreach ($script in $scripts) {
                Write-Log "▶ Ejecutando $($script.Name)..."
                try {
                    & $script.FullName
                    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                        throw "El script $($script.Name) terminó con código de error: $LASTEXITCODE"
                    }
                }
                catch {
                    Write-Error "❌ Error ejecutando $($script.Name): $($_.Exception.Message)" -ErrorAction Stop
                }
            }
        }
        finally {
            Pop-Location
        }

        # Marcar que ya no necesitamos restaurar el directorio automáticamente
        $script:ShouldRestoreDirectory = $false

        Write-Log "✅ Instalación completada"
        Write-Host ""
        Write-Host "🎉 ¡Configuración completada! Reinicia tu terminal para aplicar los cambios." -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Error durante la instalación: $($_.Exception.Message)"
        exit 1
    }
    finally {
        # Restaurar directorio original si es necesario
        if ($script:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

# Ejecutar función principal con manejo robusto
try {
    main
}
catch {
    Write-Error "❌ Error crítico: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}