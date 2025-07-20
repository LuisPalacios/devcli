#Requires -Version 7.0

# Script de instalación de herramientas locales para Windows
# Lee configuración desde 05-localtools-win.json

[CmdletBinding()]
param()

Write-Host "WiP localtools"
exit 0

$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$BIN_DIR = "$env:USERPROFILE\bin"

$script:OriginalDirectory = $env:ORIGINAL_DIRECTORY ?? $PWD.Path
$script:ShouldRestoreDirectory = $true

$NERD_FONT_NAME = "FiraCode"
$NERD_FONT_FULL_NAME = "FiraCode Nerd Font"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[05-localtools] $Message" -ForegroundColor $color
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
        $null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action {
            $Event.Args[1].Cancel = $true
            Handle-ScriptInterruption
        }
    }
    catch {
        Write-Warning "No se pudo configurar el manejador de interrupciones: $_"
    }
}

function New-DirectoryIfNotExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            return $true
        }
        catch {
            Write-Log "Error creando directorio $Path`: $_" "ERROR"
            return $false
        }
    }
    return $true
}

function Get-ToolsFromJson {
    param([string]$JsonPath)

    if (-not (Test-Path $JsonPath)) {
        Write-Log "Archivo de configuración no encontrado: $JsonPath" "ERROR"
        return @()
    }

    try {
        $jsonContent = Get-Content $JsonPath -Raw -Encoding UTF8
        $config = $jsonContent | ConvertFrom-Json

        if (-not $config.tools) {
            Write-Log "No se encontró sección 'tools' en el JSON" "WARNING"
            return @()
        }

        return $config.tools
    }
    catch {
        Write-Log "Error leyendo configuración JSON: $_" "ERROR"
        return @()
    }
}

function Update-NerdFontVariables {
    param([string]$ScriptFile)

    if (-not (Test-Path $ScriptFile)) {
        return
    }

    try {
        $content = Get-Content $ScriptFile -Raw -Encoding UTF8
        $content = $content -replace '\$NERD_FONT_NAME = "[^"]*"', "`$NERD_FONT_NAME = `"$NERD_FONT_NAME`""
        $content = $content -replace '\$NERD_FONT_FULL_NAME = "[^"]*"', "`$NERD_FONT_FULL_NAME = `"$NERD_FONT_FULL_NAME`""
        Set-Content -Path $ScriptFile -Value $content -Encoding UTF8
        Write-Log "Variables de Nerd Fonts actualizadas en $(Split-Path $ScriptFile -Leaf)"
    }
    catch {
        Write-Log "Error actualizando variables en $ScriptFile`: $_" "WARNING"
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
        Write-Log "Iniciando instalación de herramientas locales..."

        if (-not (New-DirectoryIfNotExists $BIN_DIR)) {
            Write-Log "Error creando directorio de binarios" "ERROR"
            exit 1
        }

        $filesDir = Join-Path $SETUP_DIR "files\bin"

        if (-not (Test-Path $filesDir)) {
            Write-Log "Directorio de archivos no encontrado: $filesDir" "ERROR"
            exit 1
        }

        $localToolsConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\05-localtools-win.json"
        $tools = Get-ToolsFromJson $localToolsConfig

        if ($tools.Count -eq 0) {
            Write-Log "No hay herramientas para instalar"
            return
        }

        $toolsInstalled = 0

        Write-Log "Instalando herramientas locales..."
        foreach ($tool in $tools) {
            $src = Join-Path $filesDir $tool
            $dst = Join-Path $BIN_DIR $tool

            if (Test-Path $src) {
                try {
                    Copy-Item $src $dst -Force

                    if ($tool -eq "nerd-setup.ps1" -or $tool -eq "nerd-verify.ps1") {
                        Update-NerdFontVariables $dst
                    }

                    Write-Log "Copiado: $tool"
                    $toolsInstalled++
                }
                catch {
                    Write-Log "Error copiando $tool`: $_" "WARNING"
                }
            }
            else {
                Write-Log "Herramienta no encontrada: $tool" "WARNING"
            }
        }

        if ($toolsInstalled -gt 0) {
            Write-Log "✅ Herramientas locales instaladas ($toolsInstalled herramientas)" "SUCCESS"
            Write-Log ""
            Write-Log "🛠️ Herramientas disponibles en ~/bin:" "SUCCESS"
            $tools | ForEach-Object {
                $toolPath = Join-Path $BIN_DIR $_
                if (Test-Path $toolPath) {
                    Write-Log "  • $_" "SUCCESS"
                }
            }

            Write-Log ""
            Write-Log "💡 Para usar las herramientas:"
            Write-Log "  • nerd-setup.ps1 auto    - Configurar fuente automáticamente"
            Write-Log "  • nerd-verify.ps1        - Verificar instalación de fuentes"
        }
        else {
            Write-Log "No se instalaron herramientas locales"
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
