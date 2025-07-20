#Requires -Version 7.0

# Script de instalación de herramientas locales para Windows
# Lee configuración desde 05-localtools-win.json

[CmdletBinding()]
param()

Write-Host "WiP localtools"
exit 0

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función para actualizar variables de Nerd Fonts en scripts
function Update-NerdFontVariables {
    param([string]$ScriptFile)

    if (-not (Test-Path $ScriptFile)) {
        Write-Log "Script no encontrado: $ScriptFile" "WARNING"
        return $false
    }

    try {
        $content = Get-Content $ScriptFile -Raw -Encoding UTF8
        $content = $content -replace '\$NERD_FONT_NAME = "[^"]*"', "`$NERD_FONT_NAME = `"$Global:NERD_FONT_NAME`""
        $content = $content -replace '\$NERD_FONT_FULL_NAME = "[^"]*"', "`$NERD_FONT_FULL_NAME = `"$Global:NERD_FONT_FULL_NAME`""

        Set-Content -Path $ScriptFile -Value $content -Encoding UTF8
        return $true
    }
    catch {
        Write-Log "Error actualizando variables de Nerd Fonts: $($_.Exception.Message)" "WARNING"
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
        Write-Log "Iniciando instalación de herramientas locales..."

        # Asegurar que existe el directorio de binarios
        if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
            Write-Log "Error creando directorio de binarios" "ERROR"
            exit 1
        }

        # Verificar que existe el directorio de archivos fuente
        if (-not (Test-Path $Global:FILES_DIR)) {
            Write-Log "Directorio de archivos fuente no encontrado: $Global:FILES_DIR" "ERROR"
            exit 1
        }

        # Archivo de configuración
        $localToolsConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\05-localtools-win.json"

        # Leer herramientas desde JSON usando función común
        $tools = Get-ConfigFromJson -JsonPath $localToolsConfig -PropertyName "tools"

        if ($tools.Count -eq 0) {
            Write-Log "No hay herramientas para instalar"
            return
        }

        $toolsInstalled = 0

        Write-Log "Instalando herramientas locales..."
        foreach ($tool in $tools) {
            if (-not $tool) { continue }

            $src = Join-Path $Global:FILES_DIR $tool
            $dst = Join-Path $Global:BIN_DIR $tool

            if (Test-Path $src) {
                try {
                    Copy-Item $src $dst -Force

                    # Actualizar variables de Nerd Fonts en scripts específicos
                    if ($tool -eq "nerd-setup.ps1" -or $tool -eq "nerd-verify.ps1") {
                        Update-NerdFontVariables $dst
                        Write-Log "Variables de Nerd Fonts actualizadas en $tool"
                    }

                    Write-Log "Copiado: $tool"
                    $toolsInstalled++
                }
                catch {
                    Write-Log "Error copiando $tool`: $($_.Exception.Message)" "WARNING"
                }
            }
            else {
                Write-Log "Herramienta no encontrada: $tool" "WARNING"
            }
        }

        # Mostrar resumen final
        if ($toolsInstalled -gt 0) {
            Write-Log "✅ Herramientas locales instaladas ($toolsInstalled herramientas)" "SUCCESS"
        }
        else {
            Write-Log "No se instalaron herramientas locales"
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
