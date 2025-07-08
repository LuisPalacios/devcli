#!/bin/bash
# Script para configurar terminal con Nerd Fonts
# Uso: nerd-setup.sh [terminal]

set -e

# Configuración de Nerd Fonts
export NERD_FONT_NAME="FiraCode"
export NERD_FONT_FULL_NAME="FiraCode Nerd Font"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Uso: linux-setup-terminal.sh [TERMINAL]

Configura tu terminal para usar ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}.

Terminales soportados:
  gnome-terminal    Terminal de GNOME
  konsole          Terminal de KDE
  xfce4-terminal   Terminal de XFCE
  terminator       Terminator
  alacritty        Alacritty
  kitty            Kitty
  vscode           Visual Studio Code
  macos-terminal   Terminal de macOS
  iterm            iTerm2
  wsl              Windows Subsystem for Linux
  auto             Detectar automáticamente

Ejemplos:
  linux-setup-terminal.sh gnome-terminal
  linux-setup-terminal.sh auto
EOF
}

# Función para detectar terminal automáticamente
detect_terminal() {
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        echo "wsl"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if [[ -n "$TERM_PROGRAM" ]]; then
            case "$TERM_PROGRAM" in
                "vscode") echo "vscode" ;;
                "Apple_Terminal") echo "macos-terminal" ;;
                "iTerm.app") echo "iterm" ;;
                *) echo "macos-terminal" ;;
            esac
        else
            echo "macos-terminal"
        fi
    elif [[ -n "$TERM_PROGRAM" ]]; then
        case "$TERM_PROGRAM" in
            "vscode") echo "vscode" ;;
            *) echo "unknown" ;;
        esac
    elif [[ -n "$GNOME_DESKTOP_SESSION_ID" ]]; then
        echo "gnome-terminal"
    elif [[ -n "$KDE_FULL_SESSION" ]]; then
        echo "konsole"
    elif [[ -n "$XFCE_DESKTOP_SESSION_ID" ]]; then
        echo "xfce4-terminal"
    else
        echo "unknown"
    fi
}

# Función para configurar GNOME Terminal
configure_gnome_terminal() {
    echo -e "${BLUE}Configurando GNOME Terminal...${NC}"

    # Obtener el perfil activo
    local profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
    profile=${profile:1:-1}  # Remover comillas

    # Configurar fuente
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ font '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} 12'

    echo -e "${GREEN}✓ GNOME Terminal configurado${NC}"
    echo -e "${YELLOW}Reinicia tu terminal para ver los cambios${NC}"
}

# Función para configurar Konsole
configure_konsole() {
    echo -e "${BLUE}Configurando Konsole...${NC}"

    # Crear archivo de configuración
    local config_dir="$HOME/.config/konsole"
    mkdir -p "$config_dir"

    cat > "$config_dir/Profile1.profile" << EOF
[Appearance]
ColorScheme=Breeze
Font=${NERD_FONT_FULL_NAME:-FiraCode Nerd Font},12,-1,5,50,0,0,0,0,0

[General]
Name=Profile 1
Parent=FALLBACK/
EOF

    echo -e "${GREEN}✓ Konsole configurado${NC}"
    echo -e "${YELLOW}Reinicia Konsole para ver los cambios${NC}"
}

# Función para configurar XFCE4 Terminal
configure_xfce4_terminal() {
    echo -e "${BLUE}Configurando XFCE4 Terminal...${NC}"

    # Configurar fuente
    xfconf-query -c xfce4-terminal -p /profiles/Default/font -s "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} 12" 2>/dev/null || true

    echo -e "${GREEN}✓ XFCE4 Terminal configurado${NC}"
    echo -e "${YELLOW}Reinicia tu terminal para ver los cambios${NC}"
}

