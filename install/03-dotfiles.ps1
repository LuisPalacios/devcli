#Requires -Version 7.0

Write-Host "WiP dotfiles"
exit 0

# Script de instalación de dotfiles para Windows
# Copia .luispa.omp.json al home del usuario

[CmdletBinding()]
param()

# Variables de entorno (definidas por bootstrap.ps1)
$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$TARGET_HOME = $env:USERPROFILE

# Manejo de directorio original (heredado del bootstrap)
$script:OriginalDirectory = $env:ORIGINAL_DIRECTORY ?? $PWD.Path
$script:ShouldRestoreDirectory = $true

# Función de log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[03-dotfiles] $Message" -ForegroundColor $color
}

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

function Handle-ScriptInterruption {
    Write-Host "`n❌ Script interrumpido por el usuario" -ForegroundColor Red
    Restore-OriginalDirectory
    exit 130
}

function Setup-ScriptInterruptionHandler {
    try {
        # Solo CancelKeyPress - suficiente para scripts hijos
        [Console]::CancelKeyPress += {
            param($sender, $e)
            $e.Cancel = $true
            Handle-ScriptInterruption
        }
    }
    catch {
        Write-Warning "No se pudo configurar el manejador de interrupciones: $_"
    }
}

function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Update-OmpConfig {
    param([string]$ConfigFile)

    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Archivo de configuración no encontrado: $ConfigFile" "WARNING"
        return $false
    }

    try {
        $content = Get-Content $ConfigFile -Raw -Encoding UTF8NoBOM
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupFile = "$ConfigFile.backup.$timestamp"
        Copy-Item $ConfigFile $backupFile -Force

        Write-Log "Configuración Oh-My-Posh personalizada para Windows"
        Write-Log "Backup creado: $backupFile"

        return $true
    }
    catch {
        Write-Log "Error personalizando configuración: $_" "WARNING"
        return $false
    }
}

function Set-OhMyPoshProfile {
    param([string]$ConfigPath)

    if (-not (Test-Command "oh-my-posh")) {
        Write-Log "oh-my-posh no está disponible" "WARNING"
        return $false
    }

    $profilePath = $PROFILE
    if (-not $profilePath) {
        Write-Log "No se puede determinar la ruta del perfil de PowerShell" "WARNING"
        return $false
    }

    try {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
            Write-Log "Directorio del perfil creado: $profileDir"
        }

        $ompLine = "oh-my-posh init pwsh --config `"$ConfigPath`" | Invoke-Expression"

        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($profileContent -and ($profileContent -match "oh-my-posh.*\.luispa\.omp\.json")) {
                Write-Log "Oh-My-Posh ya está configurado en el perfil"
                return $true
            }
        }

        if (Test-Path $profilePath) {
            Add-Content -Path $profilePath -Value "`n# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
        }
        else {
            Set-Content -Path $profilePath -Value "# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
        }

        Write-Log "Oh-My-Posh configurado en el perfil de PowerShell" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error configurando Oh-My-Posh en el perfil: $_" "WARNING"
        return $false
    }
}

function main {
    trap {
        Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler

    try {
        Write-Log "Iniciando instalación de dotfiles..."

        $dotfilesDir = Join-Path $SETUP_DIR "dotfiles"

        if (-not (Test-Path $dotfilesDir)) {
            Write-Log "Directorio de dotfiles no encontrado: $dotfilesDir" "ERROR"
            exit 1
        }

        $dotfilesList = @(".luispa.omp.json")
        $installedCount = 0

        Write-Log "Instalando dotfiles..."
        foreach ($file in $dotfilesList) {
            $src = Join-Path $dotfilesDir $file
            $dst = Join-Path $TARGET_HOME $file

            if (-not (Test-Path $src)) {
                Write-Log "Dotfile no encontrado: $src" "WARNING"
                continue
            }

            try {
                Copy-Item $src $dst -Force
                Write-Log "Copiado: $file"
                $installedCount++

                if ($file -eq ".luispa.omp.json") {
                    Update-OmpConfig $dst
                    Set-OhMyPoshProfile $dst
                }
            }
            catch {
                Write-Log "Error copiando $file`: $_" "WARNING"
            }
        }

        try {
            [Environment]::SetEnvironmentVariable("OMP_OS_ICON", "🪟", "User")
            Write-Log "Variable de entorno OMP_OS_ICON configurada"
        }
        catch {
            Write-Log "Error configurando variables de entorno: $_" "WARNING"
        }

        if ($installedCount -gt 0) {
            Write-Log "✅ Dotfiles instalados ($installedCount archivos)" "SUCCESS"
            Write-Log ""
            Write-Log "🎨 Configuración aplicada:" "SUCCESS"
            Write-Log "  • Oh-My-Posh configurado con tema personalizado"
            Write-Log "  • Perfil de PowerShell actualizado"
            Write-Log "  • Variables de entorno configuradas"
            Write-Log ""
            Write-Log "💡 Para aplicar los cambios:"
            Write-Log "  1. Reinicia tu terminal"
            Write-Log "  2. O ejecuta: . `$PROFILE"
        }
        else {
            Write-Log "No se instalaron dotfiles"
        }

        $script:ShouldRestoreDirectory = $false
    }
    finally {
        if ($script:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

try {
    main
}
catch {
    Write-Error "❌ Error crítico en script: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}
