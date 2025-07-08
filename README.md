# Linux Setup

Configura el entorno CLI en sistemas basados en Unix, **Linux**, **macOS** y **WSL2**. Estaba ya cansado de perder un par de horas con sistemas nuevos, parametrizar, herramientas, fuentes, scripts de ayuda. Lo automatizo todo con un solo comando.

## 📋 Requisitos

Tu usuario debe tener acceso a `sudo` sin contraseña para que la instalación sea completamente automática.

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

> IMPORTANTE: Lee este readme, se modifican archivos muy importantes, asegúrate de que **no rompe nada de tu instalación**. Ejecútalo bajo tu responsabilidad y nunca lo hagas si no entiendes lo que hace.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

- Por defecto usa `es_ES.UTF-8`, puedes cambiarlo: `bash <(curl -fsSL .../bootstrap.sh) -l en_US.UTF-8`
- Clona el repositorio en `~/.linux-setup`, detecta el sistema operativo (Linux, macOS, WSL2)
- Ejecuta automáticamente todos los scripts bajo `install/`
- Aplica los dotfiles y herramientas locales

## 🚀 ¿Qué hace este proyecto?

Automatiza la configuración inicial de un entorno personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

### Fases de instalación (`install/*.sh`)

#### `01-system.sh`

Configura la base mínima del sistema:

- Asegura que `~/bin` existe y está listo para recibir binarios personalizados.
- Instala herramientas esenciales obligatorias: `git`, `curl`, `wget`, `nano`, `zsh` y `~/bin/oh-my-posh`.
- En sistemas Linux y WSL2, genera el locale.

#### `02-packages.sh`

Instala utilidades adicionales útiles para el trabajo diario:

- Lee configuración desde `install/02-packages.json`.
- Usa el gestor de paquetes del sistema (`apt` o `brew`) con nombres específicos por OS.
- Realiza verificación previa para evitar reinstalar si ya están presentes.

#### `03-dotfiles.sh`

Aplica dotfiles personalizados al entorno del usuario:

- Copia `.zshrc` y `.luispa.omp.json` desde `dotfiles/` al `HOME`.
- Si ya existen, los sobrescribe.
- En Linux y WSL2, cambia la shell por defecto a `zsh`. En macOS no realiza el cambio, ya que `zsh` viene por defecto desde Catalina.

#### `04-gitfiles.sh`

Clona repositorios Git temporales y copia archivos específicos:

- Lee configuración desde `install/04-gitfiles.json`.
- Clona temporalmente repositorios especificados en el JSON.
- Copia archivos específicos desde los repositorios a `~/bin`.
- Limpia automáticamente los directorios temporales después de la copia.

#### `05-localtools.sh`

Instala herramientas locales y configuración adicional:

- Lee configuración desde `install/05-localtools.json`.
- Copia utilidades personalizadas desde `files/bin/` a `~/bin`.
- Aplica configuración de `nano` desde `files/etc/nanorc` a `/etc/nanorc` (solo Linux y WSL2).
- Crea directorios `.nano` en `$HOME` y `/root` si no existen (también limitado a Linux/WSL2).

## 🎨 Nerd Fonts y lsd

### Instalación Automática

El proyecto instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`. Después de la instalación, puede que necesites configurar tu terminal para usar la fuente:

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

## ✅ Resultados de pruebas

| Sistema | Detección | Fuentes | Configuración<br>fuentes |
|---------|-----------|---------|---------------|
| **macOS (iTerm2)** | ✅ Correcta | ✅ Instaladas | ✅ Automática |
| **Linux Headless** | ✅ SSH detectado | ✅ Instaladas | ⚠️ Manual requerida |
| **Linux Normal** | ✅ GNOME detectado | ✅ Instaladas | ✅ Automática |
| **WSL2** | ✅ WSL detectado | ✅ Instaladas | ✅ Automática |
