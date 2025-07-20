# CLI Setup

Configura el entorno CLI en **Linux**, **macOS**, **WSL2** y **Windows**. Estaba ya cansado de perder un par de horas cuando tengo que configurarme uno de esos sistemas y añadir mis tipicas herramientas CLI, ejecutables, scripts o fuentes.

Lo automatizo todo con un solo comando que descarga este repositorio y procede a instalar todo lo que necesito.

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

### ⚡ Ejecución en Linux, macOS y WSL2

<div style="
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  padding: 20px;
  margin: 20px 0;
  box-shadow: 0 8px 32px rgba(102, 126, 234, 0.3);
  border: 1px solid rgba(255, 255, 255, 0.2);
">
  <div style="
    background: #1e1e1e;
    border-radius: 8px;
    padding: 16px;
    font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
    position: relative;
    overflow: hidden;
  ">
    <div style="
      color: #00ff00;
      font-size: 14px;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
    ">
      <span style="margin-right: 8px;">🚀</span>
      <strong>Ejecutar en Terminal:</strong>
    </div>
    <div style="
      background: #2d2d2d;
      border-radius: 6px;
      padding: 12px;
      border-left: 4px solid #00ff00;
    ">
      <code style="
        color: #ffffff;
        font-size: 14px;
        line-height: 1.4;
        display: block;
        word-break: break-all;
      ">bash &lt;(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)</code>
    </div>
    <div style="
      margin-top: 8px;
      font-size: 12px;
      color: #888;
      text-align: right;
    ">
      ← Copia y pega en tu terminal
    </div>
  </div>
</div>

Usa por defecto `es_ES.UTF-8`, puedes cambiarlo: `bash <(curl -fsSL .../bootstrap.sh) -l en_US.UTF-8`

Automatiza la configuración inicial de un entorno personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

- Herramientas: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd
- El mejor prompt, Oh-My-Posh, para cualquier Shell.
- Establece la variable LANG (por defecto a `es_ES.UTF-8`)
- Copia mis ficheros ~/.luispa.omp.json y ~/.zshrc
- Herramientas de Git que tengo en el repositorio git-config-repos.
- Crea unos cuantos scripts en ~/bin que uso con frecuencia: e, s, confcat
- Instala automáticamente **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`.

Post instalación: verifica que te funciona bien la fuente Nerd

```bash
# Verificación completa de Nerd Fonts
nerd-verify.sh

# Verificar que las fuentes están instaladas
fc-list | grep "FiraCode Nerd Font"

# Verificar que lsd funciona con iconos
lsd --version
```

Si no funciona, ejecuta lo siguiente:

```bash
# Configuración automática (detecta tu terminal)
nerd-setup.sh auto | <nombre del terminal>
```

## Windows

Configuración automatizada para **Windows 11** (y Windows 10) usando **PowerShell** y **winget**.

Requisitos

- Windows 11 (recomendado) o Windows 10 con las últimas actualizaciones
- PowerShell 7.0 o superior (descargar desde [GitHub](https://github.com/PowerShell/PowerShell/releases) o Microsoft Store)
- App Installer (winget) instalado desde Microsoft Store
- Permisos para instalar aplicaciones con winget

> **Nota sobre PowerShell 7**: Lo prefiero para aprovechar las mejoras en sintaxis moderna, mejor manejo de errores y compatibilidad mejorada con las herramientas CLI actuales.

### ⚡ Ejecución en Windows

<div style="
  background: linear-gradient(135deg, #0078d4 0%, #106ebe 100%);
  border-radius: 12px;
  padding: 20px;
  margin: 20px 0;
  box-shadow: 0 8px 32px rgba(0, 120, 212, 0.3);
  border: 1px solid rgba(255, 255, 255, 0.2);
">
  <div style="
    background: #012456;
    border-radius: 8px;
    padding: 16px;
    font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
    position: relative;
    overflow: hidden;
  ">
    <div style="
      color: #5bc0f8;
      font-size: 14px;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
    ">
      <span style="margin-right: 8px;">🪟</span>
      <strong>Ejecutar en PowerShell:</strong>
    </div>
    <div style="
      background: #1e3a5f;
      border-radius: 6px;
      padding: 12px;
      border-left: 4px solid #5bc0f8;
    ">
      <code style="
        color: #ffffff;
        font-size: 14px;
        line-height: 1.4;
        display: block;
        word-break: break-all;
      ">iex (irm &quot;https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1&quot;)</code>
    </div>
    <div style="
      margin-top: 8px;
      font-size: 12px;
      color: #7fb3d3;
      text-align: right;
    ">
      ← Copia y pega en PowerShell
    </div>
  </div>
</div>

Automatiza la configuración inicial de un entorno personalizado para Windows. Está diseñado con un enfoque modular e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

- **Herramientas**: git, oh-my-posh, jq, lsd, zoxide, fd, fzf, ripgrep, bottom (equivalente a htop)
- **El mejor prompt**: Oh-My-Posh configurado con el tema personalizado
- **Copia mis ficheros**: `~/.luispa.omp.json` al perfil de usuario
- **Scripts útiles**: `nerd-setup.ps1`, `nerd-verify.ps1` en `~/bin`
- **Instala automáticamente**: **FiraCode Nerd Font** para soportar iconos en herramientas como `lsd`

Después de la instalación:

1. **Reiniciar el terminal** para aplicar los cambios de PATH
2. **Verifica que tienes el Nerd font** en tu terminal:

```powershell
# Verificación completa de Nerd Fonts
nerd-verify.ps1

# Instrucciones para configurarlo (detecta tu terminal)
nerd-setup.ps1 auto
```

## 🧰 Gestores de paquetes por sistema operativo

| Sistema Operativo     | Gestor de Paquetes | Rol Principal                                      | ¿Por qué lo uso?                                                                 |
|------------------------|--------------------|----------------------------------------------------|------------------------------------------------------------------------------------|
| 🐧 Linux (Debian/Ubuntu) | `apt`              | Gestor nativo del sistema                          | Estándar en Debian/Ubuntu, robusto, bien mantenido, con soporte oficial           |
| 🐧 WSL2 (Ubuntu)        | `apt`              | Paquetes de sistema y herramientas Unix            | Mismo entorno que Linux, total compatibilidad, sin reinventar la rueda            |
| 🍎 macOS               | `brew`             | CLI tools, apps de usuario, compilación cruzada    | Flexible, no requiere admin, ecosistema maduro para devs                          |
| 🪟 Windows 11          | `scoop`            | Utilidades CLI portables, estilo Unix              | Limpio, sin UAC, sin registro, scriptable, ideal para herramientas de desarrollo y cualquier "herramientas" del CLI.  |
| 🪟 Windows 11          | `winget`           | Aplicaciones GUI y binarios estándar               | Mantenido por Microsoft, buena integración con Store y apps Win32. Lo uso para aplicaciones complejas GUI.  |