# Función para configurar Terminator
configure_terminator() {
    echo -e "${BLUE}Configurando Terminator...${NC}"

    # Crear archivo de configuración
    local config_dir="$HOME/.config/terminator"
    mkdir -p "$config_dir"

    cat > "$config_dir/config" << EOF
[global_config]
  title_transmit_bg_color = "#d30102"
  title_transmit_fg_color = "#ffffff"
  title_inactive_bg_color = "#333333"
  title_inactive_fg_color = "#ffffff"
[keybindings]
[profiles]
  [[default]]
    background_color = "#300a24"
    background_darkness = 0.95
    background_type = solid
    cursor_color = "#aaaaaa"
    cursor_shape = block
    font = ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} 12
    foreground_color = "#ffffff"
    palette = "#2e2e2e:#ff0000:#00ff00:#ffff00:#0000ff:#ff00ff:#00ffff:#ffffff:#2e2e2e:#ff0000:#00ff00:#ffff00:#0000ff:#ff00ff:#00ffff:#ffffff"
    use_system_font = False
[layouts]
  [[default]]
    [[[child1]]]
      fullscreen = False
      last_active_term = 0b7c3c00-0000-0000-0000-000000000000
      maximised = False
      order = 0
      parent = ""
      position = 0:0
      size = 1920, 1000
      split_with = 0b7c3c00-0000-0000-0000-000000000000
      title = Terminal
      type = Window
      window_type = Normal
    [[[0b7c3c00-0000-0000-0000-000000000000]]]
      order = 0
      parent = child1
      profile = default
      type = Terminal
      uuid = 0b7c3c00-0000-0000-0000-000000000000
EOF

    echo -e "${GREEN}✓ Terminator configurado${NC}"
    echo -e "${YELLOW}Reinicia Terminator para ver los cambios${NC}"
}

# Función para configurar Alacritty
configure_alacritty() {
    echo -e "${BLUE}Configurando Alacritty...${NC}"

    # Crear archivo de configuración
    local config_dir="$HOME/.config/alacritty"
    mkdir -p "$config_dir"

    cat > "$config_dir/alacritty.yml" << EOF
font:
  normal:
    family: ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}
    style: Regular
  bold:
    family: ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}
    style: Bold
  italic:
    family: ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}
    style: Italic
  size: 12.0

colors:
  primary:
    background: '#2e2e2e'
    foreground: '#ffffff'
  normal:
    black:   '#2e2e2e'
    red:     '#ff0000'
    green:   '#00ff00'
    yellow:  '#ffff00'
    blue:    '#0000ff'
    magenta: '#ff00ff'
    cyan:    '#00ffff'
    white:   '#ffffff'
  bright:
    black:   '#2e2e2e'
    red:     '#ff0000'
    green:   '#00ff00'
    yellow:  '#ffff00'
    blue:    '#0000ff'
    magenta: '#ff00ff'
    cyan:    '#00ffff'
    white:   '#ffffff'
EOF

    echo -e "${GREEN}✓ Alacritty configurado${NC}"
    echo -e "${YELLOW}Reinicia Alacritty para ver los cambios${NC}"
}

# Función para configurar Kitty
configure_kitty() {
    echo -e "${BLUE}Configurando Kitty...${NC}"

    # Crear archivo de configuración
    local config_dir="$HOME/.config/kitty"
    mkdir -p "$config_dir"

    cat > "$config_dir/kitty.conf" << EOF
font_family ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}
font_size 12.0

background #2e2e2e
foreground #ffffff

color0 #2e2e2e
color1 #ff0000
color2 #00ff00
color3 #ffff00
color4 #0000ff
color5 #ff00ff
color6 #00ffff
color7 #ffffff
color8 #2e2e2e
color9 #ff0000
color10 #00ff00
color11 #ffff00
color12 #0000ff
color13 #ff00ff
color14 #00ffff
color15 #ffffff
EOF

    echo -e "${GREEN}✓ Kitty configurado${NC}"
    echo -e "${YELLOW}Reinicia Kitty para ver los cambios${NC}"
}

