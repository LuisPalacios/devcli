#Requires -Version 7.0

# Script de instalación de dotfiles para Windows
# Lee configuración desde 03-dotfiles-win.json

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
        Write-Log "Iniciando instalación de dotfiles..."
        Write-Log "Usuario: $env:USERNAME | Idioma: $Global:LOCALE"
        Write-Log "Directorio original: $Global:OriginalDirectory"

        # Directorio de dotfiles
        $dotfilesDir = Join-Path $Global:SETUP_DIR "dotfiles"

        if (-not (Test-Path $dotfilesDir)) {
            Write-Log "Directorio de dotfiles no encontrado: $dotfilesDir" "ERROR"
            exit 1
        }

        # Archivo de configuración
        $dotfilesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\03-dotfiles-win.json"

        # Leer dotfiles desde JSON usando función común
        $dotfiles = Get-ConfigFromJson -JsonPath $dotfilesConfig -PropertyName "dotfiles"

        if ($dotfiles.Count -eq 0) {
            Write-Log "No hay dotfiles para instalar"
            return
        }

        $installedCount = 0
        $failedCount = 0

        Write-Log "Copiando dotfiles según configuración..."
        foreach ($dotfile in $dotfiles) {
            if (-not $dotfile.file) {
                Write-Log "Dotfile con configuración incompleta omitido" "WARNING"
                $failedCount++
                continue
            }

            $src = Join-Path $dotfilesDir $dotfile.file

            # Construir ruta de destino (dst ahora incluye el nombre del archivo)
            if (-not $dotfile.dst) {
                Write-Log "Dotfile sin ruta destino especificada: $($dotfile.file)" "WARNING"
                $failedCount++
                continue
            }

            # Normalizar la ruta destino
            $dstRelative = $dotfile.dst.Replace('\\', [System.IO.Path]::DirectorySeparatorChar)

            # Si empieza con .\ o ./, quitarlo ya que es relativo al HOME
            if ($dstRelative.StartsWith(".\") -or $dstRelative.StartsWith("./")) {
                $dstRelative = $dstRelative.Substring(2)
            }

            # Construir ruta completa al archivo destino
            $dst = Join-Path $env:USERPROFILE $dstRelative

            # Extraer directorio padre para crear la estructura de directorios
            $dstDir = Split-Path $dst -Parent

            if (-not (Test-Path $src)) {
                Write-Log "Archivo fuente no encontrado: $src" "WARNING"
                $failedCount++
                continue
            }

            try {
                # Crear directorio de destino si no existe
                if (-not (Test-Path $dstDir)) {
                    New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
                    Write-Log "Directorio creado: $dstDir"
                }

                # Copiar archivo
                Copy-Item $src $dst -Force
                Write-Log "✅ Copiado: $($dotfile.file) → $dstRelative" "SUCCESS"
                $installedCount++
            }
            catch {
                Write-Log "Error copiando $($dotfile.file): $($_.Exception.Message)" "WARNING"
                $failedCount++
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
            if ($failedCount -gt 0) {
                Write-Log "$failedCount archivos fallaron en la copia" "WARNING"
            }
        }
        else {
            Write-Log "No se instalaron dotfiles nuevos"
        }

        # Verificar archivos críticos instalados
        $criticalFiles = @(".luispa.omp.json")
        $missingFiles = @()

        foreach ($file in $criticalFiles) {
            $filePath = Join-Path $env:USERPROFILE $file
            if (-not (Test-Path $filePath)) {
                $missingFiles += $file
            }
        }

        if ($missingFiles.Count -gt 0) {
            Write-Log "❌ Archivos críticos no disponibles: $($missingFiles -join ', ')" "WARNING"
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
