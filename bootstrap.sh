#!/usr/bin/env bash
#
set -euo pipefail

# Variables básicas para bootstrap (sin cargar env.sh)
REPO_URL="https://github.com/LuisPalacios/devcli.git"
BRANCH="main"
CURRENT_USER="$(id -un)"
SETUP_DIR="$HOME/.devcli"

# Función de log minimalista
log() {
  echo "[bootstrap] $*"
}

# Función de ayuda
show_help() {
  cat << EOF
Linux Setup - Configuración automatizada de entorno CLI

Uso: bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) [OPCIONES]

OPCIONES:
  -l, --lang LOCALE     Configurar idioma (ej: en_US.UTF-8, es_ES.UTF-8)
  -h, --help           Mostrar esta ayuda

EJEMPLOS:
  # Instalación con idioma por defecto (español)
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)

  # Instalación con idioma inglés
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -l en_US.UTF-8

  # Instalación con idioma francés
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -l fr_FR.UTF-8

IDIOMAS SOPORTADOS:
  es_ES.UTF-8 (español, por defecto)
  en_US.UTF-8 (inglés)
  :
EOF
}

# Procesar argumentos de línea de comandos
SETUP_LANG="es_ES.UTF-8"  # Valor por defecto

while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--lang)
      SETUP_LANG="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Error: Opción desconocida '$1'"
      echo "Usa -h o --help para ver las opciones disponibles"
      exit 1
      ;;
  esac
done

# Validar formato de locale
if [[ ! "$SETUP_LANG" =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]]; then
  echo "Error: Formato de locale inválido. Usa formato: ll_CC.UTF-8"
  echo "Ejemplo: es_ES.UTF-8, en_US.UTF-8"
  exit 1
fi

# Detección básica de sistema operativo (sin env.sh)
detect_os_type() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    OS_TYPE="wsl2"
  elif [[ "$OSTYPE" == darwin* ]]; then
    OS_TYPE="macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    OS_TYPE="linux"
  else
    echo "[bootstrap] ❌ Sistema operativo no soportado: $OSTYPE"
    exit 1
  fi
}

# Ejecutar detección
detect_os_type

# Preparación del entorno
log "Preparando entorno en $OS_TYPE (idioma: $SETUP_LANG)..."

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

# Instalar curl si es necesario (silencioso)
if ! command -v curl &>/dev/null; then
  log "Instalando curl..."
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq >/dev/null 2>&1
      sudo apt-get install -y -qq curl >/dev/null 2>&1
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "[bootstrap] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install curl >/dev/null 2>&1
      ;;
    *)
      log "❌ No se pudo instalar curl automáticamente."
      exit 1
      ;;
  esac
fi

# Instalar git si es necesario (silencioso)
if ! command -v git &>/dev/null; then
  log "Instalando git..."
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq >/dev/null 2>&1
      sudo apt-get install -y -qq git >/dev/null 2>&1
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "[bootstrap] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install git >/dev/null 2>&1
      ;;
    *)
      log "❌ No se pudo instalar git automáticamente."
      exit 1
      ;;
  esac
fi

# Clona o actualiza el repo (completamente silencioso)
if [[ -d "$SETUP_DIR" ]]; then
  rm -fr "$SETUP_DIR"
fi
git clone --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR" >/dev/null 2>&1

# Dar permisos de ejecución a todos los scripts de instalación
chmod +x "$SETUP_DIR/install"/*.sh >/dev/null 2>&1

# Ejecutar scripts de instalación
cd "$SETUP_DIR/install"

# Exportar SETUP_LANG para que los scripts lo usen
export SETUP_LANG

# Ejecuta la instalación por fases (silenciosa)
log "Ejecutando scripts de instalación:"
for f in [0-9][0-9]-*.sh; do
  if [[ -f "$f" ]]; then
    log "▶ Ejecutando $f"
    "./$f"
  fi
done

log "✅ Instalación completada"
