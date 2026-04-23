# =============================================================================
# Configuración avanzada de Zsh multiplataforma
# =============================================================================
# Ubicación final: ~/.zshrc
# Propósito: Configurar Zsh con herramientas modernas, navegación inteligente,
#            prompt personalizado y compatibilidad multiplataforma
# Compatible con: Linux, macOS, WSL2 en Windows 10/11
# Dependencias: lsd, zoxide, oh-my-posh, git, tmux (opcional)
# =============================================================================

# Fichero .zshrc de Linux Setup
# Versión: 6 de Julio de 2025
# Utilizado en MacOS (brew), Linux (Ubuntu), Windows WSL2
#
# Referencias:
# - Proyecto padre - https://github.com/LuisPalacios/devcli
# - Versión antigua - https://github.com/LuisPalacios/zsh-zshrc
# - ¡Adiós Bash, hola Zsh! - https://www.luispa.com/administraci%C3%B3n/2024/04/23/zsh.html
# - Terminales con tmux - https://www.luispa.com/administraci%C3%B3n/2024/04/25/tmux.html
# - WSL2 en Windows - https://www.luispa.com/desarrollo/2024/08/25/win-desarrollo.html#wsl-2
#
# Multiplataforma:
# - linux, usuario normal y root: Funciona
# - MacOS, usuario normal: Funciona
#   MacOS, root: no lo uso. MacOS usa bash especial que consume /root.lprofile
# - WSL2, usuario normal: Funciona
#
# Debug: En caso de necesitarlo, activar la línea siguiente
#set -x

# =============================================================================
# CONFIGURACIÓN INICIAL Y DETECCIÓN DE ENTORNO
# =============================================================================

# Parametrización básica del usuario actual y localización
SOY="$(id -un)"                    # Nombre del usuario actual
export LANG="es_ES.UTF-8"          # Idioma por defecto (español España)

# =============================================================================
# DETECCIÓN AUTOMÁTICA DE ENTORNOS ESPECIALES
# =============================================================================

# Detectar si estamos dentro de una sesión WSL2 (Windows Subsystem for Linux)
# WSL2 establece la variable WSL_DISTRO_NAME automáticamente
export IS_WSL2=false
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  export IS_WSL2=true
fi

# Detectar si estamos dentro de una sesión de Visual Studio Code
# VSCode establece múltiples variables de entorno que empiezan con "VSCODE_"
export IS_VSCODE=false
if [[ $(printenv | grep -c "VSCODE_") -gt 0 ]]; then
    export IS_VSCODE=true
fi

# =============================================================================
# FUNCIONES AUXILIARES PARA DETECCIÓN DE CAPACIDADES
# =============================================================================

# Función para averiguar si un comando ls soporta ciertos argumentos
# Útil para detectar si el sistema usa GNU ls (Linux) o BSD ls (macOS)
# Parámetros: comando y argumentos a probar
# Retorna: 0 si el comando soporta los argumentos, 1 si no
function test-ls-args {
  local cmd="$1"          # Comando a probar (ls, gls, colorls, etc.)
  local args="${@[2,-1]}" # Los argumentos excepto el primero
  command "$cmd" "$args" /dev/null &>/dev/null
}

# =============================================================================
# FUNCIÓN DE CONFIGURACIÓN COMÚN MULTIPLATAFORMA
# =============================================================================

