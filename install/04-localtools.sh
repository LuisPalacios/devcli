#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[04-localtools] $*"
}

FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"
BIN_TARGET="$HOME/bin"

# Asegura que el directorio de destino existe
mkdir -p "$BIN_TARGET"

# Copiar herramientas a $HOME/bin
for tool in e confcat s; do
  src="$FILES_DIR/bin/$tool"
  dst="$BIN_TARGET/$tool"

  log "Instalando $tool en $dst"
  cp -f "$src" "$dst"
  chmod 755 "$dst"
done

# Configuración de nano (solo en Linux y WSL2)
if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "wsl2" ]]; then
  log "Instalando configuración personalizada de nano en /etc/nanorc"
  sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc
fi

# Crear directorios .nano
log "Creando ~/.nano"
mkdir -p "$HOME/.nano"

if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "wsl2" ]]; then
  log "Creando /root/.nano"
  sudo mkdir -p /root/.nano
fi

log "✅ Herramientas locales instaladas"
