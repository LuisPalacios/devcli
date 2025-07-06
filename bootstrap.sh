#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/LuisPalacios/linux-setup.git"
SETUP_DIR="$HOME/.linux-setup"
BRANCH="main"

log() {
  echo "[bootstrap] $*"
}

# Comprueba que git esté instalado
if ! command -v git &>/dev/null; then
  log "git no está instalado. Intentando instalar..."

  if [[ -f /etc/debian_version ]]; then
    sudo apt-get update -y
    sudo apt-get install -y git
  else
    log "❌ No se pudo instalar git automáticamente. Instálalo manualmente e intenta de nuevo."
    exit 1
  fi
else
  log "git ya está instalado"
fi

# Clona o actualiza el repo
if [[ -d "$SETUP_DIR" ]]; then
  log "Actualizando repo en $SETUP_DIR"
  git -C "$SETUP_DIR" pull
else
  log "Clonando repo en $SETUP_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR"
fi

cd "$SETUP_DIR/install"

# Ejecuta la instalación por fases
log "Ejecutando scripts de instalación"
for f in 0*.sh; do
  chmod +x "$f"
  log "▶ Ejecutando $f"
  "./$f"
done

log "✅ Instalación completada"