# Función para configurar VSCode
configure_vscode() {
    echo -e "${BLUE}Configurando Visual Studio Code...${NC}"

    # Configurar settings.json
    local settings_dir="$HOME/.config/Code/User"
    mkdir -p "$settings_dir"

    # Crear o actualizar settings.json
    if [[ -f "$settings_dir/settings.json" ]]; then
        # Actualizar configuración existente
        jq '.terminal.integrated.fontFamily = "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}"' "$settings_dir/settings.json" > "$settings_dir/settings.json.tmp" && mv "$settings_dir/settings.json.tmp" "$settings_dir/settings.json"
    else
        # Crear nuevo archivo
        cat > "$settings_dir/settings.json" << EOF
{
    "terminal.integrated.fontFamily": "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}"
}
EOF
    fi

    echo -e "${GREEN}✓ VSCode configurado${NC}"
    echo -e "${YELLOW}Reinicia VSCode para ver los cambios${NC}"
}

# Función para configurar Terminal de macOS
configure_macos_terminal() {
    echo -e "${BLUE}Configurando Terminal de macOS...${NC}"

    echo -e "${YELLOW}Para configurar Terminal de macOS:${NC}"
    echo -e "${BLUE}1. Abre Terminal.app${NC}"
    echo -e "2. Ve a Terminal > Preferencias > Perfiles"
    echo -e "3. Selecciona un perfil y haz clic en 'Editar'"
    echo -e "4. En la pestaña 'Texto', cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
    echo -e "5. Aplica los cambios"
    echo -e ""
    echo -e "${BLUE}O usa este comando para configurar automáticamente:${NC}"
    echo -e "defaults write com.apple.Terminal 'NSWindow Frame TTWindow' 'FiraCode Nerd Font'"
    echo -e ""
    echo -e "${GREEN}✓ Instrucciones para Terminal de macOS mostradas${NC}"
}

# Función para configurar iTerm2
configure_iterm() {
    echo -e "${BLUE}Configurando iTerm2...${NC}"

    echo -e "${YELLOW}Para configurar iTerm2:${NC}"
    echo -e "${BLUE}1. Abre iTerm2${NC}"
    echo -e "2. Ve a iTerm2 > Preferencias > Perfiles"
    echo -e "3. Selecciona un perfil y ve a la pestaña 'Texto'"
    echo -e "4. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
    echo -e "5. Aplica los cambios"
    echo -e ""
    echo -e "${BLUE}O usa este comando para configurar automáticamente:${NC}"
    echo -e "defaults write com.googlecode.iterm2 'New Bookmarks' -array-add '{ \"Name\" = \"Default\"; \"Non Ascii Font\" = \"FiraCode Nerd Font 12\"; }'"
    echo -e ""
    echo -e "${GREEN}✓ Instrucciones para iTerm2 mostradas${NC}"
}

