#!/bin/bash
# Instalador ligero de ble.sh (autosugerencias + resaltado de sintaxis para
# Git Bash). No hay paquete scoop/apt/brew para ble.sh: se descarga el
# tarball de release y se extrae en ~/.local/share/blesh.
# Uso: blesh-install.sh
# Idempotente: si ~/.local/share/blesh/ble.sh ya existe, no hace nada.

set -e

BLESH_VERSION="0.3.4"
BLESH_DIR="$HOME/.local/share/blesh"
BLESH_URL="https://github.com/akinomyoga/ble.sh/releases/download/v${BLESH_VERSION}/ble-${BLESH_VERSION}.tar.xz"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -f "$BLESH_DIR/ble.sh" ]]; then
    exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo -e "${RED}✗ blesh-install: se requieren curl y tar${NC}" >&2
    exit 1
fi

echo -e "${YELLOW}Instalando ble.sh v${BLESH_VERSION} (primera vez, sólo tarda unos segundos)...${NC}"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

if ! curl -fsSL -o "$tmp_dir/ble.tar.xz" "$BLESH_URL"; then
    echo -e "${RED}✗ blesh-install: error al descargar $BLESH_URL${NC}" >&2
    exit 1
fi

if ! tar xf "$tmp_dir/ble.tar.xz" -C "$tmp_dir"; then
    echo -e "${RED}✗ blesh-install: error al extraer el tarball${NC}" >&2
    exit 1
fi

mkdir -p "$(dirname "$BLESH_DIR")"
rm -rf "$BLESH_DIR"
mv "$tmp_dir/ble-${BLESH_VERSION}" "$BLESH_DIR"

echo -e "${GREEN}✓ ble.sh instalado en $BLESH_DIR${NC}"
