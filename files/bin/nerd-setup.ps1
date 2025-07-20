#Requires -Version 5.1
# Script para configurar terminal con Nerd Fonts en Windows
# Uso: nerd-setup.ps1 [terminal]

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Terminal = ""
)

# Configuración de Nerd Fonts
$NERD_FONT_NAME = "FiraCode"
$NERD_FONT_FULL_NAME = "FiraCode Nerd Font"

# Función para mostrar ayuda
function Show-Help {
    $helpText = @"
Uso: nerd-setup.ps1 [TERMINAL]

Configura tu terminal para usar $NERD_FONT_FULL_NAME.

Terminales soportados:
  windows-terminal     Windows Terminal
  powershell          Windows PowerShell ISE
  cmd                 Command Prompt
  vscode              Visual Studio Code
  auto                Detectar automáticamente

Ejemplos:
  nerd-setup.ps1 windows-terminal
  nerd-setup.ps1 auto
"@
    Write-Host $helpText
}

# Función para verificar si las fuentes están instaladas
function Test-Fonts {
    Write-Host "🔍 Verificando instalación de fuentes..." -ForegroundColor Cyan
    
    $fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $systemFontsDir = "$env:WINDIR\Fonts"
    
    # Buscar archivos de fuente FiraCode
    $userFonts = Get-ChildItem -Path $fontsDir -Filter "*FiraCode*" -ErrorAction SilentlyContinue
    $systemFonts = Get-ChildItem -Path $systemFontsDir -Filter "*FiraCode*" -ErrorAction SilentlyContinue
    
    if ($userFonts.Count -gt 0 -or $systemFonts.Count -gt 0) {
        Write-Host "✓ $NERD_FONT_FULL_NAME encontrada" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ $NERD_FONT_FULL_NAME no encontrada" -ForegroundColor Red
        Write-Host "💡 Ejecuta 02-packages.ps1 o instala las fuentes manualmente" -ForegroundColor Yellow
        return $false
    }
}

# Función para detectar terminal automáticamente
function Get-Terminal {
    # Detectar por variables de entorno y proceso padre
    if ($env:WT_SESSION) {
        return "windows-terminal"
    }
    elseif ($env:TERM_PROGRAM -eq "vscode") {
        return "vscode"
    }
    elseif ($Host.Name -eq "ConsoleHost") {
        return "powershell"
    }
    else {
        return "windows-terminal"  # Default fallback
    }
}

# Función para configurar Windows Terminal
function Set-WindowsTerminal {
    Write-Host "🔧 Configurando Windows Terminal..." -ForegroundColor Cyan
    
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Host "❌ Windows Terminal settings.json no encontrado" -ForegroundColor Red
        Write-Host "💡 Abre Windows Terminal al menos una vez para crear la configuración" -ForegroundColor Yellow
        return $false
    }
    
    try {
        # Leer configuración actual
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Crear backup
        $backupPath = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $settingsPath $backupPath
        
        # Configurar fuente en el perfil por defecto
        if (-not $settings.profiles) {
            $settings | Add-Member -Type NoteProperty -Name "profiles" -Value @{}
        }
        
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -Type NoteProperty -Name "defaults" -Value @{}
        }
        
        if (-not $settings.profiles.defaults.font) {
            $settings.profiles.defaults | Add-Member -Type NoteProperty -Name "font" -Value @{}
        }
        
        $settings.profiles.defaults.font.face = $NERD_FONT_FULL_NAME
        
        # Guardar configuración
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        
        Write-Host "✓ Windows Terminal configurado" -ForegroundColor Green
        Write-Host "📄 Backup creado: $backupPath" -ForegroundColor Blue
        return $true
    }
    catch {
        Write-Host "❌ Error configurando Windows Terminal: $_" -ForegroundColor Red
        return $false
    }
}

