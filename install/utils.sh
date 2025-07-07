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


# Función para instalar lsd desde GitHub releases
install_lsd() {
  # Verificar si lsd ya está instalado
  if command_exists lsd; then
    #log "lsd ya está instalado, omitiendo instalación"
    return 0
  fi

  local version="1.1.5"
  local arch

  # Detectar arquitectura
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      warning "Arquitectura no soportada para lsd: $(uname -m)"
      return 1
      ;;
  esac

  local deb_file="lsd_${version}_${arch}.deb"
  local download_url="https://github.com/lsd-rs/lsd/releases/download/v${version}/${deb_file}"
  local temp_file="/tmp/${deb_file}"

  log "Descargando lsd v${version} para ${arch}..."

  # Descargar el paquete .deb
  if ! curl -fsSL -o "$temp_file" "$download_url" >/dev/null 2>&1; then
    warning "No se pudo descargar lsd desde GitHub"
    return 1
  fi

  # Instalar el paquete .deb
  if ! sudo dpkg -i "$temp_file" >/dev/null 2>&1; then
    warning "No se pudo instalar lsd desde .deb"
    rm -f "$temp_file"
    return 1
  fi

  # Limpiar archivo temporal
  rm -f "$temp_file"

  # Verificar que se instaló correctamente
  if ! command_exists lsd; then
    warning "lsd no se instaló correctamente"
    return 1
  fi

  log "lsd v${version} instalado correctamente"
}

# Función para instalar FiraCode Nerd Font
install_nerd_fonts() {
  local font_name="FiraCode"
  local font_dir="$HOME/.local/share/fonts"
  local temp_dir="/tmp/nerd-fonts-${font_name}"

  # Verificar si las fuentes ya están instaladas
  if fc-list | grep -q "FiraCode Nerd Font" 2>/dev/null; then
    #log "FiraCode Nerd Font ya está instalada, omitiendo instalación"
    return 0
  fi

  # Crear directorio de fuentes si no existe
  mkdir -p "$font_dir"

  log "Instalando ${font_name} Nerd Font..."

  # Descargar y extraer la fuente
  if ! curl -fsSL -o "/tmp/${font_name}.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/${font_name}.zip" >/dev/null 2>&1; then
    warning "No se pudo descargar ${font_name} Nerd Font"
    return 1
  fi

  # Extraer fuentes
  if ! unzip -q "/tmp/${font_name}.zip" -d "$temp_dir" >/dev/null 2>&1; then
    warning "No se pudo extraer ${font_name} Nerd Font"
    rm -f "/tmp/${font_name}.zip"
    return 1
  fi

  # Copiar fuentes al directorio local
  if ! cp -r "$temp_dir"/* "$font_dir/" >/dev/null 2>&1; then
    warning "No se pudo copiar ${font_name} Nerd Font"
    rm -rf "$temp_dir"
    rm -f "/tmp/${font_name}.zip"
    return 1
  fi

  # Limpiar archivos temporales
  rm -rf "$temp_dir"
  rm -f "/tmp/${font_name}.zip"

  # Actualizar caché de fuentes
  if command_exists fc-cache; then
    fc-cache -f -v >/dev/null 2>&1
  fi

  log "${font_name} Nerd Font instalada correctamente"
  log "Configura tu terminal para usar 'FiraCode Nerd Font'"
}

# Función para instalar paquete según OS (silenciosa)
install_package() {
  local pkg="$1"

  case "${OS_TYPE:-}" in
    linux|wsl2)
      # Verificar si ya está instalado
      if package_installed_apt "$pkg"; then
        #log "$pkg ya está instalado, omitiendo instalación"
        return 0
      fi

      # Caso especial para lsd (no disponible en repositorios estándar)
      if [[ "$pkg" == "lsd" ]]; then
        install_lsd
      else
        # Intentar instalar con manejo de errores usando apt (más moderno)
        if ! sudo apt install -y -qq "$pkg" >/dev/null 2>&1; then
          warning "No se pudo instalar $pkg - continuando..."
          return 1
        fi
      fi
      ;;
    macos)
      # Verificar si ya está instalado
      if package_installed_brew "$pkg"; then
        #log "$pkg ya está instalado, omitiendo instalación"
        return 0
      fi

      if ! brew install "$pkg" >/dev/null 2>&1; then
        warning "No se pudo instalar $pkg - continuando..."
        return 1
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
      if ! sudo apt update -y -qq >/dev/null 2>&1; then
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
