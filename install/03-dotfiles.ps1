#Requires -Version 7.0

# Script de instalación de dotfiles para Windows
# Copia .luispa.omp.json al home del usuario

[CmdletBinding()]
param()

Write-Host "WiP dotfiles"
exit 0

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función para personalizar archivo de configuración
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
        Write-Log "Error personalizando configuración: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Función para configurar oh-my-posh en PowerShell
function Set-OhMyPoshProfile {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Archivo de configuración no encontrado: $ConfigPath" "WARNING"
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
            Write-Log "Directorio de perfil creado: $profileDir"
        }
        
        $ompLine = "oh-my-posh init pwsh --config `"$ConfigPath`" | Invoke-Expression"
        
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($profileContent -and $profileContent -notlike "*oh-my-posh*") {
                Add-Content -Path $profilePath -Value "`n# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
                Write-Log "Oh-My-Posh añadido al perfil existente" "SUCCESS"
            }
            else {
                Write-Log "Oh-My-Posh ya está configurado en el perfil"
            }
        }
        else {
            Set-Content -Path $profilePath -Value "# PowerShell Profile`n`n# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
            Write-Log "Perfil de PowerShell creado con Oh-My-Posh" "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Error configurando perfil: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler

    try {
        Write-Log "Iniciando instalación de dotfiles..."

        # Directorio de dotfiles
        $dotfilesDir = Join-Path $Global:SETUP_DIR "dotfiles"
        
        if (-not (Test-Path $dotfilesDir)) {
            Write-Log "Directorio de dotfiles no encontrado: $dotfilesDir" "ERROR"
            exit 1
        }

        # Lista de dotfiles a instalar (solo para Windows)
        $dotfilesList = @(".luispa.omp.json")
        $installedCount = 0

        Write-Log "Instalando dotfiles..."
        foreach ($file in $dotfilesList) {
            $src = Join-Path $dotfilesDir $file
            $dst = Join-Path $env:USERPROFILE $file

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
                Write-Log "Error copiando $file`: $($_.Exception.Message)" "WARNING"
            }
        }

        # Configurar variables de entorno específicas para Windows Terminal
        try {
            [Environment]::SetEnvironmentVariable("OMP_OS_ICON", "🪟", "User")
            Write-Log "Variable de entorno OMP_OS_ICON configurada"
        }
        catch {
            Write-Log "Error configurando variables de entorno: $($_.Exception.Message)" "WARNING"
        }

        # Mostrar resumen final
        if ($installedCount -gt 0) {
            Write-Log "✅ Dotfiles instalados ($installedCount archivos)" "SUCCESS"
        }
        else {
            Write-Log "No se instalaron dotfiles"
        }

        $Global:ShouldRestoreDirectory = $false
    }
    finally {
        if ($Global:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

# Ejecutar función principal con manejo robusto
try {
    main
}
catch {
    Write-Error "❌ Error crítico en script: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}
