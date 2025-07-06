#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[03-dotfiles] $*"
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
TARGET_HOME="$HOME"
FILES=(.zshrc .luispa.omp.json)

for file in "${FILES[@]}"; do
  src="$DOTFILES_DIR/$file"
  dst="$TARGET_HOME/$file"

  if [[ -f "$dst" ]]; then
    log "🔄 $file ya existe en $TARGET_HOME y será sobrescrito"
  fi

  log "Copiando $file a $TARGET_HOME"
  cp -f "$src" "$dst"
done

# No cambiar shell en macOS (ya es zsh por defecto)
if [[ "${OS_TYPE:-}" == "macos" ]]; then
  log "macOS detectado: no es necesario cambiar la shell (zsh es la predeterminada)"
else
  # Cambiar shell a zsh si está instalado y no es la actual
  if command -v zsh &>/dev/null; then
    ZSH_PATH="$(command -v zsh)"

    if [[ "$OS_TYPE" == "macos" ]]; then
      CURRENT_SHELL="$(dscl . -read /Users/$USER UserShell | awk '{print $2}')"
    else
      CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
    fi

    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
      log "Se pedirá tu contraseña para cambiar la shell por defecto a zsh"
      log "Cambiando shell por defecto a zsh para el usuario $USER"
      chsh -s "$ZSH_PATH"
      log "⚠️ Se ha cambiado la shell por defecto a zsh."
      log "💡 Debes cerrar completamente la sesión gráfica (GUI) y volver a entrar para que tenga efecto."
    else
      log "La shell por defecto ya es zsh"
    fi
  else
    log "⚠️ zsh no está instalado, no se puede cambiar la shell"
  fi
fi

log "✅ Dotfiles instalados y shell configurada"
