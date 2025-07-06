#!/bin/bash
set -euo pipefail

log() {
  echo "[02-packages] $*"
}

# Asegura que sudo funcione sin contraseña
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

log "Instalando herramientas comunes..."

COMMON_PACKAGES=(
  htop
  tmux
  fzf
  bat
  fd-find
  ripgrep
  tree
  lsd
)

for pkg in "${COMMON_PACKAGES[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg ya está instalado"
  else
    log "Instalando $pkg..."
    sudo apt-get install -y -qq "$pkg"
  fi
done

# Symlink fd (en Debian/Ubuntu se instala como fdfind)
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
  log "Creando alias fd → fdfind"
  ln -sf "$(command -v fdfind)" "$HOME/bin/fd"
fi

log "✅ Paquetes adicionales instalados"
