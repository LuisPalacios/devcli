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
  -p, --profile PROFILE  Perfil de instalación: server, minimal, dev, full
  -n, --dry-run          Simulación: lista lo que haría (paquetes, repositorios,
                         descargas, ficheros) sin cambiar nada (Linux, macOS, WSL2)
      --diag             Con -p server: añade tcpdump, iperf3 y socat
  -r, --reclone          Forzar descarga limpia del repo (borra ~/.devcli y vuelve a clonar)
  -v, --verbose          Mostrar todo el output bruto de las herramientas (apt, scoop, curl…)
  -k, --custom-keys MODO Atajos estilo Mac: on, off, force (sólo Windows, desde Git Bash)
  -h, --help             Mostrar esta ayuda

PERFILES:
  server    Servidores (Linux/WSL2): sólo paquetes del repositorio oficial
            (git, curl, jq, ca-certificates, vim, tmux, htop, ripgrep, zsh)
            y los dotfiles. Sin repositorios de terceros, sin descargas fuera
            de apt, sin tocar /etc ni la shell de inicio.
  minimal   Herramientas esenciales (htop, fzf, lsd, ripgrep, bat, fd, ...)
  dev       minimal + herramientas de desarrollo (mkcert, pnpm, uv, ...)
  full      Todas las herramientas

  Sin -p: full en macOS, WSL2 y Windows. En Linux nativo, full sólo si hay
  una sesión gráfica local (no por SSH); si no, pregunta (Enter = server) o,
  sin terminal, aplica server. En servidores, usa siempre -p server.

EJEMPLOS:
  # Servidor: simular primero, luego instalar
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p server -n
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p server

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
# Vacío = no indicado: se resuelve tras detectar el sistema (resolve_profile).
DEVCLI_PROFILE="${DEVCLI_PROFILE:-}"
DEVCLI_RECLONE="${DEVCLI_RECLONE:-0}"
DEVCLI_VERBOSE="${DEVCLI_VERBOSE:-0}"
DEVCLI_DIAG="${DEVCLI_DIAG:-0}"
DEVCLI_DRY_RUN="${DEVCLI_DRY_RUN:-0}"
LANG_GIVEN=0
CUSTOM_KEYS=""
PROFILE_NOTE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--lang|-k|--custom-keys|-p|--profile)
      if [[ $# -lt 2 ]]; then
        echo "Error: $1 necesita un valor"
        echo "Usa -h o --help para ver las opciones disponibles"
        exit 1
      fi
      ;;
  esac
  case $1 in
    -l|--lang)
      SETUP_LANG="$2"
      LANG_GIVEN=1
      shift 2
      ;;
    -k|--custom-keys)
      CUSTOM_KEYS="$2"
      shift 2
      ;;
    -p|--profile)
      DEVCLI_PROFILE="$2"
      shift 2
      ;;
    -n|--dry-run)
      DEVCLI_DRY_RUN=1
      shift
      ;;
    --diag)
      DEVCLI_DIAG=1
      shift
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

# Se validan aquí porque en Windows acaban dentro de un comando de PowerShell.
case "$DEVCLI_PROFILE" in
  ""|server|minimal|dev|full) ;;
  *) echo "Error: perfil inválido '$DEVCLI_PROFILE' (server, minimal, dev, full)"; exit 1 ;;
esac
case "$CUSTOM_KEYS" in
  ""|on|off|force) ;;
  *) echo "Error: -k admite on, off o force (recibido: '$CUSTOM_KEYS')"; exit 1 ;;
esac
# El perfil server sólo existe para Linux (incluido WSL2): instala con apt.
if [[ "$DEVCLI_PROFILE" == "server" && "$OSTYPE" != linux* ]]; then
  echo "Error: el perfil server sólo está disponible en Linux (Debian y derivados) y WSL2."
  exit 1
fi
if [[ "$DEVCLI_DIAG" == 1 && "$DEVCLI_PROFILE" != "server" ]]; then
  echo "Error: --diag sólo tiene sentido con -p server."
  exit 1
