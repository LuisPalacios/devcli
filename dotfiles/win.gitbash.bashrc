# =============================================================================
# Archivo de configuración de Bash para Git Bash en Windows
# =============================================================================
# Ubicación final: ~/.bashrc
# Propósito: Personaliza el entorno de Git Bash con herramientas modernas,
#            prompt personalizado con Oh My Posh, y aliases útiles
# Compatible con: Git Bash en Windows 10/11
# =============================================================================

# ~/.bashrc: ejecutado por bash(1) para shells no-login interactivos
# Registro de acceso para depuración
date >> /tmp/fecha-login.txt

# Ver /usr/share/doc/bash/examples/startup-files (en el paquete bash-doc)
# para más ejemplos de configuración

# =============================================================================
# CONFIGURACIÓN BÁSICA DE SHELL INTERACTIVO
# =============================================================================

# Si no se ejecuta de forma interactiva, no hacer nada
# Esto evita que el archivo se procese en scripts automatizados
case $- in
    *i*) ;;
      *) return;;
esac

# =============================================================================
# CONFIGURACIÓN DEL HISTORIAL DE COMANDOS
# =============================================================================

# No duplicar líneas o líneas que empiecen con espacio en el historial
# ignoreboth = ignoredups + ignorespace
HISTCONTROL=ignoreboth

# Añadir al archivo de historial, no sobrescribirlo
# Esto preserva el historial entre sesiones
shopt -s histappend

# Configurar longitud del historial
# HISTSIZE: comandos en memoria durante la sesión
# HISTFILESIZE: comandos guardados en el archivo ~/.bash_history
HISTSIZE=1000
HISTFILESIZE=2000

# =============================================================================
# CONFIGURACIÓN DE VENTANA Y TERMINAL
# =============================================================================

# Verificar el tamaño de la ventana después de cada comando y, si es necesario,
# actualizar los valores de LINES y COLUMNS para redimensionamiento automático
shopt -s checkwinsize

# Si está habilitado, el patrón "**" usado en expansión de rutas
# coincidirá con todos los archivos y cero o más directorios y subdirectorios
# (Comentado por defecto para compatibilidad)
#shopt -s globstar

# =============================================================================
# CONFIGURACIÓN DE HERRAMIENTAS DEL SISTEMA
# =============================================================================

# Hacer que less sea más amigable para archivos de entrada no-texto
# lesspipe permite visualizar archivos comprimidos, imágenes, etc.
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Establecer variable que identifica el chroot en el que trabajas
# (usado en el prompt a continuación)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# =============================================================================
# CONFIGURACIÓN DEL PROMPT (LÍNEA DE COMANDOS)
# =============================================================================

# Configurar un prompt elegante (sin color, a menos que sepamos que "queremos" color)
# Detectar si el terminal soporta colores
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# Descomentar para un prompt con colores, si el terminal tiene la capacidad;
# desactivado por defecto para no distraer al usuario: el foco en una ventana de terminal
# debe estar en la salida de los comandos, no en el prompt
#force_color_prompt=yes

# Verificar soporte de colores del terminal
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# Tenemos soporte de color; asumir que es compatible con Ecma-48
	# (ISO/IEC-6429). (La falta de tal soporte es extremadamente rara)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# Establecer el formato del prompt según soporte de colores
if [ "$color_prompt" = yes ]; then
    # Prompt con colores: usuario@host en verde, directorio actual en azul
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    # Prompt sin colores: formato básico usuario@host:directorio$
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# =============================================================================
# CONFIGURACIÓN DEL TÍTULO DE VENTANA
# =============================================================================

# Si es un xterm, establecer el título a usuario@host:directorio
# Esto muestra información útil en la barra de título del terminal
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# =============================================================================
# CONFIGURACIÓN DE COLORES PARA COMANDOS
# =============================================================================

# Habilitar soporte de colores para ls y añadir aliases útiles
if [ -x /usr/bin/dircolors ]; then
    # Cargar configuración de colores personalizada o usar la por defecto
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"

    # Aliases para grep con colores (resaltado de coincidencias)
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Colores para advertencias y errores de GCC (compilador C/C++)
# Descomentado si desarrollas en C/C++
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# =============================================================================
# CONFIGURACIÓN DE LSD (REEMPLAZO MODERNO DE LS)
# =============================================================================

