# CLI Setup

Me he pasado años instalando sistemas operativos, una y otra vez. Cada vez acabo echando un par de horas para sacarles brillo y dejar el entorno que me gusta. Un mismo CLI (Command Line Interface), herramientas y todo bien configurado.

El proposito de este proyecto es automatizar al máximo ese segundo paso, reducir tiempo y poder tener la misma UX en **PowerShell, CMD** o las Shell de **WSL2, macOS y Linux**, perfiles perfectamente unificados, mismo prompt, casi los mismos comandos disponibles. Que funcione igual si usas PowerShell, Terminal, Alacritty, VSCode o cualquier entorno moderno. A medida que descubra nuevas utilidades CLI que cumplan con este enfoque multiplataforma y sin dependencias pesadas, las iré incorporando.

Contiene las herramientas que yo uso, siempre puedes hacerte un fork y adaptarlo a lo que te guste.

El repositorio configura el entorno de línea de comandos (CLI) en **Linux**, **macOS**, **WSL2** o **Windows**. En vez de perder una hora configurando, este script añade las herramientas CLI, algunos ejecutables, scripts y fonts, que utilizo en mi día a día.

**⚡ Linux, macOS y WSL2** (lee los "[requisitos](#-requisitos-linux-macos-y-wsl2)"):

```console
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

> *wget*: `bash <(wget -qO- https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)`

*Post instalación*:

- Verifica Nerd Fonts: `nerd-verify.sh` y `fc-list | grep "FiraCode Nerd Font"`.
- Comprueba si los iconos salen bien (i.e. `lsd --version`.
- Si no funciona, ejecuta `nerd-setup.sh`.

**⚡ Windows 10/11** (lee los "[requisitos para windows](#-requisitos-linux-macos-y-wsl2)"):

```console
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

*Post instalación*:

- Reinicia el terminal para aplicar los cambios de PATH.
- Verifica Nerd Fonts: `nerd-verify.ps1`
- Si no funciona, ejecuta: `nerd-setup.ps1`

## 📋 TLDR

Un solo comando descarga este repositorio, instala scripts, ejecutables y parametriza el CLI.

> IMPORTANTE, se modifican archivos importantes, asegúrate de que **no rompe nada de tu instalación** y ejecútalo bajo tu responsabilidad. Si no entiendes que hace, no lo ejecutes.

Enfoque modular, multiplataforma e idempotente.

- Instala herramientas como: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd, zoxide
- Instala Oh-My-Posh, para cualquier Shell, dicen que es el mejor prompt.
- Establece la variable LANG (por defecto a `es_ES.UTF-8`) en linux, macOS y WSL2
- Copia `.zshrc`, `.tmux.conf`, `.oh-my-posh`, ... ver el subdirectorio `dotfiles`.
- Copia algunas herramientas de Git que tengo en el repositorio git-config-repos.
- Crea unos cuantos scripts en ~/bin que uso con frecuencia: e, s, confcat
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`.

## 🐧 "Requisitos" Linux, macOS y WSL2

- La versión actual **🧰 solo soporta DEBIAN/UBUNTU** -> uso `apt` para instalar software.
- Tener  `curl o wget`
- Tener `zsh` como shell.
  - En Linux y WSL2 > [guía](https://luispa.com/posts/2024-04-23-zsh/).
  - En macOS viene por defecto.
- En macOS `Homebrew` > [guía](https://brew.sh)
- Usuario normal > Acceso a `sudo` sin contraseña.

    ```bash
    apt install sudo
    usermod -aG sudo <usuario>
    echo "<usuario> ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-<usuario>
    ```

- Puedes ejecutar el script como `root` para parametrizarlo igual, útil para entornos headless.

## 🪟 Requisitos Windows

Necesitarás tener **PowerShell 7** y **winget**.

- Instala y ejecuta `winget list` para aceptar.

- PowerShell 7.0 o superior en modo Administrador. Descargar desde [GitHub](https://github.com/PowerShell/PowerShell/releases) o Microsoft Store

- Recomendado preinstalar **Windows Terminal** y **scoop**:

```PowerShell
# Instalar Windows Terminal
winget install Microsoft.WindowsTerminal

# Instalar Scoop
irm get.scoop.sh | iex

# Instalar Scoop en modo Administrador (si lo necesitases)
iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
```

## ToDo

Añadir soporte a otras distribuciones y métodos de instalación en Linux.

---
