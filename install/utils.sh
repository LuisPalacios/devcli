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

# Función para instalar mkcert usando binarios pre-compilados
install_mkcert() {
  # Verificar si mkcert ya está instalado
  if command_exists mkcert; then
    #log "mkcert ya está instalado, omitiendo instalación"
    return 0
  fi

  local arch

  # Detectar arquitectura
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      warning "Arquitectura no soportada para mkcert: $(uname -m)"
      return 1
      ;;
  esac

  local download_url="https://dl.filippo.io/mkcert/latest?for=linux/${arch}"
  local bin_dir="$HOME/bin"
  local temp_file="/tmp/mkcert-download"

  # Crear directorio bin si no existe
  ensure_directory "$bin_dir"

  log "Descargando mkcert para linux/${arch}..."

  # Descargar el binario
  if ! curl -JLo "$temp_file" "$download_url" >/dev/null 2>&1; then
    warning "No se pudo descargar mkcert desde dl.filippo.io"
    return 1
  fi

  # Hacer el archivo ejecutable
  if ! chmod +x "$temp_file" >/dev/null 2>&1; then
    warning "No se pudo hacer ejecutable el binario de mkcert"
    rm -f "$temp_file"
    return 1
  fi

  # Mover al directorio bin
  if ! mv "$temp_file" "$bin_dir/mkcert" >/dev/null 2>&1; then
    warning "No se pudo mover mkcert a $bin_dir"
    rm -f "$temp_file"
    return 1
  fi

  # Verificar que se instaló correctamente (agregando $HOME/bin al PATH temporalmente si es necesario)
  export PATH="$bin_dir:$PATH"
  if ! command_exists mkcert; then
    warning "mkcert no se instaló correctamente"
    return 1
  fi

  log "mkcert instalado correctamente en $bin_dir/mkcert"
  log "Asegúrate de que $bin_dir esté en tu PATH"
}

# Función para instalar Nerd Fonts
install_nerd_fonts() {
  local font_name="${NERD_FONT_NAME:-FiraCode}"
  local font_dir="$HOME/.local/share/fonts"
  local fonts_dir="$HOME/.fonts"
  local temp_dir="/tmp/nerd-fonts-${font_name}"

  # Verificar si las fuentes ya están instaladas (método robusto)
  local fonts_installed=false

  # Método 1: Verificar con fc-list (Linux/WSL2)
  if command_exists fc-list; then
    if fc-list | grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 2: Verificar directorio estándar
  if [[ "$fonts_installed" == "false" ]] && [[ -d "$font_dir" ]]; then
    if find "$font_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 3: Verificar directorio alternativo
  if [[ "$fonts_installed" == "false" ]] && [[ -d "$fonts_dir" ]]; then
    if find "$fonts_dir" -name "*${NERD_FONT_NAME:-FiraCode}*" -type f | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  # Método 4: Verificar fuentes del sistema (macOS)
  if [[ "$fonts_installed" == "false" ]] && [[ "$OSTYPE" == "darwin"* ]]; then
    if command_exists system_profiler; then
      if system_profiler SPFontsDataType | grep -q "${NERD_FONT_NAME:-FiraCode}" 2>/dev/null; then
        fonts_installed=true
      fi
    fi
  fi

  if [[ "$fonts_installed" == "true" ]]; then
    log "'${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}' ya está instalada, omitiendo instalación"
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
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # En macOS, actualizar el caché de fuentes del sistema
    if command_exists atsutil; then
      atsutil server -shutdown >/dev/null 2>&1
      atsutil server -ping >/dev/null 2>&1
    fi
  fi

  # Verificar que la instalación fue exitosa
  if command_exists fc-list; then
    if ! fc-list | grep -q "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" 2>/dev/null; then
      warning "No se detectan las fuentes "${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}" recién instaladas"
      return 1
    fi
  fi

  log "${font_name} Nerd Font instalada correctamente"
  log "Configura tu terminal para usar '${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}'"
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

      # Casos especiales para paquetes no disponibles en repositorios estándar
      if [[ "$pkg" == "lsd" ]]; then
        install_lsd
      elif [[ "$pkg" == "mkcert" ]]; then
        install_mkcert
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

# Función para leer array desde archivo JSON
read_json_array() {
  local json_file="$1"
  local array_key="$2"

  # Verificar que jq está disponible
  if ! command_exists jq; then
    error "jq no está disponible"
    return 1
  fi

  # Verificar que el archivo existe
  if [[ ! -f "$json_file" ]]; then
    error "Archivo JSON no encontrado: $json_file"
    return 1
  fi

  # Verificar que el JSON es válido
  if ! jq empty "$json_file" 2>/dev/null; then
    error "Archivo JSON inválido: $json_file"
    return 1
  fi

  # Leer y retornar el array
  jq -r ".$array_key[]" "$json_file" 2>/dev/null
}

# Función para leer paquetes con nombres específicos por OS
read_packages_with_os_names() {
  local json_file="$1"
  local array_key="$2"

  # Verificar que jq está disponible
  if ! command_exists jq; then
    error "jq no está disponible"
    return 1
  fi

  # Verificar que el archivo existe
  if [[ ! -f "$json_file" ]]; then
    error "Archivo JSON no encontrado: $json_file"
    return 1
  fi

  # Verificar que el JSON es válido
  if ! jq empty "$json_file" 2>/dev/null; then
    error "Archivo JSON inválido: $json_file"
    return 1
  fi

  # Leer paquetes con nombres específicos por OS
  case "${OS_TYPE:-}" in
    linux|wsl2)
      jq -r ".$array_key[] | .linux" "$json_file" 2>/dev/null
      ;;
    macos)
      jq -r ".$array_key[] | .macos" "$json_file" 2>/dev/null
      ;;
    *)
      # Fallback: usar linux o macos
      jq -r ".$array_key[] | .linux // .macos" "$json_file" 2>/dev/null
      ;;
  esac
}
