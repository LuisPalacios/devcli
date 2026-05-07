#!/usr/bin/env bash
#
set -euo pipefail

# Variables básicas para bootstrap (sin cargar env.sh)
REPO_URL="https://github.com/LuisPalacios/devcli.git"
BRANCH="main"
CURRENT_USER="$(id -un)"
SETUP_DIR="$HOME/.devcli"

# Mensajes pre-banner (antes de que la capa UX esté disponible). Sin prefijo,
# silencioso por defecto — sólo emiten cuando hay algo que el usuario debe ver
# (instalación de prerrequisitos, errores, redirección a PowerShell).
log() {
  echo "$*"
}

# Función de ayuda
show_help() {
  cat << EOF
Linux Setup - Configuración automatizada de entorno CLI

Uso: bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) [OPCIONES]

OPCIONES:
  -l, --lang LOCALE      Configurar idioma (ej: en_US.UTF-8, es_ES.UTF-8)
  -p, --profile PROFILE  Perfil de instalación: minimal, dev, full (defecto: full)
  -r, --reclone          Forzar descarga limpia del repo (borra ~/.devcli y vuelve a clonar)
  -v, --verbose          Mostrar todo el output bruto de las herramientas (apt, scoop, curl…)
  -h, --help             Mostrar esta ayuda

PERFILES:
  minimal   Herramientas esenciales (htop, fzf, lsd, ripgrep, bat, fd, ...)
  dev       minimal + herramientas de desarrollo (mkcert, pnpm, uv, ...)
  full      Todas las herramientas (defecto)

EJEMPLOS:
  # Instalación completa con idioma por defecto (español)
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)

  # Instalación mínima
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p minimal

  # Instalación dev con idioma inglés
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p dev -l en_US.UTF-8

IDIOMAS SOPORTADOS:
  es_ES.UTF-8 (español, por defecto)
  en_US.UTF-8 (inglés)
  :
EOF
}

# Procesar argumentos de línea de comandos
SETUP_LANG="es_ES.UTF-8"  # Valor por defecto
DEVCLI_PROFILE="${DEVCLI_PROFILE:-full}"  # Valor por defecto
DEVCLI_RECLONE="${DEVCLI_RECLONE:-0}"
DEVCLI_VERBOSE="${DEVCLI_VERBOSE:-0}"

while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--lang)
      SETUP_LANG="$2"
      shift 2
      ;;
    -p|--profile)
      DEVCLI_PROFILE="$2"
      shift 2
      ;;
    -r|--reclone)
      DEVCLI_RECLONE=1
      shift
      ;;
    -v|--verbose)
      DEVCLI_VERBOSE=1
      shift
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
  elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    # Git Bash en Windows (MINGW64 x64 o CLANGARM64 en ARM): delegar a PowerShell 7 (bootstrap.ps1)
    if ! command -v pwsh &>/dev/null; then
      echo "❌ PowerShell 7 (pwsh) es necesario en Windows."
      echo "   Instálalo desde: https://github.com/PowerShell/PowerShell/releases"
      exit 1
    fi
    echo "Detectado Git Bash — delegando a PowerShell 7..."
    # Limpiar variables MSYS2 que pueden interferir con git.exe en PowerShell
    unset MSYSTEM MINGW_PREFIX MSYSTEM_PREFIX MSYSTEM_CHOST MSYSTEM_CTYPE
    unset ORIGINAL_PATH ORIGINAL_TEMP ORIGINAL_TMP
    exec pwsh -NoProfile -Command 'iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")'
  elif [[ "$OSTYPE" == darwin* ]]; then
    OS_TYPE="macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    OS_TYPE="linux"
  else
    echo "❌ Sistema operativo no soportado: $OSTYPE"
    exit 1
  fi
}

# Detección de usuario root
detect_root_user() {
  if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
  else
    IS_ROOT=false
  fi
}

# Ejecutar detección
detect_os_type
detect_root_user

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
  echo "sudo no está instalado o el usuario '$CURRENT_USER' no tiene acceso sin contraseña."
  exit 1
fi

# Instala un prereq silenciosamente vía apt (Linux/WSL2) o brew (macOS).
# Idempotente. Aborta si brew no está en macOS o si la plataforma no es
# soportada. Bootstrap necesita estos prereqs antes de poder clonar el repo
# y cargar utils.sh, por eso viven aquí en lugar de en 01-system.
_install_prereq() {
  local pkg="$1"
  command -v "$pkg" >/dev/null 2>&1 && return 0
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq >/dev/null 2>&1
      sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install "$pkg" >/dev/null 2>&1
      ;;
    *)
      echo "❌ No se pudo instalar $pkg automáticamente."
      exit 1
      ;;
  esac
}

_install_prereq curl
_install_prereq unzip
_install_prereq jq
_install_prereq git

# Sincroniza el repo. Por defecto: fetch + reset --hard (rápido, idempotente,
# descarta ediciones locales como hacía la rama antigua de rm -fr + clone).
# Con --reclone se fuerza el borrado y reclonado completo.
clone_repo_fresh() {
  [[ -d "$SETUP_DIR" ]] && rm -fr "$SETUP_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR" >/dev/null 2>&1
}

update_repo_in_place() {
  git -C "$SETUP_DIR" fetch --quiet origin "$BRANCH" >/dev/null 2>&1 || return 1
  git -C "$SETUP_DIR" reset --hard "origin/$BRANCH" --quiet >/dev/null 2>&1 || return 1
}

if [[ "$DEVCLI_RECLONE" == "1" ]]; then
  echo "Descarga limpia solicitada (--reclone)..."
  clone_repo_fresh
elif [[ -d "$SETUP_DIR/.git" ]]; then
  if ! update_repo_in_place; then
    echo "Actualización del repo falló — descargando desde cero..."
    clone_repo_fresh
  fi
else
  clone_repo_fresh
fi

# Dar permisos de ejecución a todos los scripts de instalación
chmod +x "$SETUP_DIR/install"/*.sh >/dev/null 2>&1

# Ejecutar scripts de instalación
cd "$SETUP_DIR/install"

# Exportar variables para que los scripts las usen
export SETUP_LANG
export DEVCLI_PROFILE
export DEVCLI_VERBOSE

# Cargar la capa UX y arrancar la sesión visual.
# shellcheck disable=SC1091
source "$SETUP_DIR/install/utils.sh"
ux_init "$HOME/.devcli/install.log"

# Etiqueta amigable para el banner.
case "$OS_TYPE" in
  wsl2)  os_label="WSL2 (Ubuntu)" ;;
  macos) os_label="macOS" ;;
  linux) os_label="Linux" ;;
  *)     os_label="$OS_TYPE" ;;
esac
ux_banner "$os_label" "$DEVCLI_PROFILE"

# Contar las fases para pasar PHASE_NUM/PHASE_TOTAL a cada una.
PHASE_FILES=( [0-9][0-9]-*.sh )
PHASE_TOTAL=${#PHASE_FILES[@]}
export PHASE_TOTAL

# Tally de resultados: una fase puede salir con 0 (ok), 1 (warn), 2+ (fail).
BS_OK=0; BS_WARN=0; BS_FAIL=0
PHASE_NUM=0
for f in "${PHASE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  PHASE_NUM=$((PHASE_NUM + 1))
  export PHASE_NUM
  if "./$f"; then
    BS_OK=$((BS_OK + 1))
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      BS_WARN=$((BS_WARN + 1))
    else
      BS_FAIL=$((BS_FAIL + 1))
    fi
  fi
done

ux_summary "$BS_OK" "$BS_WARN" "$BS_FAIL"
