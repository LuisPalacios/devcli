#!/bin/bash
# Script completo de verificación de Nerd Fonts
# Uso: ./nerd-verify.sh

set -e

# Configuración de Nerd Fonts
export NERD_FONT_NAME="FiraCode"
export NERD_FONT_FULL_NAME="FiraCode Nerd Font"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Verificación Completa de Nerd Fonts ===${NC}"
echo

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Función para detectar sistema operativo
detect_os() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl2"
  elif [[ "$OSTYPE" == darwin* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

# Función para detectar terminal
detect_terminal() {
  if [[ -n "$WSL_DISTRO_NAME" ]]; then
    echo "wsl"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
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

# Función para verificar fuentes con múltiples métodos
check_fonts_comprehensive() {
  echo -e "${CYAN}=== Verificación de Fuentes ===${NC}"

  local fonts_installed=false
  local detection_methods=()

  # Método 1: fc-list (Linux/WSL2)
  if command_exists fc-list; then
    echo -e "${CYAN}Verificando con fc-list...${NC}"
    if fc-list | grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" 2>/dev/null; then
      echo -e "${GREEN}✓ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} detectada con fc-list${NC}"
      fonts_installed=true
      detection_methods+=("fc-list")
    else
      echo -e "${RED}✗ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} NO detectada con fc-list${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ fc-list no disponible${NC}"
  fi

  # Método 2: Directorio estándar
  local font_dir="$HOME/.local/share/fonts"
  echo -e "${CYAN}Verificando directorio estándar: $font_dir${NC}"
  if [[ -d "$font_dir" ]]; then
    if find "$font_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
      echo -e "${GREEN}✓ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} detectada en directorio estándar${NC}"
      fonts_installed=true
      detection_methods+=("directorio estándar")
    else
      echo -e "${RED}✗ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} NO detectada en directorio estándar${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Directorio estándar no existe: $font_dir${NC}"
  fi

  # Método 3: Directorio alternativo
  local fonts_dir="$HOME/.fonts"
  echo -e "${CYAN}Verificando directorio alternativo: $fonts_dir${NC}"
  if [[ -d "$fonts_dir" ]]; then
    if find "$fonts_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
      echo -e "${GREEN}✓ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} detectada en directorio alternativo${NC}"
      fonts_installed=true
      detection_methods+=("directorio alternativo")
    else
      echo -e "${RED}✗ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} NO detectada en directorio alternativo${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Directorio alternativo no existe: $fonts_dir${NC}"
  fi

  # Método 4: Fuentes del sistema (macOS)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${CYAN}Verificando fuentes del sistema en macOS...${NC}"
    if command_exists system_profiler; then
      if system_profiler SPFontsDataType | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
        echo -e "${GREEN}✓ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} detectada en sistema macOS${NC}"
        fonts_installed=true
        detection_methods+=("sistema macOS")
      else
        echo -e "${RED}✗ ${NERD_FONT_FULL_NAME:-FiraCode Nerd Font} NO detectada en sistema macOS${NC}"
      fi
    else
      echo -e "${YELLOW}⚠ system_profiler no disponible${NC}"
    fi
  fi

  # Resumen de detección
  echo
  if [[ "$fonts_installed" == "true" ]]; then
    echo -e "${GREEN}✓ Fuentes instaladas y detectadas${NC}"
    echo -e "${CYAN}Métodos de detección exitosos: ${detection_methods[*]}${NC}"
    return 0
  else
    echo -e "${RED}✗ Fuentes NO instaladas o no detectadas${NC}"
    return 1
  fi
}

# Función para verificar configuración de terminal
check_terminal_configuration() {
  local terminal="$1"
  echo -e "${CYAN}=== Verificación de Configuración de Terminal ===${NC}"
  echo -e "${CYAN}Terminal detectado: $terminal${NC}"

  local terminal_configured=false

  case "$terminal" in
    "gnome-terminal")
      if command_exists gsettings; then
        local profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null)
        if [[ -n "$profile" ]]; then
          profile=${profile:1:-1}
          local font=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ font 2>/dev/null)
          if [[ "$font" == *"${NERD_FONT_NAME:-FiraCode}"* ]]; then
            echo -e "${GREEN}✓ GNOME Terminal configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
            terminal_configured=true
          else
            echo -e "${YELLOW}⚠ GNOME Terminal NO configurado con ${NERD_FONT_NAME:-FiraCode} (actual: $font)${NC}"
          fi
        fi
      fi
      ;;
    "vscode")
      local settings_file="$HOME/.config/Code/User/settings.json"
      if [[ -f "$settings_file" ]]; then
        if grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" "$settings_file" 2>/dev/null; then
          echo -e "${GREEN}✓ VSCode configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
          terminal_configured=true
        else
          echo -e "${YELLOW}⚠ VSCode NO configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ Archivo de configuración de VSCode no encontrado${NC}"
      fi
      ;;
    "alacritty")
      local config_file="$HOME/.config/alacritty/alacritty.yml"
      if [[ -f "$config_file" ]]; then
        if grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" "$config_file" 2>/dev/null; then
          echo -e "${GREEN}✓ Alacritty configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
          terminal_configured=true
        else
          echo -e "${YELLOW}⚠ Alacritty NO configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ Archivo de configuración de Alacritty no encontrado${NC}"
      fi
      ;;
    "kitty")
      local config_file="$HOME/.config/kitty/kitty.conf"
      if [[ -f "$config_file" ]]; then
        if grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" "$config_file" 2>/dev/null; then
          echo -e "${GREEN}✓ Kitty configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
          terminal_configured=true
        else
          echo -e "${YELLOW}⚠ Kitty NO configurado con ${NERD_FONT_NAME:-FiraCode}${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ Archivo de configuración de Kitty no encontrado${NC}"
      fi
      ;;
    "wsl")
      echo -e "${YELLOW}⚠ WSL requiere configuración manual en Windows Terminal${NC}"
      echo -e "${CYAN}Instrucciones:${NC}"
      echo -e "1. Abre Windows Terminal"
      echo -e "2. Ve a Configuración (Ctrl+,)"
      echo -e "3. Busca tu perfil de WSL/Ubuntu"
      echo -e "4. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
      ;;
    "unknown")
      echo -e "${YELLOW}⚠ Sistema headless detectado (SSH/consola)${NC}"
      echo -e "${CYAN}Las fuentes están instaladas y disponibles para:${NC}"
      echo -e "  - Clientes SSH con soporte de fuentes"
      echo -e "  - Editores remotos (VSCode Remote, etc.)"
      echo -e "  - Terminales locales que se conecten a este servidor"
      echo -e ""
      echo -e "${CYAN}Para configurar un cliente SSH:${NC}"
      echo -e "  nerd-setup.sh vscode    # Para VSCode Remote"
      echo -e "  nerd-setup.sh auto      # Para detección automática"
      ;;
    *)
      echo -e "${YELLOW}⚠ Verificación de configuración no implementada para $terminal${NC}"
      ;;
  esac

  return $([[ "$terminal_configured" == "true" ]] && echo 0 || echo 1)
}

