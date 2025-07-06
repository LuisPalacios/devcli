#!/bin/bash
set -euo pipefail

log() {
  echo "[03-dotfiles] $*"
}

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
TARGET_HOME="$HOME"
FILES=(.zshrc .zshrc.async .luispa.omp.json)

for file in "${FILES[@]}"; do
  src="$DOTFILES_DIR/$file"
  dst="$TARGET_HOME/$file"

  if [[ -f "$dst" ]]; then
    log "⚠️  $file ya existe en $TARGET_HOME y será sobrescrito"
  fi

  log "Copiando $file a $TARGET_HOME"
  cp -f "$src" "$dst"
done

log "✅ Dotfiles instalados"
