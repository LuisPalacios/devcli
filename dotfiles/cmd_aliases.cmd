@echo off
REM =============================================================================
REM Aliases para CMD - Comandos modernos estilo Unix
REM =============================================================================
REM Ubicación final: %USERPROFILE%\cmd_aliases.cmd
REM Propósito: Proporcionar aliases modernos en CMD tradicional
REM Compatible con: CMD en Windows 10/11
REM =============================================================================

REM Alias para listado moderno con lsd
doskey ls=lsd --group-directories-first $*

REM Aliases adicionales útiles
REM doskey ll=lsd --group-directories-first -l $*
REM doskey la=lsd --group-directories-first -a $*
REM doskey lla=lsd --group-directories-first -la $*

REM Alias para navegación rápida
REM doskey ..=cd ..
REM doskey ...=cd ..\..

REM Alias para herramientas modernas (si están instaladas)
doskey cat=bat $*
doskey find=fd $*
doskey grep=rg $*

echo Aliases CMD cargados correctamente.
