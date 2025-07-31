# CLI Setup

Configura el entorno CLI en **Linux**, **macOS**, **WSL2** y **Windows**. Estaba ya cansado de perder un par de horas cuando tengo que configurarme uno de esos sistemas y añadir mis tipicas herramientas CLI, ejecutables, scripts o fuentes.

**⚡ Linux, macOS y WSL2** (lee antes la sección Requisitos):

```console
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

**⚡ Windows 10/11** (lee antes la sección Requisitos):

```console
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

## 📋 Introducción

Con un solo comando descarga este repositorio e instale scripts, ejecutables y parametriza el CLI.

> IMPORTANTE: Lee este readme, se modifican archivos muy importantes, asegúrate de que **no rompe nada de tu instalación** y ejecútalo bajo tu responsabilidad. Si no entiendes que hace todo esto, no lo ejecutes.

Con un enfoque modular, multiplataforma e idempotente.

- Instala herramientas como: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd, zoxide
- Instala Oh-My-Posh, para cualquier Shell, dicen que es el mejor prompt.
- Establece la variable LANG (por defecto a `s_ES.UTF-8`) en linux, macOS y WSL2
- Copia ficheros importanttes de configuración (ver el subdirectorio `dotfiles`)
- Copia algunas herramientas de Git que tengo en el repositorio git-config-repos.
- Crea unos cuantos scripts en ~/bin que uso con frecuencia: e, s, confcat
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`.

## 🐧 Requisitos Linux, macOS y WSL2

Tu sistema debe tener instalado `curl o wget` y el usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática.

- Añadir tu usuario al grupo sudo: `sudo usermod -aG sudo $USER`
- Archivo `/etc/sudoers.d/10-usuario` > `<usuario> ALL=(ALL) NOPASSWD:ALL`

En macOS tienes que tener preinstalado **Homebrew** - mira cómo en [brew.sh](https://brew.sh)

Después de la instalación verifica Nerd Fonts: `nerd-verify.sh` y `fc-list | grep "FiraCode Nerd Font"`. Comprueba si los iconos salen bien (i.e. `lsd --version`. Si no funciona, ejecuta lo siguiente: `nerd-setup.sh`.

**Nota:** si no tienes curl en Linux/WSL2/... y quieres usar *wget* el comando sería:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

## 🪟 Requisitos Windows

Configuración automatizada para **Windows 11** (y Windows 10) usando **PowerShell** y **winget**.

- Windows 11 (recomendado) o Windows 10 con las últimas actualizaciones
- PowerShell 7.0 o superior (descargar desde [GitHub](https://github.com/PowerShell/PowerShell/releases) o Microsoft Store)
- Necesitas tener `winget` instalado desde Microsoft Store
- Permisos para instalar aplicaciones con winget

> **Nota sobre PowerShell 7**: Lo prefiero para aprovechar las mejoras en sintaxis moderna, mejor manejo de errores y compatibilidad mejorada con las herramientas CLI actuales.

Después de la instalación **reiniciar el terminal** para aplicar los cambios de PATH. Luego verifica Nerd Fonts: `nerd-verify.ps1` y si no funciona, ejecuta lo siguiente: `nerd-setup.ps1`

## 🧰 Notas adicionales

Los gestores de paquetes utilizados para realizar las diferentes instalaciones dependen del sistema operativo. En Linux/WSL2 uso `apt`, en macOS `brew`, en Windows uso `scoopt` para herramientas del CLI y `winget` para aplicaciones complejas GUI.