# Configuración común de Zsh que se aplica en todos los sistemas operativos
# Esta función centraliza todas las configuraciones que son independientes del OS
function parametriza_zsh_comun() {

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE COLORES PARA COMANDOS DE LISTADO
  # ---------------------------------------------------------------------------

  # LS_COLORS: Configuración de colores para GNU ls (Linux/WSL2)
  # Define colores específicos para diferentes tipos de archivos y directorios
  # Formato: tipo=color donde color usa códigos ANSI
  export LS_COLORS='fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:'
  # Archivos especiales del sistema (pipes, sockets, dispositivos)
  LS_COLORS+='pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32'
  # Archivos ejecutables y binarios (.cmd, .exe, .com, .bat, .dll)
  LS_COLORS+=':*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32'
  # Archivos comprimidos (.tar, .zip, .gz, .bz2, etc.)
  LS_COLORS+=':*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31'
  LS_COLORS+=':*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31'
  LS_COLORS+=':*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31'
  # Archivos multimedia (imágenes, videos)
  LS_COLORS+=':*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35'
  LS_COLORS+=':*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35'
  LS_COLORS+=':*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35'
  LS_COLORS+=':*.dl=01;35:*.gl=01;35:*.wmv=01;35'

  # TREE_COLORS: Colores para el comando tree basados en LS_COLORS
  # Elimina códigos específicos que tree no entiende
  export TREE_COLORS=${LS_COLORS//04;}

  # LSCOLORS: Configuración de colores para BSD ls (macOS)
  # Formato diferente más compacto usado por el ls nativo de macOS
  export CLICOLOR=1                      # Habilitar colores en BSD ls
  export LSCOLORS='GxExDxDxCxDxDxFxFxexEx'

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE ALIAS COMUNES
  # ---------------------------------------------------------------------------

  # Usar LSD (LSDeluxe) como reemplazo moderno de ls
  # LSD proporciona iconos, colores mejorados y mejor formato
  # Funciona en todos los sistemas operativos
  alias ls='lsd'
  # Git status (nota: en WSL se sobreescribe)
  alias gst='git status'

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE LOCALIZACIÓN (IDIOMA Y REGIÓN)
  # ---------------------------------------------------------------------------

  # Establecer todas las variables de localización al idioma configurado
  # Esto afecta formato de fechas, números, moneda, ordenamiento, etc.
  export LC_CTYPE=${LANG}              # Clasificación de caracteres
  export LC_NUMERIC=${LANG}            # Formato de números
  export LC_TIME=${LANG}               # Formato de fecha y hora
  export LC_COLLATE=${LANG}            # Ordenamiento de cadenas
  export LC_MONETARY=${LANG}           # Formato de moneda
  export LC_MESSAGES=${LANG}           # Idioma de mensajes del sistema
  export LC_PAPER=${LANG}              # Tamaño de papel por defecto
  export LC_NAME=${LANG}               # Formato de nombres de persona
  export LC_ADDRESS=${LANG}            # Formato de direcciones
  export LC_TELEPHONE=${LANG}          # Formato de números de teléfono
  export LC_MEASUREMENT=${LANG}        # Sistema de medidas (métrico/imperial)
  export LC_IDENTIFICATION=${LANG}     # Identificación de localización
  export LC_ALL=${LANG}                # Sobrescribe todas las anteriores

  # ---------------------------------------------------------------------------
  # DETECCIÓN Y CONFIGURACIÓN DE LA SHELL ACTUAL
  # ---------------------------------------------------------------------------

  # Detectar e inicializar el valor correcto de la variable SHELL
  # Si $SHELL no termina en */zsh o */zsh-static, actualizar con la ruta absoluta
  # Esto es importante para scripts que necesiten saber qué shell usar
  [[ -o interactive ]] && \
    case $SHELL in
        */zsh) ;;                          # Ya es zsh, no hacer nada
        */zsh-static) ;;                   # Ya es zsh-static, no hacer nada
        *) SHELL=${${0#-}:c:A}             # Obtener ruta absoluta de zsh actual
    esac

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE PRIVACIDAD Y TELEMETRÍA
  # ---------------------------------------------------------------------------

  # Deshabilitar telemetría de herramientas de desarrollo
  export DOTNET_CLI_TELEMETRY_OPTOUT=1   # Microsoft .NET Core CLI

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE EDICIÓN Y NAVEGACIÓN EN TERMINAL
  # ---------------------------------------------------------------------------

  # Personalizar qué caracteres se consideran parte de una palabra para edición
  # Por defecto, zsh incluye '/' lo que hace tedioso editar rutas de archivos
  # Esta configuración elimina '/' para facilitar la edición de rutas
  WORDCHARS='*?_.[]~&;!#$%^(){}<>'

  # Eliminar el mensaje "Last login" molesto en nuevas sesiones y pestañas
  # Crear archivo ~/.hushlogin si no existe para suprimir el mensaje
  [ ! -f ~/.hushlogin ] && touch ~/.hushlogin

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN AVANZADA DE ZSH
  # ---------------------------------------------------------------------------

  # Opciones de historial y comportamiento
  setopt HIST_IGNORE_DUPS     # No almacenar comandos duplicados en historial
  setopt SHARE_HISTORY        # Compartir historial entre todas las instancias de zsh
  setopt RM_STAR_SILENT       # No pedir confirmación para 'rm *' (más como bash)
  setopt PROMPT_SUBST         # Habilitar expansión de parámetros en el prompt
                              # Necesario para mostrar información dinámica como Git

  # Usar keybindings estilo Emacs incluso si $EDITOR está configurado como vi
  # Esto proporciona navegación familiar (Ctrl+A, Ctrl+E, etc.)
  bindkey -e

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DEL HISTORIAL DE COMANDOS
  # ---------------------------------------------------------------------------

  # Configurar tamaño y ubicación del historial
  HISTSIZE=1000               # Comandos en memoria durante la sesión
  SAVEHIST=1000               # Comandos guardados en archivo
  HISTFILE=~/.zsh_history     # Ubicación del archivo de historial

  # ---------------------------------------------------------------------------
  # SISTEMA DE AUTOCOMPLETADO MODERNO
  # ---------------------------------------------------------------------------

  # Cargar e inicializar el sistema de autocompletado avanzado de zsh
  autoload -Uz compinit
  compinit -u

  # Configuración detallada del sistema de autocompletado
  zstyle ':completion:*' auto-description 'specify: %d'
  zstyle ':completion:*' completer _expand _complete _correct _approximate
  zstyle ':completion:*' format 'Completing %d'
  zstyle ':completion:*' group-name ''
  zstyle ':completion:*' menu select=2
  zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
  zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
  zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
  zstyle ':completion:*' menu select=long
  zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
  zstyle ':completion:*' use-compctl false
  zstyle ':completion:*' verbose true
  zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
  zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
  zstyle ':completion:*' list-colors "${(@s.:.)LS_COLORS}"

  # ---------------------------------------------------------------------------
  # SISTEMA DE HOOKS Y EXTENSIBILIDAD
  # ---------------------------------------------------------------------------

  # Habilitar sistema de hooks de zsh para permitir extensiones personalizadas
  # Los hooks permiten ejecutar código en puntos específicos del ciclo de vida
  # de la shell (antes/después de comandos, cambios de directorio, etc.)
  autoload -Uz add-zsh-hook

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE TMUX (TERMINAL MULTIPLEXER)
  # ---------------------------------------------------------------------------
  # Esta sección proporciona aliases para tmux pero no lo inicia automáticamente
  # Permite flexibilidad para elegir cuándo usar tmux

  # FILOSOFÍA DE CONFIGURACIÓN DE TMUX:
  # Se pueden configurar dos comportamientos:
  # 1) AUTO-INICIO: tmux reemplaza automáticamente a zsh al hacer login
  # 2) MANUAL: tmux se inicia solo cuando se necesita (OPCIÓN ELEGIDA)
  #
  # La opción manual permite mayor flexibilidad, especialmente útil cuando
  # se conecta a servidores remotos que también tienen zsh y tmux configurados
  t_function() {
    local use_exec=false
    # Si el primer argumento es "-e", activamos el uso de exec.
    if [[ "$1" == "-e" ]]; then
      use_exec=true
    fi

    # 1. Comprobación de tmux
    if ! command -v tmux &> /dev/null; then
      echo "Error: 'tmux' no se encuentra en tu PATH."
      echo "Por favor, instala tmux para usar esta función."
      return 1
    fi

    # 2. Comprobación del archivo de configuración
    if [[ ! -f ~/.tmux.conf ]]; then
      echo "Error: No se encontró el archivo de configuración '~/.tmux.conf'."
      echo "Esta función requiere una configuración de tmux."
      return 1
    fi

    # 3. Comprobaciones de entorno
    if [[ -t 1 && -z "$TMUX" && \
            $PPID != 1 && \
            $$ != 1 && \
            $TERM != dumb && \
            $TERM != xterm && \
            $TERM != linux && \
            $TERM != screen* && \
            $IS_VSCODE != true ]]; then

      # 4. Lógica para adjuntar o crear la sesión
      if tmux has-session -t TMUX &> /dev/null; then
        if $use_exec; then
          exec tmux attach-session -t TMUX
        else
          tmux attach-session -t TMUX
        fi
      else
        if $use_exec; then
          exec tmux new-session -s TMUX
        else
          tmux new-session -s TMUX
        fi
      fi
    fi
  }
  # Inicia tmux como un subproceso (alias seguro)
  alias tt="t_function"

  # Inicia tmux reemplazando el shell actual (alias con exec)
  alias t="t_function -e"

}

# =============================================================================
# CONFIGURACIÓN ESPECÍFICA POR SISTEMA OPERATIVO
# =============================================================================

# =============================================================================
# CONFIGURACIÓN PARA WSL2 (WINDOWS SUBSYSTEM FOR LINUX)
# =============================================================================
if [ "$IS_WSL2" = true ] ; then

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE PATH PARA WSL2
  # ---------------------------------------------------------------------------

  # Eliminar duplicados en PATH usando typeset -U (unique)
  typeset -U path PATH

  # Construcción limpia y ordenada del PATH para WSL2
  # Incluye rutas tanto de Linux como de Windows accesibles desde WSL2
  path=(
    .                                    # Directorio actual (útil para desarrollo)
    "${HOME}/bin"                        # Binarios personales del usuario
    "/mnt/c/Users/${SOY}/bin"                         # Binarios personales del usuario
    "/mnt/c/Users/${SOY}/Nextcloud/priv/bin"           # Scripts privados en Windows
    "/mnt/c/Users/${SOY}/Nextcloud/priv/bin/win"       # Scripts específicos de Windows
    "/mnt/c/Users/${SOY}/dev-tools/kombine.win"        # Herramientas de desarrollo
    "/mnt/c/Program Files/Docker/Docker/resources/bin" # Docker Desktop para Windows
    "/mnt/c/Users/${SOY}/AppData/Local/Programs/Microsoft VS Code/bin" # VS Code CLI
    "/mnt/c/Program Files/Git/mingw64/bin"             # Git for Windows
    "/mnt/c/Windows/System32"                          # Comandos de sistema Windows
    "/mnt/c/Windows"                                   # Directorio Windows
    "/mnt/c/Windows/System32/wbem"                     # WMI y herramientas de gestión
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0"  # PowerShell 5.1
    "/mnt/c/Program Files/PowerShell/7"               # PowerShell 7
    "/usr/local/sbin"                                 # Binarios de administración local
    "/usr/local/bin"                                  # Binarios locales
    "/usr/sbin"                                       # Binarios de administración del sistema
    "/usr/bin"                                        # Binarios del sistema
    "/sbin"                                           # Binarios de arranque del sistema
    "/bin"                                            # Binarios básicos del sistema
    "/usr/games"                                      # Juegos del sistema
    "/usr/local/games"                                # Juegos locales
    "/usr/lib/wsl/lib"                                # Librerías específicas de WSL
    $path                                             # PATH heredado del entorno
  )

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN COMÚN Y ALIASES ESPECÍFICOS DE WSL2
  # ---------------------------------------------------------------------------

  # Aplicar configuración común multiplataforma
  parametriza_zsh_comun

  # Aliases específicos para WSL2
  alias c="cd /mnt/c/Users/${SOY}"       # Acceso rápido al directorio de usuario Windows
  alias git="git.exe"                    # Usar Git for Windows desde WSL2 para mejor integración
  alias gst="git.exe status"             # Mostrar git status

# =============================================================================
# CONFIGURACIÓN PARA MACOS Y LINUX NATIVOS
# =============================================================================
else

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN ESPECÍFICA POR TIPO DE UNIX
  # ---------------------------------------------------------------------------

  case "$OSTYPE" in
    # -------------------------------------------------------------------------
    # NetBSD - Sistema operativo BSD
    # -------------------------------------------------------------------------
    netbsd*)
      # En NetBSD, probar si `gls` (GNU ls) está instalado (soporta colores)
      # Si no está disponible, usar ls nativo sin colores
      test-ls-args gls --color && alias ls='gls --color=tty'
      ;;

    # -------------------------------------------------------------------------
    # OpenBSD - Sistema operativo BSD
    # -------------------------------------------------------------------------
    openbsd*)
      # En OpenBSD, tanto `gls` (GNU coreutils) como `colorls` están disponibles
      # `colorls` es preferido porque es específico para OpenBSD
      test-ls-args gls --color && alias ls='gls --color=tty'
      test-ls-args colorls -G && alias ls='colorls -G'
      ;;

    # -------------------------------------------------------------------------
    # macOS y FreeBSD - Sistemas BSD modernos
    # -------------------------------------------------------------------------
    (darwin|freebsd)*)
      # Configuración específica para macOS con Homebrew y herramientas de desarrollo

      # Eliminar duplicados en PATH
      typeset -U path PATH

      # Inicializar entorno de Homebrew (Intel: /usr/local, Apple Silicon: /opt/homebrew)
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi

      # Prefijo de Homebrew (usado para rutas de herramientas)
      local BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

      # PATH ordenado y optimizado para desarrollo en macOS
      path=(
        "${BREW_PREFIX}/opt/llvm/bin"             # LLVM/Clang moderno
        $path                                     # PATH heredado del sistema
        .                                         # Directorio actual para scripts locales
        "${HOME}/bin"                             # Binarios personales
        "${HOME}/.local/bin"                      # Otros binarios personales
        "${HOME}/Nextcloud/priv/bin"              # Scripts privados sincronizados
        "${HOME}/.lmstudio/bin"                   # Si instalo LM Studio CLI
        "${HOME}/.antigravity/antigravity/bin"    # Si instalo Antigravity
        "/usr/local/sbin"                         # Binarios de administración local
        "${HOME}/dev-tools/kombine.osx"           # Herramientas de desarrollo específicas
      )

      # Reflejar PATH en el entorno gráfico para aplicaciones GUI
      launchctl setenv PATH "${(j/:/)path}"

      # -----------------------------------------------------------------------
      # CONFIGURACIÓN DE LLVM/CLANG PARA DESARROLLO C/C++
      # -----------------------------------------------------------------------
      export CPLUS_INCLUDE_PATH="${BREW_PREFIX}/opt/llvm/include"
      export LIBRARY_PATH="${BREW_PREFIX}/opt/llvm/lib"
      export CC="${BREW_PREFIX}/opt/llvm/bin/clang"
      export CXX="${BREW_PREFIX}/opt/llvm/bin/clang++"
      export LDFLAGS="-L${BREW_PREFIX}/opt/llvm/lib"
      export CPPFLAGS="-I${BREW_PREFIX}/opt/llvm/include"

      # -----------------------------------------------------------------------
      # HERRAMIENTAS DE DESARROLLO
      # -----------------------------------------------------------------------
      export SHFMT_PATH="${BREW_PREFIX}/bin/shfmt"    # Formateador de shell scripts

      # Configurar LSD como reemplazo de ls (ya definido en función común)
      alias ls='lsd'

      # -----------------------------------------------------------------------
      # CONFIGURACIÓN DE TERMINAL Y TECLADO
      # -----------------------------------------------------------------------
      # Deshabilitar control de flujo de terminal (evita que Ctrl-S/Ctrl-Q congelen)
      stty -ixon

      # -----------------------------------------------------------------------
      # ALIASES ESPECÍFICOS DE MACOS
      # -----------------------------------------------------------------------
      alias grep="/usr/bin/grep"                     # Usar grep nativo de macOS
      alias e="/usr/local/bin/code"                  # Abrir Visual Studio Code
      alias pip="${BREW_PREFIX}/bin/pip3"             # Usar Python 3 por defecto
      # Delegar Homebrew dinámicamente al propietario real de la instalación
      local BREW_BIN="${BREW_PREFIX}/bin/brew"
      if [[ -x "$BREW_BIN" ]]; then
        local BREW_OWNER=$(stat -f "%Su" "$BREW_BIN" 2>/dev/null)
        
        # Crear alias solo si el dueño existe, no soy yo, y no es root
        if [[ -n "$BREW_OWNER" && "$SOY" != "$BREW_OWNER" && "$BREW_OWNER" != "root" ]]; then
          alias brew="sudo -Hu $BREW_OWNER brew"
        fi
      fi

      # -----------------------------------------------------------------------
      # OPTIMIZACIONES DE RENDIMIENTO EN BACKGROUND
      # -----------------------------------------------------------------------
      # Acelerar navegación en recursos compartidos de red
      (defaults write com.apple.desktopservices DSDontWriteNetworkStores true &)

      # Cargar claves SSH del keychain de macOS en background
      # Esto evita retrasos en el prompt mientras se cargan las claves
      (ssh-add --apple-load-keychain >/dev/null 2>&1 &)

      # -----------------------------------------------------------------------
      # CONFIGURACIÓN DE RUBY Y GEMAS
      # -----------------------------------------------------------------------
      # Instalar gemas de Ruby en directorio del usuario (no requiere sudo)
      export GEM_HOME=~/.gems

      # Si jugamos con ollama y claude
      #export ANTHROPIC_AUTH_TOKEN=ollama
      #export ANTHROPIC_API_KEY=""
      #export ANTHROPIC_BASE_URL=http://localhost:11434

      ;;

    # -------------------------------------------------------------------------
    # Linux - Distribuciones GNU/Linux
    # -------------------------------------------------------------------------
    *)
      # Configuración para sistemas Linux (Ubuntu, Debian, etc.)

      # Eliminar duplicados en PATH
      typeset -U path PATH

      if [[ $EUID -eq 0 ]]; then
        # -------------------------------------------------------------------
        # CONFIGURACIÓN PARA USUARIO ROOT
        # -------------------------------------------------------------------
        # Prompt simple y claro para root que indica privilegios elevados
        PROMPT='[%B%F{white}root%f%b]@%m:%~%# '
        # Mantener PATH heredado y añadir . y bin de root
        path=(
          .                               # Directorio actual
          "${HOME}/bin"                   # Binarios personales
          $path                           # PATH heredado del sistema
        )

      else
        # -------------------------------------------------------------------
        # CONFIGURACIÓN PARA USUARIO NORMAL
        # -------------------------------------------------------------------
        # PATH optimizado para desarrollo en Linux
        path=(
          .                               # Directorio actual
          "${HOME}/bin"                   # Binarios personales
          "${HOME}/.local/bin"            # Otros binarios personales
          "${HOME}/.local/share/pnpm"     # PNPM
          "${HOME}/Nextcloud/priv/bin"    # Scripts privados sincronizados
          "/usr/local/bin"                # Binarios instalados manualmente
          "/usr/local/sbin"               # Binarios de administración local
          "/opt/llvm/bin"                 # clang llvm
          $path                           # PATH heredado del sistema
        )

        # -------------------------------------------------------------------
        # CONFIGURACIÓN DE SSH AGENT
        # -------------------------------------------------------------------
        # Iniciar agente SSH si no está ejecutándose
        # Esto permite usar claves SSH sin introducir contraseña repetidamente
        if [[ -z "$SSH_AUTH_SOCK" ]] || ! pgrep -u "$UID" ssh-agent &>/dev/null; then
          eval "$(ssh-agent -s)" &>/dev/null
        fi
      fi

      # -----------------------------------------------------------------------
      # HERRAMIENTAS DE DESARROLLO EN LINUX
      # -----------------------------------------------------------------------
      export SHFMT_PATH="/usr/bin/shfmt"    # Formateador de shell scripts del sistema

      # Configurar LSD como reemplazo de ls (ya definido en función común)
      alias ls='lsd'
      ;;
  esac

  # ---------------------------------------------------------------------------
  # APLICAR CONFIGURACIÓN COMÚN MULTIPLATAFORMA
  # ---------------------------------------------------------------------------
  parametriza_zsh_comun

