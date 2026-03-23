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

# Verificar permisos sudo
if [[ $IS_ROOT == false ]]; then
  check_sudo_access
fi

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

# Copiar herramientas al directorio de los binarios (filtrado por plataforma)
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
      fi

      TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    fi
  fi
done < <(jq -r --arg p "$OS_TYPE" '.tools[] | select(.platforms | index($p)) | .name' "$LOCAL_TOOLS_CONFIG" 2>/dev/null)

# Configuración y directorios dependientes del sistema operativo
case "${OS_TYPE:-}" in
  linux|wsl2)
    # Instalar configuración de nano (silencioso)
    if [[ -f "$FILES_DIR/etc/nanorc" ]]; then
      sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc >/dev/null 2>&1
    fi
    sudo mkdir -p /root/.nano >/dev/null 2>&1
    ;;

  macos|*)
    ;;
esac

# Crear directorio local de nano (común a todos)
mkdir -p "$HOME/.nano" >/dev/null 2>&1

# Mostrar resumen final
success "Herramientas locales instaladas ($TOOLS_INSTALLED herramientas)"

# Verificar Nerd Fonts
check_nerd_fonts_installed() {
  # Método 1: fc-list (Linux/WSL2)
  if command -v fc-list &>/dev/null && fc-list | grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" 2>/dev/null; then
    echo "true"; return
  fi
  # Método 2: Directorios estándar de fuentes (Linux/WSL2)
  for dir in "$HOME/.local/share/fonts" "$HOME/.fonts"; do
    if [[ -d "$dir" ]] && find "$dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f 2>/dev/null | grep -q .; then
      echo "true"; return
    fi
  done
  # Método 3: Directorio de fuentes de usuario en macOS
  if [[ -d "$HOME/Library/Fonts" ]] && find "$HOME/Library/Fonts" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f 2>/dev/null | grep -q .; then
    echo "true"; return
  fi
  # Método 4: system_profiler en macOS
  if [[ "${OS_TYPE:-}" == "macos" ]] && command -v system_profiler &>/dev/null; then
    if system_profiler SPFontsDataType 2>/dev/null | grep -q "${NERD_FONT_NAME:-FiraCode}"; then
      echo "true"; return
    fi
  fi
  echo "false"
}

if [[ "$(check_nerd_fonts_installed)" == "true" ]]; then
  success "Nerd Font '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' disponible"
  if [[ "${OS_TYPE:-}" == "wsl2" ]]; then
    log "Configura la fuente en Windows Terminal: Configuración → tu perfil WSL → Appearance"
  fi
else
  log "Nerd Font no detectada. Ejecuta nerd-setup.sh para instalarla."
fi