# Usar LSD en lugar de LS si está disponible
# LSD proporciona iconos, colores mejorados y mejor formato de salida
if command -v lsd >/dev/null 2>&1; then
    # Alias principal: ls con directorios agrupados al principio
    alias ls='lsd --group-directories-first'

    # Aliases adicionales comentados - descomenta según prefieras:
    #alias ll='lsd --group-directories-first -l'      # listado largo
    #alias la='lsd --group-directories-first -a'      # mostrar archivos ocultos
    #alias lla='lsd --group-directories-first -la'    # listado largo + ocultos
    #alias l='lsd --group-directories-first -1'       # una columna
fi

# =============================================================================
# CONFIGURACIÓN DETALLADA DE COLORES LS_COLORS
# =============================================================================

# Configuración personalizada de colores para diferentes tipos de archivos
# Formato: tipo=color donde color usa códigos ANSI
export LS_COLORS='fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:'
# Archivos especiales del sistema (pipes, sockets, dispositivos)
LS_COLORS+='pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32'
# Archivos ejecutables de Windows (.cmd, .exe, .com, .bat, .dll)
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

# =============================================================================
# ALIASES Y FUNCIONES PERSONALIZADAS
# =============================================================================

# Añadir un alias "alert" para comandos de larga duración
# Uso: sleep 10; alert
# Esto mostrará una notificación cuando el comando termine
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# =============================================================================
# INCLUSIÓN DE ALIASES EXTERNOS
# =============================================================================

# Incluir definiciones de aliases personalizados
# Puedes agregar todos tus aliases en ~/.bash_aliases en lugar de aquí
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# =============================================================================
# AUTOCOMPLETADO PROGRAMABLE
# =============================================================================

# Habilitar características de autocompletado programable
# (no necesitas habilitarlo si ya está habilitado en /etc/bash.bashrc
# y /etc/profile incluye /etc/bash.bashrc)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# =============================================================================
# ALIASES Y FUNCIONES PERSONALIZADAS PARA DESARROLLO
# =============================================================================

# Alias para abrir Visual Studio Code rápidamente
# Uso: e archivo.txt  o  e .  (para abrir directorio actual)
alias e='code $*'

# =============================================================================
# CONFIGURACIÓN DE OH MY POSH PARA GIT BASH (WINDOWS)
# =============================================================================

# Establecer icono del sistema operativo para Oh My Posh
# Este icono aparecerá en el prompt personalizado
export OMP_OS_ICON="⚡"

# Ruta al ejecutable de Oh My Posh instalado con Scoop
# Scoop instala los ejecutables en ~/scoop/shims/
export OMP_PATH="/c/Users/luis/scoop/shims/oh-my-posh.exe"

# Inicializar Oh My Posh para personalizar el prompt de Git Bash
# Usa el archivo de configuración personalizado ~/.oh-my-posh.json
# Solo se ejecuta si el binario de Oh My Posh existe y es ejecutable
if [ -x "$OMP_PATH" ]; then
    eval "$("$OMP_PATH" --init --shell bash --config ~/.oh-my-posh.json)"
fi

# =============================================================================
# CONFIGURACIÓN PARA KUBERNETES
# =============================================================================

# Establecer la variable de entorno KUBECONFIG para Kubernetes
export KUBECONFIG="${HOME}/kubeconfig"

# =============================================================================
# NOTAS IMPORTANTES PARA EL USUARIO:
# =============================================================================
# 1. Este archivo se copia automáticamente a ~/.bashrc durante la instalación
# 2. Requiere tener instalados: lsd, oh-my-posh, y el tema ~/.oh-my-posh.json
# 3. El archivo ~/.oh-my-posh.json debe existir para el prompt personalizado
# 4. Si Oh My Posh no está instalado, el prompt usará el formato estándar
# 5. Los aliases de lsd solo funcionan si lsd está instalado via Scoop
# =============================================================================

