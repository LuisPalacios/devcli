#Requires -Version 7.0

# Script de instalación de herramientas locales para Windows
# Lee configuración desde 05-localtools.json

[CmdletBinding()]
param()

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

Run-Phase {
    Write-Log "Instalando herramientas locales..."

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

    # Archivo de configuración (compartido, con filtro por plataforma)
    $localToolsConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\05-localtools.json"

    # Leer herramientas desde JSON usando función común
    $allTools = Get-ConfigFromJson -JsonPath $localToolsConfig -PropertyName "tools"

    if (-not $allTools -or $allTools.Count -eq 0) {
        Write-Log "No hay herramientas para instalar"
        return
    }

    # Filtrar por plataforma Windows
    $tools = $allTools | Where-Object {
        $_.platforms -contains "windows"
    }

    if ($tools.Count -eq 0) {
        Write-Log "No hay herramientas para Windows"
        return
    }

    $toolsInstalled = 0

    foreach ($tool in $tools) {
        $toolName = $tool.name
        if (-not $toolName) { continue }

        $src = Join-Path $Global:FILES_DIR $toolName
        $dst = Join-Path $Global:BIN_DIR $toolName

        if (Test-Path $src) {
            try {
                Copy-Item $src $dst -Force

                # Actualizar variables de Nerd Fonts en scripts específicos
                if ($toolName -eq "nerd-setup.ps1" -or $toolName -eq "nerd-verify.ps1") {
                    Update-NerdFontVariables $dst | Out-Null
                }
                $toolsInstalled++
            }
            catch {
                Write-Log "Error copiando $toolName`: $($_.Exception.Message)" "WARNING"
            }
        }
        else {
            Write-Log "Herramienta no encontrada: $toolName" "WARNING"
        }
    }

    # Mostrar resumen final
    if ($toolsInstalled -gt 0) {
        Write-Log "✅ Herramientas locales instaladas ($toolsInstalled herramientas)" "SUCCESS"
    }
    else {
        Write-Log "No se instalaron herramientas locales"
    }
}
