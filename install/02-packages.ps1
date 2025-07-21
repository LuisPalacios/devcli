#Requires -Version 7.0

# Script de instalación de herramientas de productividad para Windows
# Lee configuración desde 02-packages-win.json y usa Scoop

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función para instalar Nerd Fonts usando Scoop
function Install-NerdFonts {
    Write-Log "Instalando FiraCode Nerd Font con Scoop..."

    try {
        # Verificar que Scoop esté disponible
        if (-not (Test-Scoop)) {
            Write-Log "Scoop no está disponible para instalar fuentes" "WARNING"
            return $true  # No es un error crítico, continúa
        }

        # Verificar buckets existentes de manera más robusta
        $hasBucket = $false
        try {
            $buckets = & scoop bucket list 2>$null | Where-Object { $_ -match "nerd-fonts" }
            if ($buckets) {
                $hasBucket = $true
                Write-Log "Bucket nerd-fonts ya está disponible"
            }
        }
        catch {
            Write-Log "Error verificando buckets, intentando añadir nerd-fonts..." "WARNING"
        }

        # Añadir bucket de nerd-fonts si no está agregado
        if (-not $hasBucket) {
            Write-Log "Añadiendo bucket nerd-fonts..."
            try {
                & scoop bucket add nerd-fonts https://github.com/matthewjberger/scoop-nerd-fonts 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Bucket nerd-fonts añadido correctamente"
                }
                else {
                    Write-Log "Error añadiendo bucket nerd-fonts (código: $LASTEXITCODE)" "WARNING"
                    return $true  # No es crítico, continúa
                }
            }
            catch {
                Write-Log "Excepción añadiendo bucket: $($_.Exception.Message)" "WARNING"
                return $true  # No es crítico, continúa
            }
        }

        # Verificar si FiraCode-NF ya está instalado
        if (Test-ScoopPackage -PackageName "FiraCode-NF") {
            Write-Log "FiraCode Nerd Font ya está instalada"
            return $true
        }

        # Instalar FiraCode Nerd Font
        Write-Log "Instalando FiraCode-NF con scoop..."
        if (Install-ScoopPackage -PackageName "FiraCode-NF") {
            Write-Log "✅ FiraCode Nerd Font instalada correctamente" "SUCCESS"
            Write-Log "⚠️  IMPORTANTE: Reinicia tu terminal/editor para usar las nuevas fuentes" "WARNING"
            return $true
        }
        else {
            Write-Log "No se pudo instalar FiraCode-NF, pero continuando..." "WARNING"
            return $true  # No es crítico, continúa
        }
    }
    catch {
        Write-Log "Error instalando Nerd Fonts: $($_.Exception.Message)" "WARNING"
        return $true  # No es crítico, continúa
    }
}

