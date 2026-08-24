#!/usr/bin/env bash
# -------------------------------------------------------------------
# env.sh - Variables y entorno compartido para scripts de instalación
# -------------------------------------------------------------------

# URL del repositorio
export REPO_URL="https://github.com/LuisPalacios/devcli.git"

# Rama del repositorio
export BRANCH="main"

# Usuario actual
export CURRENT_USER="$(id -un)"

# Directorio de instalación
export SETUP_DIR="$HOME/.devcli"

# Binarios de usuario
export BIN_DIR="$HOME/bin"

# Idioma y locale
export SETUP_LANG="es_ES.UTF-8"

# Configuración de Nerd Fonts
export NERD_FONT_NAME="FiraCode"
export NERD_FONT_FULL_NAME="FiraCode Nerd Font"

# Función para detectar el usuario actual de forma dinámica
detect_current_user() {
  # Priorizar variables de entorno comunes
  if [[ -n "${SUDO_USER:-}" ]]; then
    export CURRENT_USER="$SUDO_USER"
  elif [[ -n "${USER:-}" ]]; then
    export CURRENT_USER="$USER"
  else
    export CURRENT_USER="$(id -un)"
  fi
}

# Detección de sistema operativo compatible
# Establece OS_TYPE: macos, wsl2, linux, other
# Aborta si no es compatible
detect_os_type() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    export OS_TYPE="wsl2"
  elif [[ "$OSTYPE" == darwin* ]]; then
    export OS_TYPE="macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    export OS_TYPE="linux"
  else
    echo "[env.sh] ❌ Sistema operativo no soportado: $OSTYPE"
    export OS_TYPE="other"
    exit 1
  fi
}

# Detección de entorno de escritorio (para herramientas GUI como WezTerm)
# IS_DESKTOP=true  → tiene sentido instalar aplicaciones gráficas
# IS_DESKTOP=false → equipo headless (o WSL2): se omiten las herramientas
#                    marcadas con "requires_desktop" en tools.json
detect_desktop_environment() {
  case "$OS_TYPE" in
    macos)
      IS_DESKTOP=true
      ;;
    linux)
      IS_DESKTOP=false
      # 1. Sesión gráfica activa (X11 o Wayland)
      if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        IS_DESKTOP=true
      # 2. Algún entorno de escritorio instalado (aunque entremos por SSH)
      elif ls /usr/share/xsessions/*.desktop >/dev/null 2>&1 \
        || ls /usr/share/wayland-sessions/*.desktop >/dev/null 2>&1; then
        IS_DESKTOP=true
      # 3. Hay un display manager configurado (gdm, sddm, lightdm…).
      #    OJO: no usar `systemctl get-default` — Debian trae graphical.target
      #    por defecto incluso en servidores headless (falso positivo).
      elif [[ -e /etc/systemd/system/display-manager.service ]]; then
        IS_DESKTOP=true
      fi
      ;;
    *)
      # wsl2 y otros: sin escritorio nativo donde instalar apps GUI
      IS_DESKTOP=false
      ;;
  esac
  export IS_DESKTOP
}

# Detección de usuario root
detect_root_user() {
  if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
  else
    IS_ROOT=false
  fi
}

# Ejecutar detecciones al cargar
detect_current_user
detect_os_type
detect_desktop_environment
detect_root_user