# Función para configurar Visual Studio Code
function Set-VSCode {
    Write-Host "🔧 Configurando Visual Studio Code..." -ForegroundColor Cyan
    
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    
    try {
        $settings = @{}
        
        # Leer configuración existente si existe
        if (Test-Path $settingsPath) {
            $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $settings = $existingSettings
        }
        
        # Configurar fuente del terminal
        $settings."terminal.integrated.fontFamily" = "'$NERD_FONT_FULL_NAME', Consolas, 'Courier New', monospace"
        
        # Crear directorio si no existe
        $settingsDir = Split-Path $settingsPath -Parent
        if (-not (Test-Path $settingsDir)) {
            New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        }
        
        # Guardar configuración
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
        
        Write-Host "✓ Visual Studio Code configurado" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error configurando Visual Studio Code: $_" -ForegroundColor Red
        return $false
    }
}

# Función para configurar PowerShell Console
function Set-PowerShellConsole {
    Write-Host "🔧 Configurando PowerShell Console..." -ForegroundColor Cyan
    
    try {
        # Intentar cambiar la fuente del console actual
        if ($Host.UI.RawUI) {
            Write-Host "💡 Para PowerShell Console:" -ForegroundColor Yellow
            Write-Host "  1. Haz clic derecho en la barra de título" -ForegroundColor Yellow
            Write-Host "  2. Selecciona 'Propiedades'" -ForegroundColor Yellow
            Write-Host "  3. Ve a la pestaña 'Fuente'" -ForegroundColor Yellow
            Write-Host "  4. Selecciona '$NERD_FONT_FULL_NAME'" -ForegroundColor Yellow
            Write-Host "  5. Haz clic en 'Aceptar'" -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Error configurando PowerShell Console: $_" -ForegroundColor Red
        return $false
    }
}

# Función para mostrar instrucciones generales
function Show-GeneralInstructions {
    Write-Host "💡 Instrucciones generales:" -ForegroundColor Yellow
    Write-Host "  1. Asegúrate de que '$NERD_FONT_FULL_NAME' esté instalada" -ForegroundColor Yellow
    Write-Host "  2. Abre la configuración de tu terminal" -ForegroundColor Yellow
    Write-Host "  3. Busca la opción de 'Fuente' o 'Font'" -ForegroundColor Yellow
    Write-Host "  4. Selecciona '$NERD_FONT_FULL_NAME'" -ForegroundColor Yellow
    Write-Host "  5. Reinicia el terminal para aplicar los cambios" -ForegroundColor Yellow
}

# Función principal
function main {
    if ($Terminal -eq "help" -or $Terminal -eq "--help" -or $Terminal -eq "-h" -or $Terminal -eq "") {
        Show-Help
        return
    }
    
    Write-Host "🚀 Configurando Nerd Fonts para Windows..." -ForegroundColor Green
    Write-Host ""
    
    # Verificar que las fuentes estén instaladas
    if (-not (Test-Fonts)) {
        return
    }
    
    # Detectar terminal si es auto
    if ($Terminal -eq "auto") {
        $Terminal = Get-Terminal
        Write-Host "🔍 Terminal detectado: $Terminal" -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    # Configurar según el terminal
    $success = switch ($Terminal) {
        "windows-terminal" { Set-WindowsTerminal }
        "vscode" { Set-VSCode }
        "powershell" { Set-PowerShellConsole }
        "cmd" { 
            Write-Host "💡 Command Prompt usa la configuración del sistema" -ForegroundColor Yellow
            Show-GeneralInstructions
            $true
        }
        default {
            Write-Host "❌ Terminal no soportado: $Terminal" -ForegroundColor Red
            Write-Host ""
            Show-GeneralInstructions
            $false
        }
    }
    
    Write-Host ""
    
    if ($success) {
        Write-Host "✅ Configuración completada para $Terminal" -ForegroundColor Green
        Write-Host "💡 Reinicia tu terminal para ver los cambios" -ForegroundColor Blue
    }
    else {
        Write-Host "⚠️ Configuración completada con advertencias" -ForegroundColor Yellow
    }
}

# Ejecutar función principal
main 