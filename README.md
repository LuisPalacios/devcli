# devcli

![devcli](assets/old-hacker.jpg)

Me he pasado años instalando sistemas operativos, una y otra vez. Cada vez acabo echando un par de horas para sacarles brillo y dejar el entorno que me gusta. Un mismo CLI (Command Line Interface), herramientas y todo bien configurado.

El propósito de este proyecto es automatizar al máximo ese segundo paso, reducir tiempo y poder tener la misma UX en **PowerShell, CMD** o las Shell de **WSL2, macOS y Linux**, perfiles perfectamente unificados, mismo prompt, casi los mismos comandos disponibles. Que funcione igual si usas PowerShell, Terminal, Alacritty, VSCode o cualquier entorno moderno. A medida que descubra nuevas utilidades CLI que cumplan con este enfoque multiplataforma y sin dependencias pesadas, las iré incorporando.

Contiene las herramientas que yo uso, siempre puedes hacerte un fork y adaptarlo a lo que te guste.

El repositorio configura el entorno de línea de comandos (CLI) en **Linux**, **macOS**, **WSL2** o **Windows**. En vez de perder una hora configurando, este script añade las herramientas CLI, algunos ejecutables, scripts y fonts, que utilizo en mi día a día.

**Linux, macOS y WSL2** (lee los [requisitos](#-requisitos-linux-macos-y-wsl2)):

```console
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

> *wget*: `bash <(wget -qO- https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)`

**Windows 10/11** (lee los [requisitos para Windows](#-requisitos-windows)):

```console
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

> Si tu antivirus corporativo (Bitdefender, CrowdStrike, etc.) bloquea el comando anterior, usa la **instalación en dos pasos** — descarga primero, ejecuta después:
>
> ```powershell
> irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1" -OutFile "$env:TEMP\devcli-bootstrap.ps1"
> & "$env:TEMP\devcli-bootstrap.ps1"
> ```

### Perfiles de instalación

Puedes elegir qué instalar con `--profile` (bash) o `-Profile` (PowerShell):

| Perfil | Contenido | Ejemplo |
|--------|-----------|---------|
| `minimal` | Herramientas esenciales: fzf, lsd, ripgrep, bat, fd, zoxide, gping, htop | `--profile minimal` |
| `dev` | minimal + desarrollo: mkcert, uv, nss, pnpm | `--profile dev` |
| `full` | Todo (por defecto): dev + kubectl, clink, quicklook | *(sin flag)* |

```bash
# Linux/macOS/WSL2 — solo lo esencial
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p minimal
```

```powershell
# Windows — perfil de desarrollo
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile dev"
```

### Post instalación

- Reinicia el terminal para aplicar los cambios de PATH.
- Verifica Nerd Fonts: `nerd-verify.sh` (Linux/macOS/WSL2) o `nerd-verify.ps1` (Windows).
- Si los iconos no salen bien (prueba con `lsd`), ejecuta `nerd-setup.sh` o `nerd-setup.ps1`.

## Antes de ejecutar nada, lee esto

Este proyecto instala software, modifica archivos de configuración en tu HOME y cambia la shell por defecto. **Úsalo bajo tu propia responsabilidad.** Yo lo uso a diario en mis máquinas, pero tu entorno es diferente al mío.

**Recomendación**: antes de ejecutar el bootstrap, revisa los scripts para entender qué van a hacer en tu sistema. Son cortos y legibles. El orden de ejecución es:

| Fase | Script (Linux/macOS/WSL2) | Script (Windows) | Qué hace |
|------|--------------------------|-------------------|----------|
| Bootstrap | `bootstrap.sh` | `bootstrap.ps1` | Clona el repo, lanza las fases |
| 01 | `install/01-system.sh` | `install/01-system.ps1` | Paquetes base: git, curl, zsh, jq, oh-my-posh |
| 02 | `install/02-packages.sh` | `install/02-packages.ps1` | Herramientas CLI según perfil (fzf, bat, lsd, ...) |
| 03 | `install/03-dotfiles.sh` | `install/03-dotfiles.ps1` | Copia dotfiles: `.zshrc`, `.tmux.conf`, prompt, ... |
| 04 | `install/04-gitfiles.sh` | `install/04-gitfiles.ps1` | Configuración de Git (aliases, hooks, templates) |
| 05 | `install/05-localtools.sh` | `install/05-localtools.ps1` | Scripts auxiliares en `~/bin` |

Las herramientas que se instalan y sus métodos están declarados en [`install/tools.json`](install/tools.json). Los dotfiles que se copian están en [`install/03-dotfiles.json`](install/03-dotfiles.json). Todo es abierto y auditable.

> Si algo no te conviene, haz un fork y quita lo que no quieras. Es la gracia de que sea modular.

## 📋 Qué hace

Enfoque modular, multiplataforma e idempotente. Un solo comando descarga el repositorio, instala las herramientas y configura el entorno.

- Instala herramientas CLI: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd, zoxide.
- Instala Oh-My-Posh para cualquier shell.
- Establece la variable LANG (por defecto `es_ES.UTF-8`) en Linux, macOS y WSL2.
- Copia `.zshrc`, `.tmux.conf`, `.oh-my-posh`, etc. (ver subdirectorio `dotfiles`).
- Copia herramientas de Git desde el repositorio git-config-repos.
- Crea scripts en `~/bin`: e, s, confcat.
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en `lsd`.

## 🐧 Requisitos Linux, macOS y WSL2

- La versión actual solo soporta **Debian/Ubuntu** (usa `apt` para instalar software).
- Tener `curl` o `wget`.
- Tener `zsh` como shell.
  - En Linux y WSL2: [guía](https://luispa.com/posts/2024-04-23-zsh/).
  - En macOS viene por defecto.
- En macOS: `Homebrew` ([guía](https://brew.sh)).
- Usuario normal con acceso a `sudo` sin contraseña:

    ```bash
    apt install sudo
    usermod -aG sudo <usuario>
    echo "<usuario> ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-<usuario>
    ```

- Puedes ejecutar el script como `root`, útil para entornos headless.

## 🪟 Requisitos Windows

- **PowerShell 7** o superior. Descargar desde [GitHub](https://github.com/PowerShell/PowerShell/releases) o Microsoft Store.
- `winget` (viene con Windows). Compruébalo con `winget list`.
- Recomendado preinstalar **Windows Terminal** y **Scoop**:

```powershell
# Windows Terminal
winget install Microsoft.WindowsTerminal

# Scoop (modo normal)
irm get.scoop.sh | iex

# Scoop (modo administrador, si fuera necesario)
iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
```

---
