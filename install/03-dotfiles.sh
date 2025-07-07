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

# Directorio de dotfiles
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
TARGET_HOME="$HOME"

# Validar que el directorio de dotfiles existe
if [[ ! -d "$DOTFILES_DIR" ]]; then
  error "Directorio de dotfiles no encontrado: $DOTFILES_DIR"
  exit 1
fi

# Contador de dotfiles instalados
INSTALLED_COUNT=0

# Instala los dotfiles
log "Instalando dotfiles..."
for file in "${DOTFILES_LIST[@]}"; do
  src="$DOTFILES_DIR/$file"
  dst="$TARGET_HOME/$file"

  # Validar que el archivo fuente existe
  if [[ ! -f "$src" ]]; then
    warning "Dotfile no encontrado: $src"
    continue
  fi

  # Copiar archivo (silencioso pero capturando errores)
  if cp -f "$src" "$dst" >/dev/null 2>&1; then
    ((INSTALLED_COUNT++))
  else
    warning "No se pudo copiar $file"
  fi
done

# Cambiar shell a zsh si está disponible y el sistema lo requiere
SHELL_CHANGED=false
if command -v zsh &>/dev/null; then
  ZSH_PATH="$(command -v zsh)"

  case "${OS_TYPE:-}" in
    macos)
      # macOS usa zsh por defecto desde Catalina
      ;;
    linux|wsl2)
      CURRENT_SHELL="$(getent passwd "$CURRENT_USER" | cut -d: -f7)"

      if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        log "Cambiando shell por defecto a zsh..."
        if chsh -s "$ZSH_PATH" >/dev/null 2>&1; then
          SHELL_CHANGED=true
        else
          warning "No se pudo cambiar la shell por defecto (puede requerir contraseña)"
        fi
      fi
      ;;
  esac
fi

# Mostrar resumen final
if [[ "$SHELL_CHANGED" == "true" ]]; then
  success "Dotfiles instalados ($INSTALLED_COUNT archivos) y shell cambiada a zsh"
else
  success "Dotfiles instalados ($INSTALLED_COUNT archivos)"
fi
