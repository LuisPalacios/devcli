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

# Archivo de configuración
LOCAL_TOOLS_CONFIG="$(dirname "${BASH_SOURCE[0]}")/05-localtools.json"

# Contador de herramientas instaladas
TOOLS_INSTALLED=0

# Función para actualizar variables de Nerd Fonts en scripts
update_nerd_font_variables() {
  local script_file="$1"
  if [[ -f "$script_file" ]]; then
    # Crear archivo temporal
    local temp_file=$(mktemp)

    # Reemplazar NERD_FONT_NAME
    sed "s/export NERD_FONT_NAME=\"[^\"]*\"/export NERD_FONT_NAME=\"${NERD_FONT_NAME}\"/g" "$script_file" > "$temp_file"

    # Reemplazar NERD_FONT_FULL_NAME
    sed "s/export NERD_FONT_FULL_NAME=\"[^\"]*\"/export NERD_FONT_FULL_NAME=\"${NERD_FONT_FULL_NAME}\"/g" "$temp_file" > "$script_file"

    # Limpiar archivo temporal
    rm -f "$temp_file" 2>/dev/null || true
  fi
}

# Copiar herramientas al directorio de los binarios
log "Instalando herramientas locales..."
while IFS= read -r tool; do
  if [[ -n "$tool" ]]; then
    src="$FILES_DIR/bin/$tool"
    dst="$BIN_DIR/$tool"

    if [[ -f "$src" ]]; then
      cp -f "$src" "$dst" >/dev/null 2>&1
      chmod 755 "$dst" >/dev/null 2>&1

      # Actualizar variables de Nerd Fonts en scripts específicos
      if [[ "$tool" == "nerd-setup.sh" ]] || [[ "$tool" == "nerd-verify.sh" ]]; then
        update_nerd_font_variables "$dst"
        log "Variables de Nerd Fonts actualizadas en $tool"
      fi

      TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    fi
  fi
done < <(read_json_array "$LOCAL_TOOLS_CONFIG" "tools")

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
    if fc-list | grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 2: Directorio estándar
  if [[ "$fonts_installed" == "false" ]]; then
    local font_dir="$HOME/.local/share/fonts"
    if [[ -d "$font_dir" ]] && find "$font_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 3: Directorio alternativo
  if [[ "$fonts_installed" == "false" ]]; then
    local fonts_dir="$HOME/.fonts"
    if [[ -d "$fonts_dir" ]] && find "$fonts_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
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
  log "'${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' detectada, configurando terminal automáticamente..."

  # Detectar terminal
  terminal=$(detect_terminal)

  # Intentar configuración automática
  if [[ -f "$BIN_DIR/nerd-setup.sh" ]]; then
    if "$BIN_DIR/nerd-setup.sh" "$terminal" >/dev/null 2>&1; then
      success "Terminal configurado automáticamente para usar '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
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
    log "'${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' no detectada"
    log "Para instalar las fuentes y configurar tu terminal:"
    log "  1. Ejecuta: nerd-setup.sh auto"
    log "  2. O instala las fuentes primero: cd ~/.devcli/install && ./02-packages.sh"
  fi

  # Mensaje especial
  msg_shown=false

  # Mensaje especial para WSL
  if [[ "${OS_TYPE:-}" == "wsl2" ]]; then
    echo
    echo "==========================================="
    echo "IMPORTANTE PARA WSL:"
    echo "==========================================="
    echo "1. Abre Windows Terminal"
    echo "2. Ve a Configuración (Ctrl+,)"
    echo "3. Busca tu perfil de WSL/Ubuntu"
    echo "4. Ve a Appearance"
    echo "5. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
    echo "==========================================="
    echo
    msg_shown=true
  fi

  # Mensajes especiales para macOS
  if [[ "${OS_TYPE:-}" == "macos" ]] && [[ "$msg_shown" == "false" ]]; then
    # Detectar terminal específico de macOS
    macos_terminal=$(detect_terminal)

    case "$macos_terminal" in
      "macos-terminal")
        echo
        echo "==========================================="
        echo "IMPORTANTE PARA macOS TERMINAL:"
        echo "==========================================="
        echo "1. Abre Terminal.app"
        echo "2. Ve a Terminal > Ajustes (⌘,)"
        echo "3. Selecciona tu perfil actual"
        echo "4. Ve a la pestaña 'Text'"
        echo "5. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
        echo "6. Ajusta el tamaño de fuente si es necesario"
        echo "==========================================="
        echo
        msg_shown=true
        ;;
      "iterm")
        echo
        echo "==========================================="
        echo "IMPORTANTE PARA iTerm2:"
        echo "==========================================="
        echo "1. Abre iTerm2"
        echo "2. Ve a iTerm2 > Settings (⌘,)"
        echo "3. Selecciona tu perfil actual"
        echo "4. Ve a la pestaña 'Text'"
        echo "5. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
        echo "6. Ajusta el tamaño de fuente si es necesario"
        echo "7. Opcional: Activa 'Use ligatures' para mejor apariencia"
        echo "==========================================="
        echo
        msg_shown=true
        ;;
      "vscode")
        echo
        echo "==========================================="
        echo "IMPORTANTE PARA VSCode EN macOS:"
        echo "==========================================="
        echo "1. Abre VSCode"
        echo "2. Ve a Code > Preferences > Settings (⌘,)"
        echo "3. Busca 'terminal.integrated.fontFamily'"
        echo "4. Cambia el valor a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
        echo "5. Opcional: Añade 'terminal.integrated.fontLigatures': true"
        echo "==========================================="
        echo
        msg_shown=true
        ;;
      *)
        echo
        echo "==========================================="
        echo "IMPORTANTE PARA macOS:"
        echo "==========================================="
        echo "Para usar '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' en tu terminal:"
        echo "1. Abre tu aplicación de terminal"
        echo "2. Busca la configuración de fuentes"
        echo "3. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
        echo "4. Reinicia tu terminal"
        echo "==========================================="
        echo
        msg_shown=true
        ;;
    esac
  fi

  # Mensaje general para cualquier sistema (solo si no se ha mostrado ningún mensaje específico)
  if [[ "$msg_shown" == "false" ]]; then
    echo
    echo "==========================================="
    echo "CONFIGURACIÓN MANUAL DE NERD FONTS:"
    echo "==========================================="
    echo "Si tu terminal no se configuró automáticamente,"
    echo "puedes configurar manualmente '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' en cualquier terminal:"
    echo ""
    echo "1. Abre tu aplicación de terminal"
    echo "2. Busca la configuración de fuentes/tipografía"
    echo "3. Cambia la fuente a '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
    echo "4. Ajusta el tamaño de fuente si es necesario"
    echo "5. Reinicia tu terminal"
    echo ""
    echo "Beneficios de usar Nerd Fonts:"
    echo "  - Iconos y símbolos especiales en la terminal"
    echo "  - Mejor visualización de archivos y directorios"
    echo "  - Compatibilidad con herramientas como lsd, exa, etc."
    echo ""
    echo "Para verificar la instalación, ejecuta:"
    echo "  nerd-verify.sh"
    echo "==========================================="
    echo
  fi