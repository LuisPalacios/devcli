#Requires -Version 7.0

# Script de configuración base del sistema para Windows
# Instala herramientas esenciales: jq, git, oh-my-posh

[CmdletBinding()]
param()

Write-Host "WiP system"
exit 0

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler
    
    try {
        Write-Log "Iniciando configuración base del sistema..."
        Write-Log "Usuario: $Global:CURRENT_USER | Idioma: $Global:SETUP_LANG"
        Write-Log "Directorio original: $Global:OriginalDirectory"

        # Crear directorio de binarios del usuario
        if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
            Write-Log "Error creando directorio de binarios" "ERROR"
            exit 1
        }

        # Actualizar PATH para incluir ~/bin
        Update-UserPath $Global:BIN_DIR

        # Paquetes esenciales obligatorios
        $essentialPackages = @(
            @{ Id = "jqlang.jq"; Name = "jq" },
            @{ Id = "Git.Git"; Name = "git" },
            @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "oh-my-posh" }
        )

        $installedCount = 0
        $failedCount = 0

        Write-Log "Instalando paquetes base..."
        foreach ($package in $essentialPackages) {
            if (Install-WingetPackage -PackageId $package.Id -Name $package.Name) {
                $installedCount++
            }
            else {
                $failedCount++
            }
        }

        # Refrescar PATH para que los comandos recién instalados estén disponibles
        Update-SessionPath

        # Verificar instalaciones críticas
        $criticalTools = @("jq", "git", "oh-my-posh")
        $missingCritical = @()

        foreach ($tool in $criticalTools) {
            if (-not (Test-Command $tool)) {
                $missingCritical += $tool
            }
        }

        if ($missingCritical.Count -gt 0) {
            Write-Log "❌ Herramientas críticas no disponibles: $($missingCritical -join ', ')" "ERROR"
            Write-Log "Intenta ejecutar de nuevo después de reiniciar el terminal" "WARNING"
        }

        # Configurar oh-my-posh en el perfil de PowerShell
        $profilePath = $PROFILE
        if ($profilePath -and (Test-Command oh-my-posh)) {
            try {
                $profileDir = Split-Path $profilePath -Parent
                if (-not (Test-Path $profileDir)) {
                    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
                }

                $ompConfigPath = "$env:USERPROFILE\.luispa.omp.json"
                $initLine = "oh-my-posh init pwsh --config `"$ompConfigPath`" | Invoke-Expression"

                if (Test-Path $profilePath) {
                    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
                    if ($profileContent -notlike "*oh-my-posh*") {
                        Add-Content -Path $profilePath -Value "`n# Oh My Posh Configuration`n$initLine" -Encoding UTF8
                        Write-Log "Oh-My-Posh añadido al perfil de PowerShell" "SUCCESS"
                    }
                    else {
                        Write-Log "Oh-My-Posh ya está configurado en el perfil"
                    }
                }
                else {
                    Set-Content -Path $profilePath -Value "# PowerShell Profile`n`n# Oh My Posh Configuration`n$initLine" -Encoding UTF8
                    Write-Log "Perfil de PowerShell creado con Oh-My-Posh" "SUCCESS"
                }
            }
            catch {
                Write-Log "Error configurando Oh-My-Posh en el perfil: $($_.Exception.Message)" "WARNING"
            }
        }

        # Mostrar resumen final
        if ($installedCount -gt 0) {
            Write-Log "✅ Configuración base completada ($installedCount paquetes verificados)" "SUCCESS"
            if ($failedCount -gt 0) {
                Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
            }
        }
        else {
            Write-Log "No se instalaron nuevos paquetes"
        }

        if ($missingCritical.Count -eq 0) {
            Write-Log "✅ Todas las herramientas críticas están disponibles" "SUCCESS"
        }

        # Marcar que ya no necesitamos restaurar el directorio
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