fi
if [[ "$DEVCLI_DRY_RUN" == 1 && ( "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ) ]]; then
  echo "Error: la simulación (-n) sólo está disponible en Linux, macOS y WSL2."
  exit 1
fi

# Git Bash: delega en bootstrap.ps1 (PowerShell 7) traduciendo las opciones.
#
# bootstrap.ps1 se descarga del commit exacto de main, no de main: la CDN de
# raw.githubusercontent.com guarda cada URL hasta 5 minutos y un parámetro
# ?query no la salta, así que justo después de un push «main» puede servir la
# versión anterior. git ls-remote pregunta a GitHub directamente; si falla se
# usa main como antes.
delegate_to_pwsh() {
  local ref sha url ps_args
  sha="$(GIT_TERMINAL_PROMPT=0 timeout 20 git ls-remote "$REPO_URL" "refs/heads/$BRANCH" 2>/dev/null | cut -f1)" || sha=""
  if [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then ref="$sha"; else ref="$BRANCH"; fi
  url="https://raw.githubusercontent.com/LuisPalacios/devcli/$ref/bootstrap.ps1"

  ps_args="-Profile ${DEVCLI_PROFILE:-full}"
  if [[ "$LANG_GIVEN" == 1 ]]; then
    local ps_lang="${SETUP_LANG%%.*}"   # es_ES.UTF-8 → es_ES
    ps_args="$ps_args -Lang ${ps_lang/_/-}"   # → es-ES
  fi
  [[ "$DEVCLI_RECLONE" == 1 ]] && ps_args="$ps_args -Reclone"
  [[ "$DEVCLI_VERBOSE" == 1 ]] && ps_args="$ps_args -Verbose"
  [[ -n "$CUSTOM_KEYS" ]] && ps_args="$ps_args -CustomKeys $CUSTOM_KEYS"

  # Limpiar variables MSYS2 que pueden interferir con git.exe en PowerShell
  unset MSYSTEM MINGW_PREFIX MSYSTEM_PREFIX MSYSTEM_CHOST MSYSTEM_CTYPE
  unset ORIGINAL_PATH ORIGINAL_TEMP ORIGINAL_TMP
  # Como scriptblock y no con iex, para que los parámetros se enlacen de verdad.
  exec pwsh -NoProfile -Command "& ([scriptblock]::Create((Invoke-RestMethod '$url'))) $ps_args"
}

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
    delegate_to_pwsh
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

# Sesión gráfica local: la única señal que se acepta como «equipo personal».
# Por SSH no cuenta (DISPLAY puede venir del reenvío de X11). No se usan
# paquetes gráficos instalados (hay servidores que los tienen), ni la
# virtualización (servidores y VM de desarrollo son igual de virtuales).
_local_graphical_session() {
  [[ -n "${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-}" ]] && return 1
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]] && return 0
  case "${XDG_SESSION_TYPE:-}" in
    x11|wayland) return 0 ;;
  esac
  return 1
}

# Pregunta el perfil por la terminal. Enter (o fin de entrada) = server.
_ask_profile() {
  local ans
  {
    echo
    echo "No puedo confirmar que esta máquina sea un equipo personal (no hay sesión gráfica local)."
    echo "En un servidor usa siempre el perfil «server»: sólo paquetes del repositorio oficial,"
    echo "sin repositorios de terceros ni descargas fuera de apt, sin tocar /etc."
  } >/dev/tty
  while :; do
    printf "Perfil [server/minimal/dev/full] (Enter = server): " >/dev/tty
    IFS= read -r ans </dev/tty || ans=""
    case "$ans" in
      ""|server)        DEVCLI_PROFILE="server"; break ;;
      minimal|dev|full) DEVCLI_PROFILE="$ans"; break ;;
      *) echo "Respuesta no válida: '$ans'" >/dev/tty ;;
    esac
  done
  PROFILE_NOTE=" (elegido al preguntar)"
}

