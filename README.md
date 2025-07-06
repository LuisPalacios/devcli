# Linux Setup

Este repositorio contiene los scripts necesarios para configurar desde cero un entorno personal de terminal en sistemas basados en Unix: **Linux**, **macOS** y **WSL2**, utilizando una única línea de instalación remota.

## 🚀 ¿Qué hace este proyecto?

Automatiza la preparación de tu entorno de usuario, aplicando una serie de configuraciones idempotentes que incluyen:

- Instalación de **paquetes esenciales** y utilidades avanzadas
- Configuración de entorno Zsh: `.zshrc`, `oh-my-posh`, `locale`, etc.
- Aplicación de **dotfiles personalizados**
- Instalación de herramientas locales (`e`, `s`, `confcat`) en `~/bin`
- Configuración opcional de `nano` y locales (solo en Linux/WSL2)
- Soporte multiplataforma con detección automática de sistema:
  - `linux`
  - `macos`
  - `wsl2`

## ⚡ Instalación remota rápida

Puedes preparar tu equipo con una sola línea de comando:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

Este comando:

- Clona el repositorio en `~/.linux-setup`
- Detecta el sistema operativo (Linux, macOS, WSL2)
- Ejecuta automáticamente todos los scripts bajo `install/`
- Aplica los dotfiles y herramientas locales

## 🧠 Principios del diseño idempotente

Los scripts están diseñados para ejecutarse varias veces sin provocar errores ni duplicar trabajo:

- Solo se instalan los paquetes si no están presentes
- Los dotfiles se sobreescriben con advertencia
- Se informa claramente cada paso con logs semánticos
- Soporta configuraciones seguras sin intervención adicional

🗂 Estructura del repositorio

```sh
.
├── bootstrap.sh           # Script principal de instalación remota
├── dotfiles/              # Dotfiles como .zshrc y configuración de oh-my-posh
├── files/                 # Herramientas personalizadas y config de nano
│   ├── bin/               # Ejecutables locales: e, s, confcat
│   └── etc/               # Configuración de /etc/nanorc
├── install/               # Scripts de instalación por fases
│   ├── 01-system.sh
│   ├── 02-packages.sh
│   ├── 03-dotfiles.sh
│   └── 04-localtools.sh
└── README.md
```

## ✅ ToDo

- Crear un fichero de variables de entorno para configurar `locale`, `LANG`, etc., y así hacerlo completamente agnóstico al entorno.
- Eliminar cualquier dependencia de usuario `luis` o rutas codificadas, para asegurar portabilidad entre usuarios.
- Añadir integración opcional con gestores de dotfiles como [`chezmoi`](https://www.chezmoi.io/) o [`stow`](https://www.gnu.org/software/stow/).
- Incluir más herramientas útiles para desarrollo y productividad: configuración avanzada de `vim`, `git`, `tmux`, etc.
- Detectar si el entorno es remoto (por ejemplo, una sesión SSH o entorno virtualizado) para adaptar la configuración automáticamente.
