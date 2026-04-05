# =============================================================================
# Archivo de configuración de Bash para Git Bash en Windows
# =============================================================================
# Ubicación final: ~/.bashrc
# Propósito: Personaliza el entorno de Git Bash con herramientas modernas,
#            prompt personalizado con Oh My Posh, y aliases útiles
# Compatible con: Git Bash en Windows 10/11
# Dependencias: lsd, zoxide, fzf, oh-my-posh, git
# =============================================================================

# =============================================================================
# CONFIGURACIÓN BÁSICA DE SHELL INTERACTIVO
# =============================================================================

# Si no se ejecuta de forma interactiva, no hacer nada
case $- in
    *i*) ;;
      *) return;;
esac

# =============================================================================
# PATH ADICIONAL (solo afecta a Git Bash, no al PATH de Windows)
# =============================================================================

export PATH="$HOME/bin:$HOME/Nextcloud/priv/bin:$PATH"

# =============================================================================
# CONFIGURACIÓN DEL HISTORIAL DE COMANDOS
# =============================================================================

# No duplicar líneas o líneas que empiecen con espacio en el historial
# ignoreboth = ignoredups + ignorespace
HISTCONTROL=ignoreboth

# Añadir al archivo de historial, no sobrescribirlo
shopt -s histappend

# Historial amplio para uso como terminal principal
HISTSIZE=10000
HISTFILESIZE=20000

# =============================================================================
# CONFIGURACIÓN DE VENTANA Y TERMINAL
# =============================================================================

# Desactivar el parpadeo de pantalla (visible bell) en autocompletado
# Sin esto, Git Bash muestra un flash blanco cuando TAB no encuentra coincidencia única
bind 'set bell-style none'

# Verificar el tamaño de la ventana después de cada comando
shopt -s checkwinsize

# Habilitar ** para búsqueda recursiva de archivos (ej: ls **/*.ts)
shopt -s globstar

# Escribir nombre de directorio para hacer cd automáticamente (sin escribir 'cd')
shopt -s autocd

# Autocorregir errores tipográficos menores en cd y autocompletado
shopt -s cdspell
shopt -s dirspell

# =============================================================================
# CONFIGURACIÓN AVANZADA DE READLINE (AUTOCOMPLETADO)
# =============================================================================

# Autocompletado sin distinguir mayúsculas/minúsculas
bind 'set completion-ignore-case on'

# Mostrar todas las opciones en el primer TAB (sin necesitar dos pulsaciones)
bind 'set show-all-if-ambiguous on'

# Tratar guiones y guiones bajos como equivalentes en autocompletado
bind 'set completion-map-case on'

# Mostrar colores en las sugerencias de autocompletado
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'

# =============================================================================
# CONFIGURACIÓN DE COLORES PARA COMANDOS
# =============================================================================

# Aliases para grep con colores (resaltado de coincidencias)
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# =============================================================================
# CONFIGURACIÓN DE LSD (REEMPLAZO MODERNO DE LS)
# =============================================================================

# LSD proporciona iconos, colores mejorados y mejor formato de salida
if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd --group-directories-first'
    alias ll='lsd --group-directories-first -l'
    alias la='lsd --group-directories-first -a'
    alias lla='lsd --group-directories-first -la'
fi

# =============================================================================
# CONFIGURACIÓN DETALLADA DE COLORES LS_COLORS
# =============================================================================

# Colores para diferentes tipos de archivos (usado por lsd y autocompletado)
export LS_COLORS='fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:'
LS_COLORS+='pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32'
LS_COLORS+=':*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32'
LS_COLORS+=':*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31'
LS_COLORS+=':*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31'
LS_COLORS+=':*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31'
LS_COLORS+=':*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35'
LS_COLORS+=':*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35'
LS_COLORS+=':*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35'
LS_COLORS+=':*.dl=01;35:*.gl=01;35:*.wmv=01;35'

