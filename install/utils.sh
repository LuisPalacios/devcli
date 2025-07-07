#!/usr/bin/env bash
# -------------------------------------------------------------------
# utils.sh - Utilidades compartidas para scripts de instalación
# -------------------------------------------------------------------

# Función de log con timestamp
log() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$(date '+%H:%M:%S')] [$script_name] $*"
}

# Función de log simple (para compatibilidad)
log_simple() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] $*"
}

# Función de log silencioso (solo errores y warnings)
log_quiet() {
  # Esta función no hace nada - para hacer scripts silenciosos
  :
}

# Función para mostrar errores importantes
error() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ❌ $*" >&2
}

# Función para mostrar warnings importantes
warning() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ⚠️ $*" >&2
}

# Función para mostrar éxito final
success() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ✅ $*"
}

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (Linux/WSL2)
package_installed_apt() {
  dpkg -s "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (macOS)
package_installed_brew() {
  brew list --formula "$1" &>/dev/null
}

# Función para instalar paquete según OS (silenciosa)
install_package() {
  local pkg="$1"

  case "${OS_TYPE:-}" in
    linux|wsl2)
      if ! package_installed_apt "$pkg"; then
        # Intentar instalar con manejo de errores
        if ! sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
          warning "No se pudo instalar $pkg - continuando..."
          return 1
        fi
      fi
      ;;
    macos)
      if ! package_installed_brew "$pkg"; then
        if ! brew install "$pkg" >/dev/null 2>&1; then
          warning "No se pudo instalar $pkg - continuando..."
          return 1
        fi
      fi
      ;;
    *)
      error "OS_TYPE no soportado para instalación: $OS_TYPE"
      return 1
      ;;
  esac
}

# Función para crear directorio si no existe
ensure_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" >/dev/null 2>&1
  fi
}

# Función para verificar permisos sudo
check_sudo_access() {
  if ! sudo -n true 2>/dev/null; then
    error "El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
    exit 1
  fi
}

# Función para actualizar repositorios según OS (silenciosa)
update_package_manager() {
  case "${OS_TYPE:-}" in
    linux|wsl2)
      if ! sudo apt-get update -y -qq >/dev/null 2>&1; then
        warning "No se pudo actualizar repositorios - continuando..."
        return 1
      fi
      ;;
    macos)
      # Homebrew se actualiza automáticamente
      ;;
    *)
      error "OS_TYPE no soportado para actualización: $OS_TYPE"
      return 1
      ;;
  esac
}

# Función para contar paquetes instalados
count_installed_packages() {
  local count=0
  for pkg in "$@"; do
    case "${OS_TYPE:-}" in
      linux|wsl2)
        if package_installed_apt "$pkg"; then
          count=$((count + 1))
        fi
        ;;
      macos)
        if package_installed_brew "$pkg"; then
          count=$((count + 1))
        fi
        ;;
    esac
  done
  echo "$count"
}
