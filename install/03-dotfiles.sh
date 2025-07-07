#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Función de log
log() {
  echo "[03-dotfiles] $*"
}

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Directorio de dotfiles
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
TARGET_HOME="$HOME"

# Validar que el directorio de dotfiles existe
if [[ ! -d "$DOTFILES_DIR" ]]; then
  log "❌ Directorio de dotfiles no encontrado: $DOTFILES_DIR"
  exit 1
fi

# Instala los dotfiles
for file in "${DOTFILES_LIST[@]}"; do
  src="$DOTFILES_DIR/$file"
  dst="$TARGET_HOME/$file"

  # Validar que el archivo fuente existe
  if [[ ! -f "$src" ]]; then
    log "❌ Dotfile no encontrado: $src"
    continue
  fi

  if [[ -f "$dst" ]]; then
    log "🔄 $file ya existe en $TARGET_HOME y será sobrescrito"
  fi

  log "Copiando $file a $TARGET_HOME"
  cp -f "$src" "$dst"
done

# Cambiar shell a zsh si está disponible y el sistema lo requiere
if command -v zsh &>/dev/null; then
  ZSH_PATH="$(command -v zsh)"

  case "${OS_TYPE:-}" in
    macos)
      log "macOS detectado: no es necesario cambiar la shell (zsh es la predeterminada)"
      ;;

    linux|wsl2)
      CURRENT_SHELL="$(getent passwd "$CURRENT_USER" | cut -d: -f7)"

      if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        log "Se pedirá tu contraseña para cambiar la shell por defecto a zsh"
        log "Cambiando shell por defecto a zsh para el usuario $CURRENT_USER"
        chsh -s "$ZSH_PATH"
        log "⚠️ Se ha cambiado la shell por defecto a zsh."
        log "💡 Debes cerrar completamente la sesión gráfica (GUI) y volver a entrar para que tenga efecto."
      else
        log "La shell por defecto ya es zsh"
      fi
      ;;

    *)
      log "Sistema operativo no soportado para cambio de shell: $OS_TYPE"
      ;;
  esac
else
  log "⚠️ zsh no está instalado, no se puede cambiar la shell"
fi

log "✅ Dotfiles instalados y shell configurada"
