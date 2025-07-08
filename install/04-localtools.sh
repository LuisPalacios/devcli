#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Carga las utilidades compartidas
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Función de log (usando la de utils.sh)
log() {
  log_simple "$*"
}

# Directorio de archivos
FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Contador de herramientas instaladas
TOOLS_INSTALLED=0

# Copiar herramientas al directorio de los binarios
log "Instalando herramientas locales..."
for tool in e confcat s nerd-setup.sh nerd-verify.sh; do
  src="$FILES_DIR/bin/$tool"
  dst="$BIN_DIR/$tool"

  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst" >/dev/null 2>&1
    chmod 755 "$dst" >/dev/null 2>&1
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
  fi
done

# Configuración y directorios dependientes del sistema operativo
case "${OS_TYPE:-}" in
  linux|wsl2)
    # Instalar configuración de nano (silencioso)
    if [[ -f "$FILES_DIR/etc/nanorc" ]]; then
      log "Configurando nano..."
      sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc >/dev/null 2>&1
    fi

    # Crear directorio /root/.nano (silencioso)
    sudo mkdir -p /root/.nano >/dev/null 2>&1
    ;;

  macos)
    log "macOS detectado: se omite configuración de /etc/nanorc y /root/.nano"
    ;;

  *)
    log "Sistema no soportado: omitiendo configuración específica de nano"
    ;;
esac

# Crear directorio local de nano (común a todos)
mkdir -p "$HOME/.nano" >/dev/null 2>&1

# Mostrar resumen final
success "Herramientas locales instaladas ($TOOLS_INSTALLED herramientas)"

# Configuración automática de Nerd Fonts si están disponibles
log "Verificando configuración de Nerd Fonts..."

# Función para verificar si las fuentes están instaladas
check_nerd_fonts_installed() {
  local fonts_installed=false

  # Método 1: fc-list (Linux/WSL2)
  if command -v fc-list &>/dev/null; then
    if fc-list | grep -q "FiraCode Nerd Font" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 2: Directorio estándar
  if [[ "$fonts_installed" == "false" ]]; then
    local font_dir="$HOME/.local/share/fonts"
    if [[ -d "$font_dir" ]] && find "$font_dir" -name "*FiraCode*" -type f | grep -q "FiraCode" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 3: Directorio alternativo
  if [[ "$fonts_installed" == "false" ]]; then
    local fonts_dir="$HOME/.fonts"
    if [[ -d "$fonts_dir" ]] && find "$fonts_dir" -name "*FiraCode*" -type f | grep -q "FiraCode" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  echo "$fonts_installed"
}

# Función para detectar terminal automáticamente
detect_terminal() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    echo "wsl"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -n "${TERM_PROGRAM:-}" ]]; then
      case "$TERM_PROGRAM" in
        "vscode") echo "vscode" ;;
        "Apple_Terminal") echo "macos-terminal" ;;
        "iTerm.app") echo "iterm" ;;
        *) echo "macos-terminal" ;;
      esac
    else
      echo "macos-terminal"
    fi
  elif [[ -n "${TERM_PROGRAM:-}" ]]; then
    case "$TERM_PROGRAM" in
      "vscode") echo "vscode" ;;
      *) echo "unknown" ;;
    esac
  elif [[ -n "${GNOME_DESKTOP_SESSION_ID:-}" ]]; then
    echo "gnome-terminal"
  elif [[ -n "${KDE_FULL_SESSION:-}" ]]; then
    echo "konsole"
  elif [[ -n "${XFCE_DESKTOP_SESSION_ID:-}" ]]; then
    echo "xfce4-terminal"
  else
    echo "unknown"
  fi
}

# Verificar si las fuentes están instaladas
if [[ "$(check_nerd_fonts_installed)" == "true" ]]; then
  log "FiraCode Nerd Font detectada, configurando terminal automáticamente..."

  # Detectar terminal
  terminal=$(detect_terminal)

  # Intentar configuración automática
  if [[ -f "$BIN_DIR/nerd-setup.sh" ]]; then
    if "$BIN_DIR/nerd-setup.sh" "$terminal" >/dev/null 2>&1; then
      success "Terminal configurado automáticamente para usar FiraCode Nerd Font"
    else
      if [[ "$terminal" == "unknown" ]]; then
        log "Sistema headless detectado (SSH/consola)"
        log "Las fuentes están instaladas y disponibles para:"
        log "  - Clientes SSH con soporte de fuentes"
        log "  - Editores remotos (VSCode Remote, etc.)"
        log "  - Terminales locales que se conecten a este servidor"
        log ""
        log "Para configurar un cliente SSH, ejecuta:"
        log "  nerd-setup.sh vscode    # Para VSCode Remote"
        log "  nerd-setup.sh auto      # Para detección automática"
      else
        warning "Configuración automática falló, pero las fuentes están instaladas"
        log "Para configurar manualmente tu terminal, ejecuta:"
        log "  nerd-setup.sh $terminal"
      fi
    fi
  else
    warning "Script nerd-setup.sh no encontrado"
    log "Para configurar tu terminal, ejecuta:"
    log "  nerd-setup.sh $terminal"
  fi
  else
    log "FiraCode Nerd Font no detectada"
    log "Para instalar las fuentes y configurar tu terminal:"
    log "  1. Ejecuta: nerd-setup.sh auto"
    log "  2. O instala las fuentes primero: cd ~/.linux-setup/install && ./02-packages.sh"
  fi

  # Mensaje especial para WSL
  if [[ "${OS_TYPE:-}" == "wsl2" ]]; then
    echo
    echo "==============================="
    echo "IMPORTANTE PARA WSL:"
    echo "==============================="
    echo "1. Abre Windows Terminal"
    echo "2. Ve a Configuración (Ctrl+,)"
    echo "3. Busca tu perfil de WSL/Ubuntu"
    echo "4. Ve a Appearance"
    echo "5. Cambia la fuente a 'FiraCode Nerd Font'"
    echo "==============================="
    echo
  fi