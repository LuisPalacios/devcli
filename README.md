# CLI Setup

Configura el entorno CLI en sistemas basados en Unix, **Linux**, **macOS** y **WSL2** y para **Windows**. Estaba ya cansado de perder un par de horas cuando tengo que configurarme uno de esos sistemas y añadir las herramientas CLI, ejecutables, scripts o fuentes, que siempre quiero tener disponibles

Lo automatizo todo con un solo comando que se puede ejecutar en el terminal, descarga este repositorio y procede a instalar todo lo que quiero.

> IMPORTANTE: Lee este readme, se modifican archivos muy importantes, asegúrate de que **no rompe nada de tu instalación** y ejecútalo bajo tu responsabilidad. Si no entiendes que hace todo esto, no lo ejecutes.

## Linux, macOS y WSL2

Tu usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática.

```bash
# Añadir tu usuario al grupo sudo (si no está ya)
sudo usermod -aG sudo $USER

# Configurar sudo sin contraseña (editar /etc/sudoers)
sudo visudo
# Añadir línea: $USER ALL=(ALL) NOPASSWD:ALL
```

En macOS tienes que tener preinstalado **Homebrew** - mira cómo en [brew.sh](https://brew.sh)

### ⚡ Ejecución

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

Usa por defecto `es_ES.UTF-8`, puedes cambiarlo: `bash <(curl -fsSL .../bootstrap.sh) -l en_US.UTF-8`

Automatiza la configuración inicial de un entorno personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

- Herramientas: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd
- El mejor prompt, Oh-My-Posh, para cualquier Shell.
- Establece la variable LANG (por defecto a ``es_ES.UTF-8`)
- Copia mis ficheros ~/.luispa.omp.json y ~/.zshrc
- Herramientas de Git que tengo en el repositorio git-config-repos.
- Crea unos cuantos scripts en ~/bin que uso con frecuencia: e, s, confcat
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`.

Post instalación (fuentes): puede que necesites configurar tu terminal para usar la fuente:

```bash
# Configuración automática (detecta tu terminal)
nerd-setup.sh auto | <nombre del terminal>
```

```bash
# Verificación completa de Nerd Fonts
nerd-verify.sh

# Verificar que las fuentes están instaladas
fc-list | grep "FiraCode Nerd Font"

# Verificar que lsd funciona con iconos
lsd --version
```

## Windows

PENDIENTE