fi

# =============================================================================
# CONFIGURACIÓN DE GO - PATH DE BINARIOS
# =============================================================================
# Si Go está instalado (vía brew, paquete del sistema, etc.), añadir GOPATH/bin
# al PATH para que los binarios instalados con `go install` estén disponibles.
# Funciona en todas las plataformas (macOS, Linux, WSL2).
if command -v go &>/dev/null; then
  path+=("$(go env GOPATH)/bin")
fi

# =============================================================================
# Kubernetes
# =============================================================================
export KUBECONFIG="${HOME}/kubeconfig"

# =============================================================================
# CONFIGURACIÓN DE ZOXIDE - NAVEGACIÓN INTELIGENTE DE DIRECTORIOS
# =============================================================================

# Zoxide es un reemplazo inteligente para 'cd' que recuerda directorios visitados
# Permite saltar rápidamente a directorios frecuentes con comandos cortos
# Ejemplo: 'z doc' puede saltar a ~/Documents, 'z pro' a ~/Projects

# Verificar si zoxide está instalado
if ! command -v zoxide >/dev/null 2>&1; then
  echo "⚠️  zoxide no está instalado - navegación básica de directorios"
  echo "Instalación:"
  echo "  macOS: brew install zoxide"
  echo "  Linux: sudo apt install zoxide  (o desde https://github.com/ajeetdsouza/zoxide)"
  echo "  WSL2: sudo apt install zoxide"
