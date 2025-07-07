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

Ejecución del bootstrap:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

- Clona el repositorio en `~/.linux-setup`
- Detecta el sistema operativo (Linux, macOS, WSL2)
- Ejecuta automáticamente todos los scripts bajo `install/`
- Aplica los dotfiles y herramientas locales

## 🚀 ¿Qué hace este proyecto?

Automatiza la configuración inicial de un entorno de usuario personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

### Fases de instalación (`install/*.sh`)

#### `01-system.sh`

Configura la base mínima del sistema:

- Asegura que `~/bin` existe y está listo para recibir binarios personalizados.
- Instala herramientas esenciales como `git`, `curl`, `wget`, `nano` y `zsh` mediante `apt` (Linux/WSL2) o `brew` (macOS).
- Descarga e instala `oh-my-posh` en `~/bin`.
- En sistemas Linux y WSL2, genera la locale `es_ES.UTF-8` si no existe.

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

## ✅ ToDo

- [x] Añadir sección Requisitos con tema sudo
- [x] Revisar deteccion OS y sacarlo a `.sh` externo, que usen todos los `.sh`
- [x] Crear un fichero de variables de entorno para configurar `locale`, `LANG`, etc., y así hacerlo completamente agnóstico al entorno.
- [x] Eliminar cualquier dependencia de usuario `luis` o rutas codificadas, para asegurar portabilidad entre usuarios.
- [ ] Añadir integración opcional con gestores de dotfiles como [`chezmoi`](https://www.chezmoi.io/) o [`stow`](https://www.gnu.org/software/stow/).
- [ ] Incluir más herramientas útiles para desarrollo y productividad: configuración avanzada de `vim`, `git`, `tmux`, etc.
- [ ] Detectar si el entorno es remoto (por ejemplo, una sesión SSH o entorno virtualizado) para adaptar la configuración automáticamente.
- [ ] Añadir opciones de configuración personalizables
- [ ] Implementar rollback en caso de error
- [ ] Añadir tests automatizados
