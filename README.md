# Linux Setup

Configura el entorno CLI en sistemas basados en Unix: **Linux**, **macOS** y **WSL2**, utilizando una única línea de instalación. Estaba ya cansado de que cada vez que instalo uno de estos sitemas me lleva un par de horas parametrizándolo, instalar tools, fuentes, scripts de ayuda. He creado este repo para automatizarlo con un solo comando.

## 📋 Requisitos

Tu usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática. Para configurar esto:

```bash
# Añadir tu usuario al grupo sudo (si no está ya)
sudo usermod -aG sudo $USER

# Configurar sudo sin contraseña (editar /etc/sudoers)
sudo visudo
# Añadir línea: $USER ALL=(ALL) NOPASSWD:ALL
```

En macOS utilizo **Homebrew**: Instalar desde [brew.sh](https://brew.sh) antes de ejecutar el setup

En WSL2, necesitas tenerlo configurado y funcionando. Yo siempre uso Ubuntu como distribución Linux.

## ⚡ Ejecución

> Revisa este documento y los scripts para sentirte seguro de que lo que hacen **no rompe nada de tu instalación**. Ten en cuenta que toca archivos MUY IMPORTANTES. Ejecútalo bajo tu responsabilidad y nunca lo hagas si no entiendes lo que hacen.

### Instalación Básica

Ejecuta este comando. Para cambiar el idioma mira Personalización de Idioma, más adelante.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

- Clona el repositorio en `~/.linux-setup`
- Detecta el sistema operativo (Linux, macOS, WSL2)
- Ejecuta automáticamente todos los scripts bajo `install/`
- Aplica los dotfiles y herramientas locales
- Configura el idioma especificado (por defecto: español)

## 🚀 ¿Qué hace este proyecto?

Automatiza la configuración inicial de un entorno personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

### Fases de instalación (`install/*.sh`)

#### `01-system.sh`

Configura la base mínima del sistema:

- Asegura que `~/bin` existe y está listo para recibir binarios personalizados.
- Instala herramientas esenciales como `git`, `curl`, `wget`, `nano` y `zsh` mediante `apt` (Linux/WSL2) o `brew` (macOS).
- Descarga e instala `oh-my-posh` en `~/bin`.
- En sistemas Linux y WSL2, genera la locale especificada (por defecto `es_ES.UTF-8`).

#### `02-packages.sh`

Instala utilidades adicionales útiles para el trabajo diario:

- Lee configuración desde `install/02-packages.json`.
- Herramientas incluidas: `htop`, `tmux`, `fzf`, `bat`, `fd-find`, `ripgrep`, `tree`, `jq`, `lsd`.
- Usa el gestor de paquetes del sistema (`apt` o `brew`) y adapta los nombres según el sistema operativo.
- Realiza verificación previa para evitar reinstalar si ya están presentes.

#### `03-dotfiles.sh`

Aplica dotfiles personalizados al entorno del usuario:

- Copia `.zshrc` y `.luispa.omp.json` desde `dotfiles/` al `HOME`.
- Si ya existen, los sobrescribe mostrando una advertencia.
- En Linux y WSL2, cambia la shell por defecto a `zsh` si no lo es ya. En macOS no realiza el cambio, ya que `zsh` es por defecto desde Catalina.

#### `04-gitfiles.sh`

Clona repositorios Git temporales y copia archivos específicos:

- Lee configuración desde `install/04-gitfiles.json`.
- Clona temporalmente repositorios especificados en el JSON.
- Copia archivos específicos desde los repositorios a `~/bin`.
- Aplica permisos 755 automáticamente (excepto archivos `.ps1`).
- Limpia automáticamente los directorios temporales después de la copia.

#### `05-localtools.sh`

Instala herramientas locales y configuración adicional:

- Lee configuración desde `install/05-localtools.json`.
- Copia utilidades personalizadas (`e`, `confcat`, `s`, `nerd-setup.sh`, `nerd-verify.sh`) desde `files/bin/` a `~/bin`.
- Aplica configuración de `nano` desde `files/etc/nanorc` a `/etc/nanorc` (solo Linux y WSL2).
- Crea directorios `.nano` en `$HOME` y `/root` si no existen (también limitado a Linux/WSL2).

## 🧠 Principios del diseño idempotente

Los scripts están diseñados para ejecutarse múltiples veces sin provocar errores ni duplicar trabajo. Muy útil para actualizarse a la última versión, simplemente ejecuta el bootstrap de nuevo.

- **Paquetes del sistema**: Solo se instalan si no están presentes
- **lsd**: Verifica si ya está instalado antes de descargar desde GitHub
- **Nerd Fonts**: Verifica si las fuentes ya están instaladas antes de descargar
- **Dotfiles**: Se sobreescriben con advertencia y backup automático
- **Logging mejorado**: Informa claramente cada paso con logs semánticos
- **Configuración segura**: Soporta ejecuciones múltiples sin intervención

Una vez que termina de ejecutarse, algunas verificaciones que puedes hacer

```bash
# Verificar herramientas instaladas
command -v lsd && echo "lsd está instalado" || echo "lsd no está instalado"

# Verificar fuentes instaladas
fc-list | grep "FiraCode Nerd Font" && echo "Fuentes instaladas" || echo "Fuentes no instaladas"

# Verificar paquetes del sistema
dpkg -s git >/dev/null 2>&1 && echo "git instalado" || echo "git no instalado"
```

## 🗂 Estructura del repositorio

```sh
.
├── bootstrap.sh           # Script principal de instalación remota
├── dotfiles/              # Dotfiles como .zshrc y configuración de oh-my-posh
├── files/                 # Herramientas personalizadas y config de nano
│   ├── bin/               # Ejecutables locales: e, s, confcat
│   └── etc/               # Configuración de /etc/nanorc
├── install/               # Scripts de instalación por fases
│   ├── env.sh             # Variables de entorno compartidas
│   ├── utils.sh           # Utilidades compartidas
│   ├── 01-system.sh
│   ├── 02-packages.sh
│   ├── 02-packages.json   # Configuración de paquetes
│   ├── 03-dotfiles.sh
│   ├── 04-gitfiles.sh
│   ├── 04-gitfiles.json   # Configuración de repositorios Git
│   ├── 05-localtools.sh
│   └── 05-localtools.json # Configuración de herramientas locales
└── README.md
```

## 🔧 Herramientas Instaladas

### Configuración de Gitfiles

El proyecto incluye un sistema modular para clonar repositorios Git temporales y copiar archivos específicos. La configuración se define en `install/04-gitfiles.json`. Este es un ejemplo:

```json
{
  "repositories": [
    {
      "url": "https://github.com/LuisPalacios/git-config-repos",
      "files": [
        "./git-config-repos.sh",
        "./git-status-pull.ps1",
        "./git-status-pull.sh"
      ]
    }
  ]
}
```

**Características:**

- **Clonación temporal**: Los repositorios se clonan en `/tmp` y se limpian automáticamente
- **Permisos automáticos**: Archivos `.sh` y otros ejecutables reciben permisos 755, `.ps1` mantiene permisos originales
- **Idempotente**: Se puede ejecutar múltiples veces
- **Manejo de errores**: Continúa con otros repositorios si uno falla

### Herramientas del Sistema

- `git` - Control de versiones
- `curl`, `wget` - Descarga de archivos
- `nano` - Editor de texto
- `zsh` - Shell avanzado

### Herramientas de Productividad

- `htop` - Monitor de procesos
- `tmux` - Multiplexor de terminal
- `fzf` - Búsqueda fuzzy
- `bat` - Cat con syntax highlighting
- `ripgrep` - Búsqueda rápida en archivos
- `tree` - Visualización de directorios
- `lsd` - ls moderno

### Herramientas Locales

- `e` - Alias para nano
- `confcat` - Cat sin comentarios
- `s` - Acceso rápido a sudo
- `nerd-setup.sh` - Configuración automática de terminal con Nerd Fonts
- `nerd-verify.sh` - Verificación completa de Nerd Fonts

## 🎨 Nerd Fonts y lsd

### Instalación Automática

El proyecto instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`:

- **Fuente**: FiraCode Nerd Font v3.1.1
- **Ubicación**: `~/.local/share/fonts/`
- **Configuración**: Automática durante la instalación

### Configuración de Terminal

Después de la instalación, configura tu terminal para usar la fuente:

```bash
# Configuración automática (detecta tu terminal)
nerd-setup.sh auto | <nombre del terminal>
```

### Verificación

```bash
# Verificación completa de Nerd Fonts
nerd-verify.sh

# Verificar que las fuentes están instaladas
fc-list | grep "FiraCode Nerd Font"

# Verificar que lsd funciona con iconos
lsd --version
```

## 🌍 Personalización de Idioma

El proyecto soporta múltiples idiomas mediante el argumento `-l` o `--lang`:

```bash
# Ejemplos de uso
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -l en_US.UTF-8
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -l fr_FR.UTF-8
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -l de_DE.UTF-8
```

### Configuración Aplicada

- **Locale del sistema**: Configura `LANG`, `LC_ALL`, etc.
- **Dotfiles**: Adapta la configuración según el idioma
- **Herramientas**: Configura herramientas para el idioma especificado

## ✅ Resultados de Pruebas

### Tabla de Compatibilidad

| Sistema | Detección | Fuentes | Configuración<br>fuentes |
|---------|-----------|---------|---------------|
| **macOS (iTerm2)** | ✅ Correcta | ✅ Instaladas | ✅ Automática |
| **Linux Headless** | ✅ SSH detectado | ✅ Instaladas | ⚠️ Manual requerida |
| **Linux Normal** | ✅ GNOME detectado | ✅ Instaladas | ✅ Automática |
| **WSL2** | ✅ WSL detectado | ✅ Instaladas | ✅ Automática |
