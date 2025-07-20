#Requires -Version 7.0

# Script de configuración base del sistema para Windows
# Instala herramientas esenciales: jq, git, oh-my-posh

[CmdletBinding()]
param()

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

        # Paquetes con scoop
        $scoopPackages = @("jq", "oh-my-posh")

        # Paquetes con winget (git ya se instala en bootstrap.ps1)
        $wingetPackages = @()

        $installedCount = 0
        $failedCount = 0

        # Instalar paquetes con scoop
        if ($scoopPackages.Count -gt 0) {
            Write-Log "Instalando paquetes base con scoop..."

            # Verificar que scoop funciona antes de intentar instalar
            if (-not (Test-Scoop)) {
                Write-Log "Scoop no está funcionando correctamente. Ejecutando diagnóstico..." "WARNING"
                Test-ScoopDiagnostic
                Write-Log "Abortando instalación con scoop" "ERROR"
                $failedCount += $scoopPackages.Count
            }
            else {
                foreach ($package in $scoopPackages) {
                    if (Install-ScoopPackage -PackageName $package) {
                        $installedCount++
                    }
                    else {
                        $failedCount++
                    }
                }
            }
        }

        # Instalar paquetes con winget
        if ($wingetPackages.Count -gt 0) {
            Write-Log "Instalando paquetes base con winget..."
            foreach ($package in $wingetPackages) {
                if (Install-WingetPackage -PackageId $package.Id -Name $package.Name) {
                    $installedCount++
                }
                else {
                    $failedCount++
                }
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
