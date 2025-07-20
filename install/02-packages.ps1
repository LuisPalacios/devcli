#Requires -Version 7.0

# Script de instalación de herramientas de productividad para Windows
# Lee configuración desde 02-packages-win.json

[CmdletBinding()]
param()

Write-Host "WiP packages"
exit 0

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función para instalar Nerd Fonts
function Install-NerdFonts {
    Write-Log "Instalando FiraCode Nerd Font..."
    
    try {
        $fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        if (-not (Test-Path $fontsDir)) {
            New-Item -Path $fontsDir -ItemType Directory -Force | Out-Null
        }

        $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
        $tempZip = "$env:TEMP\FiraCode.zip"
        $tempDir = "$env:TEMP\FiraCode-NerdFont"

        Write-Log "Descargando FiraCode Nerd Font..."
        Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip -UseBasicParsing

        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

        $fontFiles = Get-ChildItem "$tempDir\*.ttf" -ErrorAction SilentlyContinue
        $installedFonts = 0

        foreach ($fontFile in $fontFiles) {
            $destPath = Join-Path $fontsDir $fontFile.Name
            if (-not (Test-Path $destPath)) {
                Copy-Item $fontFile.FullName $destPath -Force
                $installedFonts++
            }
        }

        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        if ($installedFonts -gt 0) {
            Write-Log "✅ FiraCode Nerd Font instalada ($installedFonts archivos)" "SUCCESS"
            return $true
        }
        else {
            Write-Log "FiraCode Nerd Font ya estaba instalada"
            return $true
        }
    }
    catch {
        Write-Log "Error instalando Nerd Fonts: $($_.Exception.Message)" "WARNING"
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
        Write-Log "Iniciando instalación de herramientas de productividad..."
        Write-Log "Directorio original: $Global:OriginalDirectory"

        # Verificar que jq esté disponible
        if (-not (Test-Jq)) {
            Write-Log "Abortando: jq es requerido para procesar la configuración" "ERROR"
            exit 1
        }

        # Archivo de configuración
        $packagesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\02-packages-win.json"
        
        # Leer paquetes desde JSON usando función común
        $packages = Get-ConfigFromJson -JsonPath $packagesConfig -PropertyName "packages"

        if ($packages.Count -eq 0) {
            Write-Log "No hay paquetes para instalar"
            return
        }

        $installedCount = 0
        $failedCount = 0

        Write-Log "Instalando herramientas de productividad..."
        foreach ($package in $packages) {
            if ($package.id -and $package.name) {
                if (Install-WingetPackage -PackageId $package.id -Name $package.name -Description $package.description) {
                    $installedCount++
                }
                else {
                    $failedCount++
                }
            }
            else {
                Write-Log "Paquete con configuración incompleta omitido" "WARNING"
                $failedCount++
            }
        }

        # Instalar Nerd Fonts si lsd está en la lista
        $hasLsd = $packages | Where-Object { $_.id -eq "lsd-rs.lsd" }
        if ($hasLsd) {
            Install-NerdFonts | Out-Null
        }

        # Refrescar PATH
        Update-SessionPath

        # Crear alias para herramientas si es necesario
        $aliasesCreated = 0

        # Crear alias para btm -> htop si bottom está instalado
        if ((Test-Command "btm") -and (-not (Test-Command "htop"))) {
            try {
                $aliasScript = @"
@echo off
btm %*
"@
                $htopPath = Join-Path $Global:BIN_DIR "htop.cmd"
                Set-Content -Path $htopPath -Value $aliasScript -Encoding ASCII
                Write-Log "Alias htop -> btm creado" "SUCCESS"
                $aliasesCreated++
            }
            catch {
                Write-Log "Error creando alias htop: $($_.Exception.Message)" "WARNING"
            }
        }

        # Mostrar resumen final
        if ($installedCount -gt 0) {
            Write-Log "✅ Herramientas de productividad instaladas ($installedCount paquetes)" "SUCCESS"
            if ($failedCount -gt 0) {
                Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
            }
            if ($aliasesCreated -gt 0) {
                Write-Log "$aliasesCreated alias creados" "SUCCESS"
            }
        }
        else {
            Write-Log "No se instalaron nuevos paquetes"
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