# Función para mostrar información del sistema
show_system_info() {
  echo -e "${CYAN}=== Información del Sistema ===${NC}"
  echo "OS: $(detect_os)"
  echo "Terminal: $(detect_terminal)"
  echo "TERM_PROGRAM: ${TERM_PROGRAM:-no definido}"
  echo "TERM: ${TERM:-no definido}"
  echo "HOME: $HOME"
  echo "WSL_DISTRO_NAME: ${WSL_DISTRO_NAME:-no definido}"
  echo
}

# Función para mostrar fuentes disponibles
show_available_fonts() {
  echo -e "${CYAN}=== Fuentes Disponibles ===${NC}"

  if command_exists fc-list; then
    echo "Fuentes con '${NERD_FONT_NAME:-FiraCode}' en el nombre:"
    fc-list | grep -i "${NERD_FONT_NAME:-FiraCode}" | head -5
    echo

    echo "Fuentes con 'Nerd' en el nombre:"
    fc-list | grep -i "nerd" | head -5
    echo
  fi
}

# Función para mostrar directorios de fuentes
show_font_directories() {
  echo -e "${CYAN}=== Directorios de Fuentes ===${NC}"

  local dirs=(
    "$HOME/.local/share/fonts"
    "$HOME/.fonts"
    "/usr/share/fonts"
    "/usr/local/share/fonts"
    "/System/Library/Fonts"
    "/Library/Fonts"
    "$HOME/Library/Fonts"
  )

  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      echo "✓ $dir"
      local firacode_files=$(find "$dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f 2>/dev/null | head -3)
      if [[ -n "$firacode_files" ]]; then
        echo "$firacode_files" | while read -r file; do
          echo "  └─ $(basename "$file")"
        done
      fi
    else
      echo "✗ $dir (no existe)"
    fi
  done
  echo
}

# Función para mostrar recomendaciones
show_recommendations() {
  echo -e "${CYAN}=== Recomendaciones ===${NC}"

  local os=$(detect_os)
  local terminal=$(detect_terminal)

  if [[ "$1" -eq 0 ]] && [[ "$2" -eq 0 ]]; then
    echo -e "${GREEN}✓ Todo está configurado correctamente${NC}"
    echo -e "${CYAN}Prueba lsd para ver los iconos:${NC}"
    echo "lsd --version"
    echo "lsd -la"
  else
    if [[ "$1" -ne 0 ]]; then
      echo -e "${RED}✗ Fuentes no instaladas${NC}"
      echo -e "${YELLOW}Para instalar las fuentes:${NC}"
      echo "cd ~/.devcli/install && ./02-packages.sh"
      echo
    fi

    if [[ "$2" -ne 0 ]]; then
      echo -e "${RED}✗ Terminal no configurado${NC}"
      echo -e "${YELLOW}Para configurar el terminal:${NC}"
      echo "nerd-setup.sh $terminal"
      echo
    fi
  fi
}

# Función principal
main() {
  show_system_info

  local os=$(detect_os)
  local terminal=$(detect_terminal)

  # Verificar fuentes
  check_fonts_comprehensive
  fonts_status=$?

  echo

  # Verificar configuración de terminal
  check_terminal_configuration "$terminal"
  terminal_status=$?

  echo

  # Mostrar información adicional
  show_available_fonts
  show_font_directories

  # Mostrar recomendaciones
  show_recommendations $fonts_status $terminal_status

  # Resumen final
  echo -e "${CYAN}=== Resumen Final ===${NC}"
  if [[ "$fonts_status" -eq 0 ]]; then
    echo -e "${GREEN}✓ Fuentes instaladas${NC}"
  else
    echo -e "${RED}✗ Fuentes NO instaladas${NC}"
  fi

  if [[ "$terminal_status" -eq 0 ]]; then
    echo -e "${GREEN}✓ Terminal configurado${NC}"
  else
    echo -e "${RED}✗ Terminal NO configurado${NC}"
  fi

  echo
}

main "$@"