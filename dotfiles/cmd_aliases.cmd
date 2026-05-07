@echo off
REM =============================================================================
REM Aliases para CMD - Comandos modernos estilo Unix
REM =============================================================================
REM Ubicación final: %USERPROFILE%\cmd_aliases.cmd
REM Propósito: Proporcionar aliases modernos en CMD tradicional
REM Compatible con: CMD en Windows 10/11
REM =============================================================================

REM Variables de color para eza/lsd (process-scope, mismo patrón que
REM bashrc/zshrc/PS profile). Sin "setx" — el dotfile es la fuente de verdad.
set "LS_COLORS=fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32:*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32:*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31:*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31:*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31:*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35:*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35:*.dl=01;35:*.gl=01;35:*.wmv=01;35"
set "EZA_COLORS=uu=38;5;230:gu=38;5;187:ur=32:uw=33:ux=31:ue=31:gr=32:gw=33:gx=31:tr=32:tw=33:tx=31:su=38;5;5:sf=38;5;5:xa=36:oc=38;5;6:sn=38;5;245:nb=38;5;229:nk=38;5;229:nm=38;5;216:ng=38;5;172:nt=38;5;172:ub=38;5;229:uk=38;5;229:um=38;5;216:ug=38;5;172:ut=38;5;172:da=38;5;36:in=38;5;13:lc=38;5;13:xx=38;5;245:ga=32:gm=33:gd=31:gv=32:gt=33:gi=38;5;245:gc=31"

REM Alias para listado moderno con eza (si fallara, tipear `lsd` directamente).
REM Sin --group-directories-first: sort alfabético interleaved.
doskey ls=eza --icons=auto --color=auto --git $*

REM Aliases adicionales útiles
REM doskey ll=eza -lh --icons=auto --color=auto --git $*
REM doskey la=eza -a --icons=auto --color=auto --git $*
REM doskey lla=eza -la --icons=auto --color=auto --git $*

REM Alias para navegación rápida
REM doskey ..=cd ..
REM doskey ...=cd ..\..

REM Alias para herramientas modernas (si están instaladas)
doskey cat=bat $*
doskey find=fd $*
doskey grep=rg $*

REM Alias para git status
doskey gst=git --status

echo Aliases CMD cargados correctamente.
