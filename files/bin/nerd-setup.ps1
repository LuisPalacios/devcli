#Requires -Version 7.0
# Script para mostrar instrucciones de configuración de Nerd Fonts en Windows
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

Muestra instrucciones para configurar tu terminal con $NERD_FONT_FULL_NAME.

Terminales soportados:
  windows-terminal     Windows Terminal
  powershell          Windows PowerShell ISE
  cmd                 Command Prompt
  vscode              Visual Studio Code
  auto                Detectar automáticamente

Ejemplos:
  nerd-setup.ps1 windows-terminal
  nerd-setup.ps1 auto

Nota: Este script solo muestra instrucciones, no modifica archivos automáticamente.
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

# Función para mostrar instrucciones de Windows Terminal
function Show-WindowsTerminalInstructions {
    Write-Host "🔧 Configuración de Windows Terminal:" -ForegroundColor Cyan
    Write-Host ""

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-not (Test-Path $settingsPath)) {
        Write-Host "❌ Windows Terminal settings.json no encontrado" -ForegroundColor Red
        Write-Host "💡 Abre Windows Terminal al menos una vez para crear la configuración" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    Write-Host "📋 Instrucciones paso a paso:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Método 1 - Interfaz Gráfica (Recomendado):" -ForegroundColor Green
    Write-Host "   1. Abre Windows Terminal" -ForegroundColor White
    Write-Host "   2. Presiona Ctrl + , (o ve a Configuración)" -ForegroundColor White
    Write-Host "   3. En la sidebar izquierda, selecciona 'Valores predeterminados'" -ForegroundColor White
    Write-Host "   4. Busca la sección 'Apariencia'" -ForegroundColor White
    Write-Host "   5. En 'Tipo de letra', selecciona:" -ForegroundColor White
    Write-Host "      '$NERD_FONT_FULL_NAME'" -ForegroundColor Cyan
    Write-Host "   6. Haz clic en 'Guardar'" -ForegroundColor White
    Write-Host ""

    Write-Host "   Método 2 - Edición Manual del JSON:" -ForegroundColor Green
    Write-Host "   1. Abre: $settingsPath" -ForegroundColor White
    Write-Host "   2. En la sección 'profiles' -> 'defaults', añade o modifica:" -ForegroundColor White
    Write-Host '      "font": {' -ForegroundColor Cyan
    Write-Host "          `"face`": `"$NERD_FONT_FULL_NAME`"" -ForegroundColor Cyan
    Write-Host '      }' -ForegroundColor Cyan
    Write-Host "   3. Guarda el archivo (Ctrl + S)" -ForegroundColor White
    Write-Host ""

    Write-Host "💡 Tip: También puedes configurar la fuente por perfil específico en lugar de globalmente" -ForegroundColor Blue

    return $true
}

# Función para mostrar instrucciones de Visual Studio Code
function Show-VSCodeInstructions {
    Write-Host "🔧 Configuración de Visual Studio Code:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 Instrucciones paso a paso:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Método 1 - Interfaz Gráfica (Recomendado):" -ForegroundColor Green
    Write-Host "   1. Abre Visual Studio Code" -ForegroundColor White
    Write-Host "   2. Presiona Ctrl + , (o ve a File > Preferences > Settings)" -ForegroundColor White
    Write-Host "   3. En el buscador, escribe: 'terminal font'" -ForegroundColor White
    Write-Host "   4. Busca 'Terminal › Integrated: Font Family'" -ForegroundColor White
    Write-Host "   5. En el campo, escribe:" -ForegroundColor White
    Write-Host "      '$NERD_FONT_FULL_NAME'" -ForegroundColor Cyan
    Write-Host "   6. Los cambios se guardan automáticamente" -ForegroundColor White
    Write-Host ""

    Write-Host "   Método 2 - Edición Manual del settings.json:" -ForegroundColor Green
    Write-Host "   1. Presiona Ctrl + Shift + P" -ForegroundColor White
    Write-Host "   2. Escribe: 'Preferences: Open Settings (JSON)'" -ForegroundColor White
    Write-Host "   3. Añade o modifica esta línea:" -ForegroundColor White
    Write-Host "      `"terminal.integrated.fontFamily`": `"'$NERD_FONT_FULL_NAME', Consolas, 'Courier New', monospace`"" -ForegroundColor Cyan
    Write-Host "   4. Guarda el archivo (Ctrl + S)" -ForegroundColor White
    Write-Host ""

    Write-Host "💡 Tip: También puedes configurar 'editor.fontFamily' para usar Nerd Font en el editor" -ForegroundColor Blue

    return $true
}

