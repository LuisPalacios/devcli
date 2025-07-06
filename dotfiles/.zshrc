# Fichero .zshrc de LuisPa
# Versión: 6 de Julio de 2025
# Utilizado en MacOS (brew), Linux (Ubuntu), Windows WSL2
#
# Referencias:
# - Proyecto padre - https://github.com/LuisPalacios/linux-setup
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

# Parametrización
SOY="luis"  # cual es mi nombre de usuario en este sistema

# Detecciones:
# Estoy dentro de una sesión WSL2?
export IS_WSL2=false
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  export IS_WSL2=true
fi

# Estoy dentro de una sesión VSCode?
export IS_VSCODE=false
if [[ $(printenv | grep -c "VSCODE_") -gt 0 ]]; then
    export IS_VSCODE=true
fi

# -----------------------------------------------------------------------------
# Comunes
# -----------------------------------------------------------------------------
#

# Función para averiguar la opción de usar colores en el comando ls
function test-ls-args {
  local cmd="$1"          # ls, gls, colorls, ...
  local args="${@[2,-1]}" # los argumentos excepto el primero
  command "$cmd" "$args" /dev/null &>/dev/null
}

# Parametrización de Zsh común
#
function parametriza_zsh_comun() {

  # Personalización de los colores del comando 'ls'
  # LS_COLORS se usan en ls de GNU,
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

  # Personalización de los colores del tree de GNU
  export TREE_COLORS=${LS_COLORS//04;}

  # mientras que LSCOLORS se usa en el ls de BSD
  export CLICOLOR=1
  export LSCOLORS='GxExDxDxCxDxDxFxFxexEx'

  # Bajo WSL2 se soporta ls --color
  alias ls='ls --color=tty'

  # Locales
  export LANG=es_ES.UTF-8
  export LC_CTYPE="es_ES.UTF-8"
  export LC_NUMERIC="es_ES.UTF-8"
  export LC_TIME="es_ES.UTF-8"
  export LC_COLLATE="es_ES.UTF-8"
  export LC_MONETARY="es_ES.UTF-8"
  export LC_MESSAGES="es_ES.UTF-8"
  export LC_PAPER="es_ES.UTF-8"
  export LC_NAME="es_ES.UTF-8"
  export LC_ADDRESS="es_ES.UTF-8"
  export LC_TELEPHONE="es_ES.UTF-8"
  export LC_MEASUREMENT="es_ES.UTF-8"
  export LC_IDENTIFICATION="es_ES.UTF-8"
  export LC_ALL="es_ES.UTF-8"

  # Detecto e inicializo el valor de la variable SHELL
  #
  # Si mi $SHELL acaba en */zsh o */zsh-static, no hago nada.
  # En caso contrario, hago una sustitución compleja de la variable SHELL, poniendo
  # el PATH absoluto de la shell
  [[ -o interactive ]] && \
    case $SHELL in
        */zsh) ;;
        */zsh-static) ;;
        *) SHELL=${${0#-}:c:A}
    esac

  # Variables de entorno para no enviar telemetría a Microsoft
  export DOTNET_CLI_TELEMETRY_OPTOUT=1

  # En bash, escape-delete elimina una sola palabra. Sin embargo, en ZSH hace
  # falta una variable define qué caracteres especiales se consideran parte de
  # una palabra. Esta es mi versión modificada, en la que he eliminado '/' para
  # que sea más conveniente al eliminar componentes de directorio desde la CLI.
  WORDCHARS='*?_.[]~&;!#$%^(){}<>'

  # Elimino el mensaje "Last login" en las sesiones y nuevos tabs.
  [ ! -f ~/.hushlogin ] && touch ~/.hushlogin

  # No poner líneas de comando en la lista de historial si son duplicados
  setopt HIST_IGNORE_DUPS
  # Comparte el historial entre todas las instancias
  setopt SHARE_HISTORY
  # Que no pida Y/N cuando se hace un rm -fr
  setopt RM_STAR_SILENT
  # Habilitar expansión de parñametros en el prompt, necesario para
  # mostrar información de branches de Git por ejemplo.
  setopt PROMPT_SUBST

  # Uso los keybindings emacs incluso si el editor está puesto a 'vi'
  bindkey -e

  # Mantener 1000 líneas de history
  HISTSIZE=1000
  SAVEHIST=1000
  HISTFILE=~/.zsh_history

  # Usar el sistema de auto completado moderno
  autoload -Uz compinit
  compinit
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

  # Permitir ganchos en diferentes puntos de la ejecución del shell,
  # como antes o después de un comando, permitiendo a los usuarios o scripts
  # añadir comportamientos personalizados en estos puntos.
  autoload -Uz add-zsh-hook

}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
#
# -----------------------------------------------------------------------------
# Caso: WSL2
# -----------------------------------------------------------------------------
if [ "$IS_WSL2" = true ] ; then

  # Evitar duplicados en PATH
  typeset -U path PATH

  # Bloque limpio de construcción del PATH para WSL2
  path=(
    .                                    # Prioriza . en desarrollo
    "/home/${SOY}/bin"
    "/mnt/c/Users/${SOY}/Nextcloud/priv/bin"
    "/mnt/c/Users/${SOY}/Nextcloud/priv/bin/win"
    "/mnt/c/Users/${SOY}/dev-tools/kombine.win"
    "/mnt/c/Program Files/Docker/Docker/resources/bin"
    "/mnt/c/Users/${SOY}/AppData/Local/Programs/Microsoft VS Code/bin"
    "/mnt/c/Program Files/Git/mingw64/bin"
    "/mnt/c/Windows/System32"
    "/mnt/c/Windows"
    "/mnt/c/Windows/System32/wbem"
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
    "/mnt/c/Program Files/PowerShell/7"
    "/usr/local/go/bin"
    "/usr/local/sbin"
    "/usr/local/bin"
    "/usr/sbin"
    "/usr/bin"
    "/sbin"
    "/bin"
    "/usr/games"
    "/usr/local/games"
    "/usr/lib/wsl/lib"
    $path                                # Añadir el PATH heredado al final
  )

  # Comunes
  #
  parametriza_zsh_comun

  # Alias
  alias c="cd /mnt/c/Users/${SOY}"
  alias git="git.exe"

# --------------------------------------------------------------------------------
# Caso: MacOS, Linux
# --------------------------------------------------------------------------------
else

  # PATH MacOS Y Linux -----------------------------------------------------------
  #
  case "$OSTYPE" in
    # NetBSD
    netbsd*)
      # On NetBSD, test if `gls` (GNU ls) is installed (this one supports colors);
      # otherwise, leave ls as is, because NetBSD's ls doesn't support -G
      test-ls-args gls --color && alias ls='gls --color=tty'
      ;;

    # OpenBSD
    openbsd*)
      # On OpenBSD, `gls` (ls from GNU coreutils) and `colorls` (ls from base,
      # with color and multibyte support) are available from ports.
      # `colorls` will be installed on purpose and can't be pulled in by installing
      # coreutils (which might be installed for ), so prefer it to `gls`.
      test-ls-args gls --color && alias ls='gls --color=tty'
      test-ls-args colorls -G && alias ls='colorls -G'
      ;;

    (darwin|freebsd)*)
       # PATH macOS y FreeBSD limpio con eliminación de duplicados
      typeset -U path PATH
      # Homebrew (instala en /opt/homebrew en Apple Silicon)
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # PATH ordenado
      path=(
        .                                        # Prioriza . para scripts locales
        "$HOME/Nextcloud/priv/bin"
        "/usr/local/bin"
        "/usr/local/sbin"
        "/usr/local/go/bin"
        "$HOME/dev-tools/kombine.osx"
        "/opt/homebrew/opt/ruby/bin"
        "$HOME/.gems/bin"
        "/opt/homebrew/opt/llvm@17/bin"
        $path                                   # Heredado del entorno
      )

      # También reflejar en entorno gráfico
      launchctl setenv PATH "${(j/:/)path}"

      # LLVM/Clang 17
      export CPLUS_INCLUDE_PATH="/opt/homebrew/opt/llvm@17/include"
      export LIBRARY_PATH="/opt/homebrew/opt/llvm@17/lib"
      export CC="/opt/homebrew/opt/llvm@17/bin/clang"
      export CXX="/opt/homebrew/opt/llvm@17/bin/clang++"
      export LDFLAGS="-L/opt/homebrew/opt/llvm@17/lib"
      export CPPFLAGS="-I/opt/homebrew/opt/llvm@17/include"

      # Path para shfmt
      export SHFMT_PATH="/opt/homebrew/bin/shfmt"

      # Colores para ls
      test-ls-args ls -G && alias ls='ls -G'
      zstyle -t ':omz:lib:theme-and-appearance' gnu-ls \
        && test-ls-args gls --color \
        && alias ls='gls --color=tty'

      # Terminal sin flow control (evita que Ctrl-S/Ctrl-Q congelen terminal)
      stty -ixon

      # Alias específicos macOS
      alias grep="/usr/bin/grep" # "-d skip"
      alias e="/usr/local/bin/code"
      alias pip="/opt/homebrew/bin/pip3"

      # Acelerar la navegación en recursos compartidos de red
      (defaults write com.apple.desktopservices DSDontWriteNetworkStores true &)

      # SSH - Lo arranco en el background porque tarda 1 o 2 segundos
      # De esta forma consigo el prompt inmediatamente.
      (ssh-add --apple-load-keychain >/dev/null 2>&1 &)

      # GEMS de Ruby se instalan en ~/.gems, relacionado con PATH:
      export GEM_HOME=~/.gems

      ;;
    *)
      # Linux
      typeset -U path PATH

      if [[ $EUID -eq 0 ]]; then
        # PATH para root (mantengo PATH heredado, puedes añadir si lo deseas)
        PROMPT='[%B%F{white}root%f%b]@%m:%~%# '
      else
        # PATH para usuario normal
        path=(
          .
          "$HOME/Nextcloud/priv/bin"
          "$HOME/bin"
          "/usr/local/bin"
          "/usr/local/sbin"
          "/usr/local/go/bin"
          $path
        )

        # Ejecutar agente SSH si no está en ejecución
        if [[ -z "$SSH_AUTH_SOCK" ]] || ! pgrep -u "$UID" ssh-agent &>/dev/null; then
          eval "$(ssh-agent -s)" &>/dev/null
        fi
      fi

      # Herramienta shfmt (si está instalada desde el sistema)
      export SHFMT_PATH="/usr/bin/shfmt"

      # Configuración de alias para ls (soporte GNU o BSD)
      if test-ls-args ls --color; then
        alias ls='ls --color=tty'
      elif test-ls-args ls -G; then
        alias ls='ls -G'
      fi
      ;;
  esac


  # Comunes
  #
  parametriza_zsh_comun

  # TMUX MacOS Y Linux ----------------------------------------------------------
  #
  # Este código está comentado porque no lo uso.
  #
  # Ejecución de `tmux` (si está disponible y además existe ~/.tmux.conf)
  # Esto podría haberlo configurado de dos formas. Cuando hago login con mi
  # usuario y arranza zsh. He optado por la opcion (2)
  #
  # 1) REEMPLAZA zsh por tmux - Que zsh arranque pero inmediatamente sea
  #    reemplazada por tmux
  # 2) MANTENER zsh - Que zsh arranque y me quede en él, para arrancar tmux
  #    manualmente cuando yo quiera.
  #
  # OPCION 1) REEMPLAZAR
  # [ -t 1 ]: Comprueba si el file descriptor 1 (stdout) está asociado a un terminal.
  # (( $+commands[tmux] )): Comprueba si el ejecutable tmux está en el PATH
  # [[ -f ~/.tmux.conf ]]: Compruebo si tengo el fichero  de configuración
  # $PPID != 1: Me aseguro que mi proceso padre no es 1, que significaría que esta
  # sesión se está ejecutando desde init/systemd.
  # $$ != 1: Me aseguro que mi número de proceso no es el 1, que sería un desastre ;-)
  # $TERM != dumb, linux, screen, xterm. En esos casos arranco sin tmux, por ejemplo
  # me interesa que gnome-terminal y terminator ejecuten tmux, pero xterm no.
  # -z $TMUX: Me aseguro de que no esté puesta la variable TMUX, es decir que no este
  # ya en una sesión encadenada de tmux
  # if (tmux has-session -t TMUX); Si ya hay una sesión ejecutándose me conecto con ella.
  # en caso contrario arranco una sesión nueva
  #
  # (Copia del script "t" en el PATH)
  # ------- ------- ------- ------- ------- -------
  # #!/usr/bin/env zsh
  # #By LuisPa 2024
  # #Ejecuto tmux si es que debo/puedo
  # if [ -t 1 ] && (( $+commands[tmux] )) && \
  #       [[ -f ~/.tmux.conf && \
  #                $PPID != 1 && \
  #                $$ != 1 && \
  #                $TERM != dumb && \
  #                $TERM != xterm && \
  #                $TERM != linux && \
  #                $TERM != screen* && \
  #                $IS_VSCODE != true && \
  #                -z $TMUX ]]; then
  #     if (tmux has-session -t TMUX >/dev/null 2>&1); then
  #         exec tmux attach -t TMUX >/dev/null 2>&1
  #     else
  #         exec tmux new -s TMUX >/dev/null 2>&1
  #    fi
  # fi
  # ------- ------- ------- ------- ------- -------
  #
  # OPCION 2) MANTENER
  # Como decía, podría haber dejado las líneas anteriores sin comentar que
  # provocarían que se ejecute tmux reemplazando la shell actual.
  # He optado por dejarlas comentadas y si necesito tmux lo ejecuto
  # llamando al alias 't' (con exec) o 'tt' (sin exec).
  #
  # Esta opción me da más flexibilidad, puedo elegir cuándo uso
  # tmux, lo cual es muy útil si me conecto a equipos linux remotos
  # que tienen zsh y tmux (y copia de este .zshrc, .tmux.conf, etc)
  alias t="exec ~/Nextcloud/priv/bin/t"
  alias tt="~/Nextcloud/priv/bin/t"