else
  # Inicializar zoxide para zsh
  # Esto crea automáticamente los comandos: z, zi, y reemplaza cd con inteligencia
  eval "$(zoxide init zsh)"
fi

# =============================================================================
# CONFIGURACIÓN DE OH MY POSH - PROMPT PERSONALIZADO AVANZADO
# =============================================================================

# Oh My Posh proporciona un prompt rico y personalizable con información de:
# - Estado de Git (branch, cambios, etc.)
# - Información del sistema (OS, usuario, directorio)
# - Tiempo de ejecución de comandos
# - Estado de herramientas de desarrollo

# Verificar si Oh My Posh está instalado
if ! command -v oh-my-posh >/dev/null 2>&1; then
  echo "Necesitas instalar 'Oh My Posh', más info en .zshrc"
  echo "Instalación:"
  echo "  Visita: https://ohmyposh.dev/docs/installation/"
  echo "  Script universal: curl -s https://ohmyposh.dev/install.sh | bash -s"
  echo "  macOS: brew install oh-my-posh"
  echo "  WSL2: curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/bin"
else

  # ---------------------------------------------------------------------------
  # GESTIÓN AUTOMÁTICA DEL TEMA DE OH MY POSH
  # ---------------------------------------------------------------------------

  # Detecta si la sesión proviene de sshd (subiendo por la cadena PPid)
  _is_ssh_ancestor() {
    local pid ppid comm
    pid=$$
    for _ in {1..16}; do
      ppid=$(awk '/^PPid:/{print $2}' /proc/$pid/status 2>/dev/null) || return 1
      [[ -z "$ppid" || "$ppid" -le 1 ]] && return 1
      comm=$(< /proc/$ppid/comm 2>/dev/null)
      [[ "$comm" == "sshd" || "$comm" == sshd:* ]] && return 0
      pid=$ppid
    done
    return 1
  }

  # Configuración de archivos para el tema personalizado
  LOCAL_FILE=~/.oh-my-posh.json                    # Archivo local del tema
  REMOTE_FILE_URL="https://raw.githubusercontent.com/LuisPalacios/devcli/main/dotfiles/.oh-my-posh.json"
  TEMP_REMOTE_FILE="/tmp/.oh-my-posh_remote.yaml"  # Archivo temporal para comparación

  # Detectar sistema operativo para usar comando 'date' correcto
  case "$OSTYPE" in
    # macOS usa sintaxis BSD para date
    (darwin|freebsd)*)
      ONE_DAY_AGO=$(date -v -1d +%s)
      ;;
    # Linux y WSL2 usan sintaxis GNU para date
    *)
      ONE_DAY_AGO=$(date -d '1 day ago' +%s)
      ;;
  esac

  # ---------------------------------------------------------------------------
  # DESCARGA Y ACTUALIZACIÓN AUTOMÁTICA DEL TEMA
  # ---------------------------------------------------------------------------

  # Si el archivo local no existe, descargarlo
  if [[ ! -a $LOCAL_FILE ]]; then
    curl --connect-timeout 2 --max-time 3 -LJs -o $LOCAL_FILE $REMOTE_FILE_URL
    touch $LOCAL_FILE
  else
    # Si el archivo existe, verificar si necesita actualización (una vez al día)

    # Obtener timestamp de modificación según el sistema operativo
    if [[ "$OSTYPE" == darwin* ]]; then
      MODTIME=$(stat -f %m "$LOCAL_FILE")      # macOS BSD stat
    else
      MODTIME=$(stat -c %Y "$LOCAL_FILE")      # Linux GNU stat
    fi

    # Si el archivo tiene más de un día, verificar actualizaciones
    if (( MODTIME <= ONE_DAY_AGO )); then
      # Descargar versión remota temporalmente
      curl --connect-timeout 2 --max-time 3 -LJs -o $TEMP_REMOTE_FILE $REMOTE_FILE_URL

      # Comparar archivos local y remoto
      if ! cmp -s $LOCAL_FILE $TEMP_REMOTE_FILE; then
        # Archivos diferentes: actualizar con versión remota
        mv $TEMP_REMOTE_FILE $LOCAL_FILE
      else
        # Archivos iguales: eliminar temporal
        rm $TEMP_REMOTE_FILE
      fi

      # Actualizar timestamp para evitar verificaciones frecuentes
      touch $LOCAL_FILE
    fi
  fi

  # ---------------------------------------------------------------------------
  # CONFIGURACIÓN DE ICONOS POR SISTEMA OPERATIVO
  # ---------------------------------------------------------------------------

  # Variable usada en el tema .oh-my-posh.json para mostrar icono del OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    export OMP_OS_ICON="🍎"                    # macOS
  elif [[ "$(uname -s)" == "Linux" ]]; then
    if [ "$IS_WSL2" = true ] ; then
        export OMP_OS_ICON="🔳"                # WSL2
    else
        export OMP_OS_ICON="🐧"                # Linux nativo
    fi
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    export OMP_OS_ICON="🪟"                    # Windows (detección alternativa)
  else
    export OMP_OS_ICON="❓"                    # Sistema desconocido
  fi

  # Variable usada para que OMP sepa que estamos en una sesioni SSH
  if _is_ssh_ancestor; then
    export OMP_SSH=1
  fi

  # ---------------------------------------------------------------------------
  # INICIALIZACIÓN DE OH MY POSH
  # ---------------------------------------------------------------------------

  # Inicializar Oh My Posh con el tema personalizado
  eval "$(oh-my-posh init zsh --config ~/.oh-my-posh.json)"