# Función para mostrar instrucciones de PowerShell Console
function Show-PowerShellInstructions {
    Write-Host "🔧 Configuración de PowerShell Console:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 Instrucciones paso a paso:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   1. Haz clic derecho en la barra de título de PowerShell" -ForegroundColor White
    Write-Host "   2. Selecciona 'Propiedades' en el menú" -ForegroundColor White
    Write-Host "   3. Ve a la pestaña 'Fuente'" -ForegroundColor White
    Write-Host "   4. En la lista de fuentes, selecciona:" -ForegroundColor White
    Write-Host "      '$NERD_FONT_FULL_NAME'" -ForegroundColor Cyan
    Write-Host "   5. Ajusta el tamaño si es necesario (recomendado: 12-14)" -ForegroundColor White
    Write-Host "   6. Haz clic en 'Aceptar'" -ForegroundColor White
    Write-Host "   7. Elige si aplicar solo a esta ventana o a todas las futuras" -ForegroundColor White
    Write-Host ""

    Write-Host "💡 Nota: Los cambios se aplicarán inmediatamente" -ForegroundColor Blue

    return $true
}

# Función para mostrar instrucciones de Command Prompt
function Show-CmdInstructions {
    Write-Host "🔧 Configuración de Command Prompt:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 Instrucciones paso a paso:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   1. Abre Command Prompt (cmd)" -ForegroundColor White
    Write-Host "   2. Haz clic derecho en la barra de título" -ForegroundColor White
    Write-Host "   3. Selecciona 'Propiedades'" -ForegroundColor White
    Write-Host "   4. Ve a la pestaña 'Fuente'" -ForegroundColor White
    Write-Host "   5. En la lista de fuentes, selecciona:" -ForegroundColor White
    Write-Host "      '$NERD_FONT_FULL_NAME'" -ForegroundColor Cyan
    Write-Host "   6. Ajusta el tamaño si es necesario" -ForegroundColor White
    Write-Host "   7. Haz clic en 'Aceptar'" -ForegroundColor White
    Write-Host ""

    Write-Host "💡 Nota: Command Prompt tiene soporte limitado para iconos Unicode" -ForegroundColor Blue

    return $true
}

# Función para mostrar instrucciones generales
function Show-GeneralInstructions {
    Write-Host "💡 Instrucciones generales para otros terminales:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   1. Asegúrate de que '$NERD_FONT_FULL_NAME' esté instalada" -ForegroundColor White
    Write-Host "   2. Abre la configuración/preferencias de tu terminal" -ForegroundColor White
    Write-Host "   3. Busca la opción de 'Fuente', 'Font' o 'Tipografía'" -ForegroundColor White
    Write-Host "   4. Selecciona '$NERD_FONT_FULL_NAME' de la lista" -ForegroundColor White
    Write-Host "   5. Guarda los cambios" -ForegroundColor White
    Write-Host "   6. Reinicia el terminal para aplicar los cambios" -ForegroundColor White
    Write-Host ""

    Write-Host "🔍 Terminales populares:" -ForegroundColor Blue
    Write-Host "   • Hyper: Edit > Preferences > fontFamily" -ForegroundColor Gray
    Write-Host "   • Terminus: Settings > Appearance > Font" -ForegroundColor Gray
    Write-Host "   • ConEmu: Settings > Main > Font" -ForegroundColor Gray
    Write-Host "   • Cmder: Settings > Main > Font" -ForegroundColor Gray
}

# Función principal
function main {
    if ($Terminal -eq "help" -or $Terminal -eq "--help" -or $Terminal -eq "-h" -or $Terminal -eq "") {
        Show-Help
        return
    }

    Write-Host "🚀 Instrucciones para configurar Nerd Fonts en Windows..." -ForegroundColor Green
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

    # Mostrar instrucciones según el terminal
    $success = switch ($Terminal) {
        "windows-terminal" { Show-WindowsTerminalInstructions }
        "vscode" { Show-VSCodeInstructions }
        "powershell" { Show-PowerShellInstructions }
        "cmd" { Show-CmdInstructions }
        default {
            Write-Host "❌ Terminal no soportado: $Terminal" -ForegroundColor Red
            Write-Host ""
            Show-GeneralInstructions
            $true
        }
    }

    Write-Host ""
    Write-Host "✅ Instrucciones mostradas para $Terminal" -ForegroundColor Green
    Write-Host "💡 Una vez configurado, reinicia tu terminal para ver los iconos de Nerd Font" -ForegroundColor Blue
    Write-Host "🧪 Ejecuta 'nerd-verify.ps1' para verificar que todo funciona correctamente" -ForegroundColor Magenta
}

# Ejecutar función principal
main