# Función para configurar CLINK automáticamente
function Configure-Clink {
    Write-Log "Configurando CLINK para CMD..."

    try {
        # Verificar si CLINK está instalado
        if (-not (Test-ScoopPackage -PackageName "clink")) {
            Write-Log "CLINK no está instalado, omitiendo configuración" "WARNING"
            return $false
        }

        # Obtener la ruta de CLINK instalado con Scoop
        $clinkPath = Get-Command "clink" -ErrorAction SilentlyContinue
        if (-not $clinkPath) {
            Write-Log "No se pudo encontrar el ejecutable de CLINK" "WARNING"
            return $false
        }

        $clinkDir = Split-Path $clinkPath.Source -Parent
        $clinkBat = Join-Path $clinkDir "clink.bat"

        # Verificar que existe clink.bat
        if (-not (Test-Path $clinkBat)) {
            Write-Log "No se encontró clink.bat en: $clinkBat" "WARNING"
            return $false
        }

        # Configurar AutoRun en el registro para inyectar CLINK automáticamente en CMD
        $registryPath = "HKCU:\Software\Microsoft\Command Processor"
        $autoRunValue = "`"$clinkBat`" inject --autorun"

        try {
            # Verificar si ya está configurado
            $currentAutoRun = Get-ItemProperty -Path $registryPath -Name "AutoRun" -ErrorAction SilentlyContinue

            if ($currentAutoRun -and $currentAutoRun.AutoRun -like "*clink*") {
                Write-Log "CLINK ya está configurado en AutoRun del CMD"
            }
            else {
                # Configurar AutoRun para inyectar CLINK
                Set-ItemProperty -Path $registryPath -Name "AutoRun" -Value $autoRunValue -Force
                Write-Log "✅ CLINK configurado para inyección automática en CMD" "SUCCESS"
            }
        }
        catch {
            Write-Log "Error configurando AutoRun del registro: $($_.Exception.Message)" "WARNING"
            return $false
        }

        # Configurar CLINK para usar Oh-My-Posh
        # NOTA: Estos comandos requieren que CLINK esté ya inyectado en una sesión de CMD
        # Se ejecutarán en el siguiente inicio de CMD
        try {
            # Crear script de configuración inicial que se ejecutará en CMD
            $configScript = @"
@echo off
echo Configurando CLINK con Oh-My-Posh...
clink config prompt use oh-my-posh >nul 2>&1
clink set ohmyposh.theme %USERPROFILE%\.oh-my-posh.yaml >nul 2>&1
echo CLINK configurado correctamente.
"@

            $configPath = Join-Path $env:TEMP "configure-clink.bat"
            Set-Content -Path $configPath -Value $configScript -Encoding ASCII

            Write-Log "Script de configuración creado en: $configPath"
            Write-Log "⚠️  IMPORTANTE: Abre CMD y ejecuta: $configPath" "WARNING"
            Write-Log "   O ejecuta manualmente en CMD:" "WARNING"
            Write-Log "   clink config prompt use oh-my-posh" "WARNING"
            Write-Log "   clink set ohmyposh.theme %USERPROFILE%\.oh-my-posh.yaml" "WARNING"
        }
        catch {
            Write-Log "Error creando script de configuración: $($_.Exception.Message)" "WARNING"
        }

        return $true
    }
    catch {
        Write-Log "Error configurando CLINK: $($_.Exception.Message)" "WARNING"
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
        Write-Log "Usuario: $env:USERNAME | Idioma: $Global:LOCALE"
        Write-Log "Directorio original: $Global:OriginalDirectory"

        # Verificar que Scoop esté disponible
        if (-not (Test-Scoop)) {
            Write-Log "Scoop no está disponible. Ejecutando diagnóstico..." "WARNING"
            Test-ScoopDiagnostic
            Write-Log "Abortando: Scoop es requerido para instalar herramientas" "ERROR"
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
        $scoopPackages = @()

        # Separar paquetes para Scoop
        foreach ($package in $packages) {
            if ($package.name) {
                $scoopPackages += $package.name
            }
            else {
                Write-Log "Paquete con configuración incompleta omitido" "WARNING"
                $failedCount++
            }
        }

        # Instalar paquetes con Scoop
        if ($scoopPackages.Count -gt 0) {
            Write-Log "Instalando herramientas de productividad con scoop..."

            foreach ($packageName in $scoopPackages) {
                if (Install-ScoopPackage -PackageName $packageName) {
                    $installedCount++
                }
                else {
                    $failedCount++
                }
            }
        }

        # Instalar Nerd Fonts si lsd está en la lista
        $hasLsd = $scoopPackages -contains "lsd"
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

        # Configurar CLINK si está instalado
        $clinkConfigured = $false
        if ($scoopPackages -contains "clink") {
            $clinkConfigured = Configure-Clink
        }

        # Verificar herramientas críticas instaladas
        $criticalTools = @("lsd", "fzf", "fd", "ripgrep", "clink")
        $missingTools = @()

        foreach ($tool in $criticalTools) {
            if (-not (Test-ScoopPackage -PackageName $tool)) {
                $missingTools += $tool
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
            if ($clinkConfigured) {
                Write-Log "✅ CLINK configurado para CMD" "SUCCESS"
            }
        }
        else {
            Write-Log "No se instalaron nuevos paquetes"
        }

        if ($missingTools.Count -gt 0) {
            Write-Log "❌ Herramientas críticas no disponibles: $($missingTools -join ', ')" "WARNING"
            Write-Log "Intenta ejecutar de nuevo después de reiniciar el terminal" "WARNING"
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