# Perfil cuando no se ha indicado con -p ni DEVCLI_PROFILE: seguro por
# defecto. full sólo donde la máquina es personal con certeza razonable.
resolve_profile() {
  [[ -n "$DEVCLI_PROFILE" ]] && return 0
  case "$OS_TYPE" in
    macos|wsl2)
      DEVCLI_PROFILE="full"
      return 0
      ;;
  esac
  if _local_graphical_session; then
    DEVCLI_PROFILE="full"
    PROFILE_NOTE=" (automático: sesión gráfica local)"
  elif ( : </dev/tty ) 2>/dev/null; then
    _ask_profile
  else
    DEVCLI_PROFILE="server"
    PROFILE_NOTE=" (automático: sin sesión gráfica local ni terminal)"
  fi
}

# Ejecutar detección
detect_os_type
detect_root_user
resolve_profile

if [[ -n "$CUSTOM_KEYS" ]]; then
  echo "Aviso: -k/--custom-keys sólo aplica en Windows; se ignora."
fi

# Modo simulación: las notas de lo que se haría van a un directorio temporal
# que se borra al salir (también el clon del repo, si hace falta uno).
DRY_DIR=""
if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then
  DRY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/devcli-simulacion.XXXXXX")" || { echo "Error: no se pudo crear el directorio temporal"; exit 1; }
  trap '[ -n "$DRY_DIR" ] && [ -d "$DRY_DIR" ] && rm -rf "$DRY_DIR"' EXIT
  DEVCLI_DRY_RUN_FILE="$DRY_DIR/notas.tsv"
  : >"$DEVCLI_DRY_RUN_FILE"
  export DEVCLI_DRY_RUN DEVCLI_DRY_RUN_FILE
fi

# Igual que dry_note de utils.sh (aquí todavía no está cargado).
_bs_dry_note() {
  printf '%s\t%s\n' "$1" "$2" >>"$DEVCLI_DRY_RUN_FILE"
}

# `sudo bash bootstrap.sh` sin cambiar HOME (macOS, o sudoers con env_keep)
# instalaría como root dentro del home de otro usuario: ficheros de root en
# su $HOME. Root de verdad (login, `sudo -i`, Ubuntu/Debian, que fijan
# HOME=/root) sí está soportado.
ROOT_HOME=~root
if [[ "$IS_ROOT" == true && -n "${SUDO_USER:-}" && "$HOME" != "$ROOT_HOME" ]]; then
  echo "No ejecutes el bootstrap con sudo: lánzalo como el usuario a configurar (HOME=$HOME)."
  exit 1
fi

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
  if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then
    _bs_dry_note aviso "sudo no está instalado o '$CURRENT_USER' no tiene acceso sin contraseña: la ejecución real se pararía aquí"
  else
    echo "sudo no está instalado o el usuario '$CURRENT_USER' no tiene acceso sin contraseña."
    exit 1
  fi
fi

# ca-certificates no es un comando: se comprueba como paquete.
_prereq_present() {
  case "$1" in
    ca-certificates) dpkg -s ca-certificates >/dev/null 2>&1 ;;
    *) command -v "$1" >/dev/null 2>&1 ;;
  esac
}

# Instala un prereq silenciosamente vía apt (Linux/WSL2) o brew (macOS).
# Idempotente. Aborta si brew no está en macOS o si la plataforma no es
# soportada. Bootstrap necesita estos prereqs antes de poder clonar el repo
# y cargar utils.sh, por eso viven aquí en lugar de en 01-system.
_install_prereq() {
  local pkg="$1"
  if _prereq_present "$pkg"; then
    [[ "$DEVCLI_DRY_RUN" == 1 ]] && _bs_dry_note presente "$pkg"
    return 0
  fi
  if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then
    case "${OS_TYPE:-}" in
      macos) _bs_dry_note brew "$pkg (prerrequisito del bootstrap)" ;;
      *)     _bs_dry_note apt "$pkg (prerrequisito del bootstrap)" ;;
    esac
    return 0
  fi
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq >/dev/null 2>&1
      if [[ "$DEVCLI_PROFILE" == "server" ]]; then
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$pkg" >/dev/null 2>&1
      else
        sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1
      fi
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

# Perfil server: sin unzip (sólo lo usan las fuentes) y con ca-certificates
# (con --no-install-recommends un Debian mínimo se quedaría sin HTTPS).
if [[ "$DEVCLI_PROFILE" == "server" ]]; then
  _install_prereq ca-certificates
  _install_prereq curl
  _install_prereq jq
  _install_prereq git
