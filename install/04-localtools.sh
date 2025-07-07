#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Función de log
log() {
  echo "[04-locatools] $*"
}

# Directorio de archivos
FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"

# Me aseguro de que existe el directorio de los binarios del
# usuario ($BIN_DIR definido en env.sh)
if [[ ! -d "$BIN_DIR" ]]; then
  log "Creando $BIN_DIR"
  mkdir -p "$BIN_DIR"
fi

# Copiar herramientas al directorio de los binarios
for tool in e confcat s; do
  src="$FILES_DIR/bin/$tool"
  dst="$BIN_DIR/$tool"

  log "Instalando $tool en $dst"
  cp -f "$src" "$dst"
  chmod 755 "$dst"
done

# Configuración y directorios dependientes del sistema operativo
case "${OS_TYPE:-}" in
  linux|wsl2)
    log "Instalando configuración personalizada de nano en /etc/nanorc"
    sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc

    log "Creando /root/.nano"
    sudo mkdir -p /root/.nano
    ;;

  macos)
    log "macOS detectado: se omite configuración de /etc/nanorc y /root/.nano"
    ;;

  *)
    log "Sistema no soportado: omitiendo configuración específica de nano"
    ;;
esac

# Crear directorio local de nano (común a todos)
log "Creando ~/.nano"
mkdir -p "$HOME/.nano"

log "✅ Herramientas locales instaladas"