fi

# =============================================================================
# SNAPSHOT PATH A ~/.zshenv PARA SESIONES SSH NO INTERACTIVAS
# =============================================================================
# Las shells no interactivas (p.ej. `ssh host 'cmd'`) solo cargan ~/.zshenv,
# nunca ~/.zshrc. Este bloque congela el PATH que acaba de construirse y lo
# pone en ~/.zshenv, de modo que cualquier `ssh ... cmd` posterior a un login
# interactivo hereda el mismo PATH.
#
# IMPORTANTE: ~/.zshenv es POR-MÁQUINA. No sincronizar entre dispositivos.
if [[ -o interactive ]]; then
  local _zshenv="$HOME/.zshenv"
  local _desired="export PATH=\"${(j/:/)path}\""
  local _current=""
  [[ -f "$_zshenv" ]] && _current="$(grep -E '^export PATH=' "$_zshenv" 2>/dev/null | tail -1)"

  if [[ "$_current" != "$_desired" ]]; then
    {
      print -- "# ~/.zshenv — AUTO-GENERATED por ~/.zshrc en $(hostname -s) el $(date '+%Y-%m-%d %H:%M:%S')"
      print -- "# Snapshot del PATH interactivo para sesiones ssh no interactivas."
      print -- "# Per-máquina. No sincronizar entre dispositivos."
      print -- "$_desired"
    } > "$_zshenv"
  fi
fi

# =============================================================================
# NOTAS IMPORTANTES PARA EL USUARIO:
# =============================================================================
# 1. Este archivo se ejecuta automáticamente al iniciar Zsh
# 2. Detecta automáticamente el sistema operativo y se adapta
# 3. Requiere las siguientes herramientas para funcionalidad completa:
#    - lsd (listado moderno con iconos)
#    - zoxide (navegación inteligente de directorios)
#    - oh-my-posh (prompt personalizado)
#    - tmux (opcional, para sesiones múltiples)
# 4. Compatible con WSL2, macOS, y distribuciones Linux
# 5. Si faltan herramientas, muestra mensajes informativos de instalación
# 6. El tema de Oh My Posh se actualiza automáticamente desde el repositorio
# 7. Para personalizar, modifica las funciones y variables en este archivo
# 8. Debug: Descomenta 'set -x' al principio para ver ejecución detallada
# =============================================================================

# Linux Setup: -------------------------------------------------------------- END
