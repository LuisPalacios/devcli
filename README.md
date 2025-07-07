# Linux Setup

Contiene los scripts necesarios para configurar el entorno CLI en sistemas basados en Unix: **Linux**, **macOS** y **WSL2**, utilizando una única línea de instalación remota.

## 📋 Requisitos Previos

### Permisos Sudo

El usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática. Para configurar esto:

```bash
# Añadir tu usuario al grupo sudo (si no está ya)
sudo usermod -aG sudo $USER

# Configurar sudo sin contraseña (editar /etc/sudoers)
sudo visudo
# Añadir línea: $USER ALL=(ALL) NOPASSWD:ALL
```

### macOS

- **Homebrew**: Instalar desde [brew.sh](https://brew.sh) antes de ejecutar el setup

### WSL2

- WSL2 configurado y funcionando
- Distribución Linux instalada (Ubuntu recomendado)

## ⚡ Ejecución

Revisa este readme y los scripts para sentirte seguro de que lo que hacen no rompe nada de tu instalacion. Ten en cuenta que toca archivos MUY IMPORTANTES. Ejecútalo bajo tu responsabilidad y nunca lo hagas si no entiendes lo que hacen.

### Instalación Básica

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

### Instalación con Idioma Personalizado

```bash
# Instalación con idioma inglés
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -l en_US.UTF-8

# Instalación con idioma francés
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -l fr_FR.UTF-8

# Ver todas las opciones disponibles
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh) -h
```

### Idiomas Soportados

- `es_ES.UTF-8` - Español (por defecto)
- `en_US.UTF-8` - Inglés
- `fr_FR.UTF-8` - Francés
- `de_DE.UTF-8` - Alemán
- `it_IT.UTF-8` - Italiano
- `pt_PT.UTF-8` - Portugués
- `ca_ES.UTF-8` - Catalán
- `eu_ES.UTF-8` - Euskera
- `gl_ES.UTF-8` - Gallego

- Clona el repositorio en `~/.linux-setup`
- Detecta el sistema operativo (Linux, macOS, WSL2)
- Ejecuta automáticamente todos los scripts bajo `install/`
- Aplica los dotfiles y herramientas locales
- Configura el idioma especificado (por defecto: español)

## 🚀 ¿Qué hace este proyecto?

Automatiza la configuración inicial de un entorno de usuario personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

### Fases de instalación (`install/*.sh`)

#### `01-system.sh`

Configura la base mínima del sistema:

- Asegura que `~/bin` existe y está listo para recibir binarios personalizados.
- Instala herramientas esenciales como `git`, `curl`, `wget`, `nano` y `zsh` mediante `apt` (Linux/WSL2) o `brew` (macOS).
- Descarga e instala `oh-my-posh` en `~/bin`.
- En sistemas Linux y WSL2, genera la locale especificada (por defecto `es_ES.UTF-8`).

#### `02-packages.sh`

Instala utilidades adicionales útiles para el trabajo diario:

- Herramientas incluidas: `htop`, `tmux`, `fzf`, `bat`, `fd-find`, `ripgrep`, `tree`, `lsd`.
- Usa el gestor de paquetes del sistema (`apt` o `brew`) y adapta los nombres según el sistema operativo.
- Realiza verificación previa para evitar reinstalar si ya están presentes.

#### `03-dotfiles.sh`

Aplica dotfiles personalizados al entorno del usuario:

- Copia `.zshrc` y `.luispa.omp.json` desde `dotfiles/` al `HOME`.
- Si ya existen, los sobrescribe mostrando una advertencia.
- En Linux y WSL2, cambia la shell por defecto a `zsh` si no lo es ya. En macOS no realiza el cambio, ya que `zsh` es por defecto desde Catalina.

#### `04-localtools.sh`

Instala herramientas locales y configuración adicional:

- Copia utilidades personalizadas (`e`, `confcat`, `s`) desde `files/bin/` a `~/bin`.
- Aplica configuración de `nano` desde `files/etc/nanorc` a `/etc/nanorc` (solo Linux y WSL2).
- Crea directorios `.nano` en `$HOME` y `/root` si no existen (también limitado a Linux/WSL2).

## 🧠 Principios del diseño idempotente

Los scripts están diseñados para ejecutarse múltiples veces sin provocar errores ni duplicar trabajo. Muy útil para actualizarse a la última versión, simplemente ejecuta el bootstrap de nuevo.

- Solo se instalan los paquetes si no están presentes
- Los dotfiles se sobreescriben con advertencia
- Se informa claramente cada paso con logs semánticos
- Soporta configuraciones seguras sin intervención adicional

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
│   ├── 03-dotfiles.sh
│   └── 04-localtools.sh
└── README.md
```

## 🔧 Herramientas Instaladas

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