# Función para configurar WSL
configure_wsl() {
    echo -e "${BLUE}Configurando WSL...${NC}"

    # Intentar configurar Windows Terminal automáticamente
    if command_exists powershell.exe; then
        echo -e "${BLUE}Intentando configurar Windows Terminal automáticamente...${NC}"

        # Crear script PowerShell para configurar Windows Terminal
        local ps_script="/tmp/configure-wt.ps1"
        cat > "$ps_script" << 'EOF'
# Script para configurar Windows Terminal con FiraCode Nerd Font
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath | ConvertFrom-Json

    # Buscar el perfil de WSL/Ubuntu
    foreach ($profile in $settings.profiles.list) {
        if ($profile.source -eq "Windows.Terminal.Wsl" -or $profile.name -like "*Ubuntu*" -or $profile.name -like "*WSL*") {
            $profile.font = @{
                face = "FiraCode Nerd Font"
                size = 12
            }
            Write-Host "Configurando perfil: $($profile.name)"
        }
    }

    # Guardar configuración
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
    Write-Host "Windows Terminal configurado exitosamente"
} else {
    Write-Host "Archivo de configuración de Windows Terminal no encontrado"
    Write-Host "Configuración manual requerida"
}
EOF

        # Ejecutar script PowerShell
        if powershell.exe -ExecutionPolicy Bypass -File "$ps_script" 2>/dev/null; then
            echo -e "${GREEN}✓ Windows Terminal configurado automáticamente${NC}"
        else
            echo -e "${YELLOW}⚠ Configuración automática falló, usando método manual${NC}"
        fi

        # Limpiar script temporal
        rm -f "$ps_script"
    fi

    echo -e "${YELLOW}Configuración manual (si la automática falló):${NC}"
    echo -e "${BLUE}1. Windows Terminal:${NC}"
    echo -e "   - Abre Windows Terminal"
    echo -e "   - Ve a Configuración (Ctrl+,)"
    echo -e "   - Busca tu perfil de WSL/Ubuntu"
    echo -e "   - En Apariencia, cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
    echo -e ""
    echo -e "${BLUE}2. Alternativas:${NC}"
    echo -e "   - Usa VSCode con terminal integrado"
    echo -e "   - Configura Alacritty o Kitty en Windows"
    echo -e ""
    echo -e "${GREEN}✓ Instrucciones para WSL mostradas${NC}"
}

# Función para verificar si las fuentes están instaladas
check_fonts() {
    local fonts_installed=false

    # Método 1: Verificar con fc-list (Linux/WSL2)
    if command_exists fc-list; then
        if fc-list | grep -q "FiraCode Nerd Font" 2>/dev/null; then
            fonts_installed=true
        fi
    fi

    # Método 2: Verificar directorio estándar
    if [[ "$fonts_installed" == "false" ]]; then
        local font_dir="$HOME/.local/share/fonts"
        if [[ -d "$font_dir" ]] && find "$font_dir" -name "*FiraCode*" -type f | grep -q "FiraCode" 2>/dev/null; then
            fonts_installed=true
        fi
    fi

    # Método 3: Verificar directorio alternativo
    if [[ "$fonts_installed" == "false" ]]; then
        local fonts_dir="$HOME/.fonts"
        if [[ -d "$fonts_dir" ]] && find "$fonts_dir" -name "*FiraCode*" -type f | grep -q "FiraCode" 2>/dev/null; then
            fonts_installed=true
        fi
    fi

    # Método 4: Verificar fuentes del sistema (macOS)
    if [[ "$fonts_installed" == "false" ]] && [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists system_profiler; then
            if system_profiler SPFontsDataType | grep -q "FiraCode" 2>/dev/null; then
                fonts_installed=true
            fi
        fi
    fi

    if [[ "$fonts_installed" == "false" ]]; then
        echo -e "${RED}Error: ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} no está instalada${NC}"
        echo -e "${YELLOW}Ejecuta el script de instalación primero${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ FiraCode Nerd Font detectada${NC}"
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    # Verificar que las fuentes estén instaladas
    check_fonts

    local terminal="$1"

    case "$terminal" in
        "auto")
            terminal=$(detect_terminal)
            echo -e "${BLUE}Terminal detectado: $terminal${NC}"
            ;;
        "gnome-terminal")
            configure_gnome_terminal
            ;;
        "konsole")
            configure_konsole
            ;;
        "xfce4-terminal")
            configure_xfce4_terminal
            ;;
        "terminator")
            configure_terminator
            ;;
        "alacritty")
            configure_alacritty
            ;;
        "kitty")
            configure_kitty
            ;;
        "vscode")
            configure_vscode
            ;;
        "macos-terminal")
            configure_macos_terminal
            ;;
        "iterm")
            configure_iterm
            ;;
        "wsl")
            configure_wsl
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo -e "${RED}Terminal no soportado: $terminal${NC}"
            show_help
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Configuración completada${NC}"
}

main "$@"