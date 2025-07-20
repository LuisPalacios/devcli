#Requires -Version 7.0

# Script de instalación de herramientas locales para Windows
# Lee configuración desde 05-localtools-win.json

[CmdletBinding()]
param()

# Variables de entorno (definidas por bootstrap.ps1)
$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.cli-setup"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$BIN_DIR = "$env:USERPROFILE\bin"

# Configuración de Nerd Fonts para Windows
$NERD_FONT_NAME = "FiraCode"
$NERD_FONT_FULL_NAME = "FiraCode Nerd Font"

# Función de log
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

# Función para crear directorio si no existe
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

# Función para leer herramientas desde JSON
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

# Función para actualizar variables de Nerd Fonts en scripts
function Update-NerdFontVariables {
    param([string]$ScriptFile)
    
    if (-not (Test-Path $ScriptFile)) {
        return
    }
    
    try {
        $content = Get-Content $ScriptFile -Raw -Encoding UTF8
        
        # Reemplazar variables de Nerd Fonts
        $content = $content -replace '\$NERD_FONT_NAME = "[^"]*"', "`$NERD_FONT_NAME = `"$NERD_FONT_NAME`""
        $content = $content -replace '\$NERD_FONT_FULL_NAME = "[^"]*"', "`$NERD_FONT_FULL_NAME = `"$NERD_FONT_FULL_NAME`""
        
        Set-Content -Path $ScriptFile -Value $content -Encoding UTF8
        Write-Log "Variables de Nerd Fonts actualizadas en $(Split-Path $ScriptFile -Leaf)"
    }
    catch {
        Write-Log "Error actualizando variables en $ScriptFile`: $_" "WARNING"
    }
}

# Función principal
function main {
    Write-Log "Iniciando instalación de herramientas locales..."
    
    # Asegurar que existe el directorio de binarios
    if (-not (New-DirectoryIfNotExists $BIN_DIR)) {
        Write-Log "Error creando directorio de binarios" "ERROR"
        exit 1
    }
    
    # Directorio de archivos fuente
    $filesDir = Join-Path $SETUP_DIR "files\bin"
    
    if (-not (Test-Path $filesDir)) {
        Write-Log "Directorio de archivos no encontrado: $filesDir" "ERROR"
        exit 1
    }
    
    # Archivo de configuración
    $localToolsConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\05-localtools-win.json"
    
    # Leer herramientas desde JSON
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
                
                # Actualizar variables de Nerd Fonts en scripts específicos
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
    
    # Mostrar resumen final
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
}

# Ejecutar función principal
main 