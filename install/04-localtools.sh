#!/bin/bash
set -euo pipefail

log() {
  echo "[04-localtools] $*"
}

FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"

# Ejecutables → /usr/bin/
for tool in e confcat s; do
  src="$FILES_DIR/bin/$tool"
  dst="/usr/bin/$tool"

  log "Instalando $tool en $dst"
  sudo cp -f "$src" "$dst"
  sudo chmod 755 "$dst"
done

# Configuración de nano
log "Instalando configuración personalizada de nano"
sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc

# Crear directorios .nano
log "Creando ~/.nano y /root/.nano si no existen"
mkdir -p "$HOME/.nano"
sudo mkdir -p /root/.nano

log "✅ Herramientas locales instaladas"
