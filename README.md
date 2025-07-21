# CLI Setup

Configura el entorno CLI en **Linux**, **macOS**, **WSL2** y **Windows**. Estaba ya cansado de perder un par de horas cuando tengo que configurarme uno de esos sistemas y añadir mis tipicas herramientas CLI, ejecutables, scripts o fuentes.

Lo automatizo todo con un solo comando que descarga este repositorio y procede a instalar todo lo que necesito.

> IMPORTANTE: Lee este readme, se modifican archivos muy importantes, asegúrate de que **no rompe nada de tu instalación** y ejecútalo bajo tu responsabilidad. Si no entiendes que hace todo esto, no lo ejecutes.

Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`:

- Instala herramientas como: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd
- Instala Oh-My-Posh, para cualquier Shell, dicen que es el mejor prompt.
- Establece la variable LANG (por defecto a `s_ES.UTF-8`) en linux, macOS y WSL2
- Copia ficheros importanttes de configuración (ver el subdirectorio `dotfiles`)
- Copia algunas herramientas de Git que tengo en el repositorio git-config-repos.
- Crea unos cuantos scripts en ~/bin que uso con frecuencia: e, s, confcat
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`.

## Linux, macOS y WSL2

Tu usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática.

- Añadir tu usuario al grupo sudo: `sudo usermod -aG sudo $USER`
- Archivo `/etc/sudoers.d/10-usuario` > `<usuario> ALL=(ALL) NOPASSWD:ALL`

En macOS tienes que tener preinstalado **Homebrew** - mira cómo en [brew.sh](https://brew.sh)

**⚡ Ejecución en Linux, macOS y WSL2**:

```console
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

Después de la instalación verifica Nerd Fonts: `nerd-verify.sh` y `fc-list | grep "FiraCode Nerd Font"`. Comprueba si los iconos salen bien (i.e. `lsd --version`. Si no funciona, ejecuta lo siguiente: `nerd-setup.sh`

## Windows

Configuración automatizada para **Windows 11** (y Windows 10) usando **PowerShell** y **winget**.

Requisitos

- Windows 11 (recomendado) o Windows 10 con las últimas actualizaciones
- PowerShell 7.0 o superior (descargar desde [GitHub](https://github.com/PowerShell/PowerShell/releases) o Microsoft Store)
- App Installer (winget) instalado desde Microsoft Store
- Permisos para instalar aplicaciones con winget

> **Nota sobre PowerShell 7**: Lo prefiero para aprovechar las mejoras en sintaxis moderna, mejor manejo de errores y compatibilidad mejorada con las herramientas CLI actuales.

**⚡ Ejecución en Linux, macOS y WSL2**:

```console
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

Después de la instalación **reiniciar el terminal** para aplicar los cambios de PATH. Luego verifica Nerd Fonts: `nerd-verify.ps1` y si no funciona, ejecuta lo siguiente: `nerd-setup.ps1`

## 🧰 Gestores de paquetes utilizados

| Sistema Operativo     | Gestor de Paquetes | Rol Principal                                      | ¿Por qué lo uso?                                                                 |
|------------------------|--------------------|----------------------------------------------------|------------------------------------------------------------------------------------|
| 🐧 Linux (Debian/Ubuntu) | `apt`              | Gestor nativo del sistema                          | Estándar en Debian/Ubuntu, robusto, bien mantenido, con soporte oficial           |
| 🐧 WSL2 (Ubuntu)        | `apt`              | Paquetes de sistema y herramientas Unix            | Mismo entorno que Linux, total compatibilidad, sin reinventar la rueda            |
| 🍎 macOS               | `brew`             | CLI tools, apps de usuario, compilación cruzada    | Flexible, no requiere admin, ecosistema maduro para devs                          |
| 🪟 Windows 11          | `scoop`            | Utilidades CLI portables, estilo Unix              | Limpio, sin UAC, sin registro, scriptable, ideal para herramientas de desarrollo y cualquier "herramientas" del CLI.  |
| 🪟 Windows 11          | `winget`           | Aplicaciones GUI y binarios estándar               | Mantenido por Microsoft, buena integración con Store y apps Win32. Lo uso para aplicaciones complejas GUI.  |