else
  _install_prereq curl
  _install_prereq unzip
  _install_prereq jq
  _install_prereq git
fi

# La simulación necesita git (clonar) y jq (leer la configuración). Si
# faltan, se dice qué instalaría y se para.
if [[ "$DEVCLI_DRY_RUN" == 1 ]] && { ! command -v git >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; }; then
  echo "Simulación incompleta: faltan git y/o jq, necesarios para leer la configuración."
  echo "Hasta aquí, el bootstrap haría esto:"
  awk -F'\t' '{ printf "  - [%s] %s\n", $1, $2 }' "$DEVCLI_DRY_RUN_FILE"
  echo "Instálalos (p.ej. sudo apt install git jq) y repite la simulación."
  exit 0
fi

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

if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then
  # Simulación: ~/.devcli no se toca. Si el bootstrap se lanza desde una
  # copia del repo se usa esa; si no (bash <(curl …)), un clon temporal.
  if [[ "$DEVCLI_RECLONE" == "1" || ! -d "$SETUP_DIR/.git" ]]; then
    _bs_dry_note home "copia del repo en \$HOME/.devcli/ (git clone) e install.log"
  else
    _bs_dry_note home "copia del repo en \$HOME/.devcli/ (git fetch + reset --hard) e install.log"
  fi
  _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || _self_dir=""
  if [[ -n "$_self_dir" && -f "$_self_dir/install/utils.sh" && -f "$_self_dir/install/tools.json" ]]; then
    SETUP_DIR="$_self_dir"
  else
    SETUP_DIR="$DRY_DIR/devcli"
    if ! git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR" >/dev/null 2>&1; then
      echo "Error: no se pudo clonar $REPO_URL para la simulación."
      exit 1
    fi
  fi
elif [[ "$DEVCLI_RECLONE" == "1" ]]; then
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

# Dar permisos de ejecución a todos los scripts de instalación (en
# simulación no: las fases se lanzan con bash y la copia no se modifica).
[[ "$DEVCLI_DRY_RUN" == 1 ]] || chmod +x "$SETUP_DIR/install"/*.sh >/dev/null 2>&1

# Ejecutar scripts de instalación
cd "$SETUP_DIR/install"

# Exportar variables para que los scripts las usen
export SETUP_LANG
export DEVCLI_PROFILE
export DEVCLI_VERBOSE
export DEVCLI_DIAG

# Cargar la capa UX y arrancar la sesión visual.
# shellcheck disable=SC1091
source "$SETUP_DIR/install/utils.sh"
if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then
  ux_init "$DRY_DIR/install.log"
else
  ux_init "$HOME/.devcli/install.log"
fi

# IS_DESKTOP para el aviso final de WezTerm en ux_summary. No se puede cargar
# env.sh entero aquí (pisaría SETUP_LANG del flag -l), así que se deriva en
# un subshell. Si algo falla, se asume escritorio (comportamiento previo).
IS_DESKTOP="$(source "$SETUP_DIR/install/env.sh" >/dev/null 2>&1; echo "${IS_DESKTOP:-true}")" || true
IS_DESKTOP="${IS_DESKTOP:-true}"
export IS_DESKTOP

# Etiqueta amigable para el banner.
case "$OS_TYPE" in
  wsl2)  os_label="WSL2 (Ubuntu)" ;;
  macos) os_label="macOS" ;;
  linux) os_label="Linux" ;;
  *)     os_label="$OS_TYPE" ;;
esac
banner_profile="$DEVCLI_PROFILE"
[[ "$DEVCLI_DIAG" == 1 ]] && banner_profile="$banner_profile + diag"
banner_profile="$banner_profile$PROFILE_NOTE"
[[ "$DEVCLI_DRY_RUN" == 1 ]] && banner_profile="$banner_profile · SIMULACIÓN"
ux_banner "$os_label" "$banner_profile"

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
  if [[ "$DEVCLI_DRY_RUN" == 1 ]]; then run=(bash "./$f"); else run=("./$f"); fi
  if "${run[@]}"; then
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