# =============================================================================
# ALIASES Y FUNCIONES PERSONALIZADAS
# =============================================================================

# Abrir Visual Studio Code rápidamente
alias e='code $*'

# Git status (consistente con zsh y PowerShell)
alias gst='git status'

# Monitor de sistema (btm/bottom como alternativa a htop)
if command -v btm >/dev/null 2>&1; then
    alias htop='btm'
fi

# Llevo años usando more... me sale solo
alias more='less'

# =============================================================================
# INCLUSIÓN DE ALIASES EXTERNOS
# =============================================================================

# Aliases personalizados adicionales en ~/.bash_aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# =============================================================================
# AUTOCOMPLETADO PROGRAMABLE
# =============================================================================

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# =============================================================================
# PRIVACIDAD Y TELEMETRÍA
# =============================================================================

# Deshabilitar telemetría de herramientas de desarrollo
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Servidor X para aplicaciones gráficas (ej: X410, VcXsrv)
export DISPLAY=localhost:0.0

# =============================================================================
# CONFIGURACIÓN DE OH MY POSH PARA GIT BASH (WINDOWS)
# =============================================================================

# Icono del sistema operativo para Oh My Posh
export OMP_OS_ICON="⚡"

# Ruta al ejecutable de Oh My Posh instalado con Scoop
#export OMP_PATH="$HOME/scoop/shims/oh-my-posh.exe"
#export OMP_PATH="$HOME/scoop/apps/oh-my-posh/current/oh-my-posh.exe"
export OMP_PATH="$(readlink -f "$HOME/scoop/apps/oh-my-posh/current/oh-my-posh.exe")"

# Inicializar Oh My Posh con el tema personalizado
if [ -x "$OMP_PATH" ]; then
    eval "$("$OMP_PATH" --init --shell bash --config ~/.oh-my-posh.json)"
fi

# =============================================================================
# CONFIGURACIÓN PARA KUBERNETES
# =============================================================================

export KUBECONFIG="${HOME}/kubeconfig"

# =============================================================================
# CONFIGURACIÓN DE ZOXIDE (NAVEGACIÓN INTELIGENTE DE DIRECTORIOS)
# =============================================================================

# Reemplaza 'cd' con zoxide para saltar a directorios frecuentes
# Uso: cd nombre_directorio (salta al directorio más frecuente que coincida)
#       cdi                 (selector interactivo con fzf)
#if command -v zoxide >/dev/null 2>&1; then
#    eval "$(zoxide init bash --cmd cd)"
#fi
#ZOXIDE_PATH="$HOME/scoop/apps/zoxide/current/zoxide.exe"
ZOXIDE_PATH="$(readlink -f "$HOME/scoop/apps/zoxide/current/zoxide.exe")"
if [ -x "$ZOXIDE_PATH" ]; then
    eval "$("$ZOXIDE_PATH" init bash --cmd cd)"
fi

# =============================================================================
# CONFIGURACIÓN DE FZF (BÚSQUEDA DIFUSA)
# =============================================================================

# Ctrl+R: búsqueda en historial, Ctrl+T: búsqueda de archivos, Alt+C: cd a directorio
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash 2>/dev/null)"
fi

# =============================================================================
# NOTAS IMPORTANTES PARA EL USUARIO:
# =============================================================================
# 1. Este archivo se copia automáticamente a ~/.bashrc durante la instalación
# 2. Requiere tener instalados: lsd, zoxide, fzf, oh-my-posh
# 3. El archivo ~/.oh-my-posh.json debe existir para el prompt personalizado
# 4. Si Oh My Posh no está instalado, el prompt usará el formato estándar
# 5. Autocompletado: TAB muestra opciones, sin distinguir mayúsculas/minúsculas
# 6. Navegación: autocd (escribir directorio = cd), cdspell (autocorrección)
# 7. Búsqueda: Ctrl+R (historial), Ctrl+T (archivos), Alt+C (directorios)
# =============================================================================