fi

# -----------------------------------------------------------------------------
# Oh My Posh
# -----------------------------------------------------------------------------
#
# Instrucciones de instalación
# MacOS, Windows y Linux:
#   Fuente: https://ohmyposh.dev/docs/installation/linux
#
# WSL2:
#   sudo su -
#   apt update && apt upgrade -y && apt full-upgrade -y
#   apt install unzip
#   mkdir ~/bin
#   curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/bin
#     Instala temas en /home/${SOY}/.cache/oh-my-posh/themes
#   Revisar el PATH (en mi caso ya tengo /home/${SOY}/bin en este .zshrc)
#   Salgo y entro de nuevo a WSL2
#
#   Instalo la fuente de Meslo:
#     oh-my-posh font install
#
#   La primera vez arranca con el tema por defecto, lo renombro
#    oh-my-posh config export --output ~/.luispa.omp.json
#    Solo le quité el naranja del directorio al de por defecto
#    el de por defecto es jandedobbeleer.omp.json
#
# UPGRADES: Se pueden hacer desde el CLI, pero no siempre (major):
#
# ❯ oh-my-posh upgrade (si detecta que hay un cambio de major no lo hará)
# ❯ oh-my-posh upgrade --force (para forzar la actualización)
#

#
# Primero comprobar si está Oh-My-Posh instalado
if ! command -v oh-my-posh >/dev/null 2>&1; then
  echo "Necesitas instalar 'Oh My Posh', más info en .zshrc"
