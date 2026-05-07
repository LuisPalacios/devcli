#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Lang = "es-ES",

    [Parameter()]
    [ValidateSet("minimal", "dev", "full")]
    [string]$Profile = "full",

    [Parameter()]
    [switch]$Reclone,

    [Parameter()]
    [switch]$Help
)

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

# Variables básicas para bootstrap
$REPO_URL = "https://github.com/LuisPalacios/devcli.git"
$BRANCH = "main"
$CURRENT_USER = $env:USERNAME
$SETUP_DIR = "$env:USERPROFILE\.devcli"

# Guardar directorio original para restaurarlo en caso de interrupción
$script:OriginalDirectory = $PWD.Path

# Flag para controlar si debemos restaurar el directorio
$script:ShouldRestoreDirectory = $true

# Mensajes pre-banner (antes de que la capa UX esté disponible). Sin prefijo
# `[bootstrap]` — ese se sentía técnico. Sólo emite cuando hay algo que el
# usuario debe ver (instalación de prereqs, errores).
function Write-Log {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

# Clona el repo desde cero, borrando primero $SETUP_DIR si existiera.
# Usado por la lógica de sincronización (con -Reclone, o como fallback si fetch+reset falla).
function Invoke-FreshClone {
    if (Test-Path $SETUP_DIR) {
        Remove-Item $SETUP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
    git clone --branch $BRANCH $REPO_URL $SETUP_DIR *>$null
    if (-not (Test-Path $SETUP_DIR)) {
        Write-Error "❌ Error clonando repositorio" -ErrorAction Stop
    }
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

# Función de ayuda
function Show-Help {
    $helpText = @"
CLI Setup - Configuración automatizada de entorno CLI para Windows

Uso: Ejecutar desde PowerShell con política de ejecución apropiada

OPCIONES:
  -Lang LOCALE          Configurar idioma (ej: en-US, es-ES)
  -Profile PROFILE      Perfil de instalación: minimal, dev, full (defecto: full)
  -Reclone              Forzar descarga limpia del repo (borra ~/.devcli y vuelve a clonar)
  -Verbose              Mostrar todo el output bruto de las herramientas (scoop, winget, curl…)
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

# Comprobar que winget funciona de verdad (no solo que el .exe esté en el PATH).
# En W11 ARM o imágenes recién provisionadas el reparse point existe pero el
# AppExecutionAlias no, y winget devuelve "Acceso denegado" al invocarse.
function Test-WingetFunctional {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    try {
        $null = & winget --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Instala un prereq vía winget (silencioso, accept-agreements). Refresca PATH
# tras la instalación. Con -Critical, los fallos abortan; sin -Critical son
# warnings (la siguiente fase puede reintentarlo). -ManualHint añade contexto
# a los abort messages cuando winget no está operativo.
function Install-WingetPrereq {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$WingetOk,
        [string]$ManualHint = '',
        [switch]$Critical
    )
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return }

    if (-not $WingetOk) {
        if ($Critical) {
            $msg = "❌ $Name no está instalado y winget no está operativo."
            if ($ManualHint) { $msg += " $ManualHint" }
            Write-Error $msg -ErrorAction Stop
        }
        Write-Log "⚠️ $Name no está instalado y winget no está operativo — saltando. Se reintentará en 02-packages si procede."
        return
    }

    Write-Log "Instalando $Name con winget..."
    try {
        winget install $Id --silent --accept-package-agreements --accept-source-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        if (Get-Command $Name -ErrorAction SilentlyContinue) {
            Write-Log "✅ $Name instalado correctamente"
        } elseif ($Critical) {
            Write-Error "❌ No se pudo instalar $Name automáticamente" -ErrorAction Stop
        } else {
            Write-Log "⚠️ $Name no pudo instalarse — continuando (no es crítico para bootstrap)."
        }
    } catch {
        if ($Critical) {
            Write-Error "❌ Error instalando ${Name}: $_" -ErrorAction Stop
        }
        Write-Log "⚠️ Error instalando ${Name}: $_ — continuando (no es crítico para bootstrap)."
    }
}

# Verificar herramientas necesarias
function Test-Prerequisites {
    # Verificar winget de forma funcional
    $wingetOk = Test-WingetFunctional
    if (-not $wingetOk) {
        Write-Warning "⚠️ winget no está operativo en esta sesión."
        Write-Warning "   Causa típica: AppExecutionAlias roto o App Installer desactualizado (común en Windows 11 ARM recién aprovisionado)."
        Write-Warning "   Arreglos posibles:"
        Write-Warning "     1) Abrir Microsoft Store → buscar 'App Installer' → Actualizar."
        Write-Warning "     2) Settings → Apps → Advanced app settings → App execution aliases → activar 'App Installer (winget.exe)'."
        Write-Warning "     3) Settings → Apps → App Installer → Advanced options → Reset."
        Write-Warning "   El bootstrap continuará omitiendo los pasos que dependen de winget."
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
                Write-Log "✅ Scoop instalado correctamente"

                # Agregar bucket extras (silencioso si ya estaba)
                try {
                    $buckets = scoop bucket list | ForEach-Object { $_.Split()[0] }
                    if ('extras' -notin $buckets) {
                        scoop bucket add extras *>$null
                    }
                }
                catch {
                    Write-Warning "⚠️  Error al añadir el bucket extras: $_"
                }
            }
        }
        catch {
            Write-Error "❌ Error instalando scoop: $_" -ErrorAction Stop
        }
    }

    # Verificar y agregar bucket extras si scoop ya estaba instalado (silencioso si ya está)
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $hasBucketExtras = (scoop bucket list 2>$null) | Where-Object { $_.Name -eq "extras" }
        if (-not $hasBucketExtras) {
            try {
                scoop bucket add extras *>$null
            }
            catch {
                Write-Warning "⚠️  No se pudo añadir el bucket extras: $_"
            }
        }
    }

    # git: crítico (bootstrap no puede continuar sin él para clonar el repo).
    Install-WingetPrereq -Id 'Git.Git' -Name 'git' -WingetOk $wingetOk -Critical `
        -ManualHint 'Instala Git for Windows manualmente desde https://git-scm.com/download/win (o en ARM64: https://github.com/git-for-windows/git/releases) y vuelve a ejecutar el bootstrap.'

    # pnpm: no crítico (02-packages lo reintenta vía el handler scoop/winget).
    Install-WingetPrereq -Id 'pnpm.pnpm' -Name 'pnpm' -WingetOk $wingetOk
}

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada en bootstrap: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    try {
        $windowsInfo = Test-WindowsVersion
        $isAdmin = Test-Administrator

        # Verificar prerequisitos (silencioso si ya están instalados)
        Test-Prerequisites

        # Sincronizar repo. Por defecto: fetch + reset --hard (rápido, idempotente,
        # descarta ediciones locales como hacía la rama antigua de Remove-Item + clone).
        # Con -Reclone se fuerza el borrado y reclonado completo.
        if ($Reclone) {
            Write-Log "Descarga limpia solicitada (-Reclone)..."
            Invoke-FreshClone
        }
        elseif (Test-Path "$SETUP_DIR\.git") {
            git -C $SETUP_DIR fetch --quiet origin $BRANCH 2>$null
            $fetchOk = ($LASTEXITCODE -eq 0)
            if ($fetchOk) {
                git -C $SETUP_DIR reset --hard "origin/$BRANCH" --quiet 2>$null
            }
            if (-not $fetchOk -or $LASTEXITCODE -ne 0) {
                Write-Log "Actualización del repo falló — descargando desde cero..."
                Invoke-FreshClone
            }
        }
        else {
            Invoke-FreshClone
        }

        # Establecer variables de entorno para los scripts
        $env:SETUP_LANG = $Lang
        $env:DEVCLI_PROFILE = $Profile
        $env:SETUP_DIR = $SETUP_DIR
        $env:CURRENT_USER = $CURRENT_USER

        # Puente entre el -Verbose común de PS y la capa UX (lee $env:DEVCLI_VERBOSE).
        $env:DEVCLI_VERBOSE = if ($VerbosePreference -ne 'SilentlyContinue') { '1' } else { '0' }

        # Cargar la capa UX y arrancar la sesión visual.
        $installDir = "$SETUP_DIR\install"
        . "$installDir\utils.ps1"
        Initialize-Ux -LogFile (Join-Path $env:USERPROFILE '.devcli\install.log')
        Show-UxBanner -OS 'Windows 11' -Profile $Profile

        Push-Location $installDir
        try {
            $scripts = Get-ChildItem "*.ps1" | Where-Object { $_.Name -match '^\d{2}-.*\.ps1$' } | Sort-Object Name
            $env:PHASE_TOTAL = $scripts.Count

            $bsOk = 0; $bsWarn = 0; $bsFail = 0
            $phaseNum = 0
            foreach ($script in $scripts) {
                $phaseNum++
                $env:PHASE_NUM = $phaseNum
                & $script.FullName
                $rc = $LASTEXITCODE
                switch ($rc) {
                    0       { $bsOk++ }
                    1       { $bsWarn++ }
                    default { $bsFail++ }
                }
            }
        }
        finally {
            Pop-Location
        }

        # Marcar que ya no necesitamos restaurar el directorio automáticamente
        $script:ShouldRestoreDirectory = $false

        Show-UxSummary -PhasesOk $bsOk -PhasesWarn $bsWarn -PhasesFail $bsFail
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