else

  # Compruebo si tengo mi tema
  LOCAL_FILE=~/.luispa.omp.json
  REMOTE_FILE_URL="https://raw.githubusercontent.com/LuisPalacios/zsh-zshrc/main/.luispa.omp.json"
  TEMP_REMOTE_FILE="/tmp/.luispa.omp_remote.json"

  # Detectar el sistema operativo para usar el comando 'date' correcto
  case "$OSTYPE" in
    # MacOS
    (darwin|freebsd)*)
      ONE_DAY_AGO=$(date -v -1d +%s)
      ;;
    # Linux|WSL2
    *)
      ONE_DAY_AGO=$(date -d '1 day ago' +%s)
      ;;
  esac

  # Comprobar si el archivo local no existe
  if [[ ! -a $LOCAL_FILE ]]; then
    curl --connect-timeout 2 --max-time 3 -LJs -o $LOCAL_FILE $REMOTE_FILE_URL
    touch $LOCAL_FILE
  else
    # Verificar si se ha descargado en el último día
    if [[ "$OSTYPE" == darwin* ]]; then
      MODTIME=$(stat -f %m "$LOCAL_FILE")
    else
      MODTIME=$(stat -c %Y "$LOCAL_FILE")
    fi
    if (( MODTIME <= ONE_DAY_AGO )); then
      # Descargar el archivo remoto temporalmente
      curl --connect-timeout 2 --max-time 3 -LJs -o $TEMP_REMOTE_FILE $REMOTE_FILE_URL
      # Comprobar si el archivo local es diferente del remoto
      if ! cmp -s $LOCAL_FILE $TEMP_REMOTE_FILE; then
        # El fichero local es diferente del remoto, actualizo copiando el remoto al local
        mv $TEMP_REMOTE_FILE $LOCAL_FILE
      else
        rm $TEMP_REMOTE_FILE
      fi
      touch $LOCAL_FILE
    fi
  fi

  # Arranco Oh My Posh
  eval "$(oh-my-posh init zsh --config ~/.luispa.omp.json)"
fi

# LuisPa: -------------------------------------------------------------- END
