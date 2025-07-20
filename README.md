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

```console
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

Usa por defecto `es_ES.UTF-8`, puedes cambiarlo: `bash <(curl -fsSL .../bootstrap.sh) -l en_US.UTF-8`

Automatiza la configuración inicial de un entorno personalizado para sistemas Linux, macOS y WSL2. Está diseñado con un enfoque modular, multiplataforma e idempotente. La instalación se realiza por fases, mediante los scripts ubicados en el directorio `install/`.

- Herramientas: git, curl, wget, nano, htop, tmux, fzf, bat, fd-find, ripgrep, tree, jq, lsd
- El mejor prompt, Oh-My-Posh, para cualquier Shell.
- Establece la variable LANG (por defecto a `s_ES.UTF-8`)
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

```powershell
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

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

## 🎨 **Opción 1: HTML/CSS (Más atractiva)**

```html
<code_block_to_apply_changes_from>
```

## 🎨 **Opción 2: Estilo Terminal Retro**

```html
<div style="
  background: #000;
  border: 2px solid #00ff00;
  border-radius: 8px;
  padding: 16px;
  margin: 16px 0;
  font-family: 'Courier New', monospace;
  box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
">
  <div style="color: #00ff00; margin-bottom: 8px;">
    <span style="animation: blink 1s infinite;">▊</span> <strong>~/terminal $</strong>
  </div>
  <div style="
    background: #111;
    padding: 12px;
    border-radius: 4px;
    border: 1px solid #333;
  ">
    <code style="color: #00ff00; font-size: 13px;">
      bash &lt;(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
    </code>
  </div>
</div>

<style>
@keyframes blink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0; }
}
</style>
```

## 🎨 **Opción 3: Markdown con cajas ASCII (Más simple)**

```markdown
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  🚀 **Instalación Rápida - Linux/macOS/WSL2**                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ```bash                                                                            │
│  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)  │
│  ```                                                                                │
│                                                                                     │
│  💡 **Opcional:** Cambiar idioma con `-l en_US.UTF-8`                               │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 🎨 **Opción 4: CSS + Botón Copiar (Más interactiva)**

```html
<div style="
  background: linear-gradient(145deg, #667eea, #764ba2);
  padding: 2px;
  border-radius: 12px;
  margin: 20px 0;
">
  <div style="
    background: #1a1a1a;
    border-radius: 10px;
    padding: 20px;
    position: relative;
  ">
    <div style="
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    ">
      <span style="color: #00ff88; font-weight: bold;">
        🚀 Ejecutar Bootstrap
      </span>
      <button onclick="navigator.clipboard.writeText('bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)')"
              style="
                background: #00ff88;
                border: none;
                border-radius: 6px;
                padding: 6px 12px;
                color: #000;
                font-weight: bold;
                cursor: pointer;
                font-size: 12px;
              ">
        📋 Copiar
      </button>
    </div>

    <div style="
      background: #2d2d2d;
      border-radius: 8px;
      padding: 16px;
      border-left: 4px solid #00ff88;
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
    ">
      <code style="
        color: #ffffff;
        font-size: 14px;
        line-height: 1.5;
        display: block;
        word-wrap: break-word;
      ">bash &lt;(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)</code>
    </div>

    <div style="
      margin-top: 8px;
      font-size: 12px;
      color: #888;
      text-align: center;
    ">
      Compatible con Linux, macOS y WSL2
    </div>
  </div>
</div>
```

## 🎨 **Opción 5: Estilo GitHub/GitLab (Profesional)**

```html
<div style="
  border: 1px solid #d1d9e0;
  border-radius: 6px;
  margin: 16px 0;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.12);
">
  <div style="
    background: #f6f8fa;
    padding: 8px 16px;
    border-bottom: 1px solid #d1d9e0;
    font-weight: 600;
    color: #24292e;
    font-size: 14px;
  ">
    🚀 Instalación Automática
  </div>
  <div style="
    background: #24292e;
    padding: 16px;
    position: relative;
  ">
    <pre style="
      margin: 0;
      color: #e1e4e8;
      font-family: 'SFMono-Regular', 'Consolas', 'Liberation Mono', monospace;
      font-size: 13px;
      line-height: 1.45;
      overflow-x: auto;
    "><code>bash &lt;(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)</code></pre>

    <div style="
      position: absolute;
      top: 8px;
      right: 8px;
      background: rgba(255,255,255,0.1);
      border-radius: 3px;
      padding: 4px 8px;
      font-size: 11px;
      color: #959da5;
    ">
      bash
    </div>
  </div>
</div>
```

## 💡 **Mi recomendación:**

Para el **README.md**, usa la **Opción 1** (HTML/CSS con gradiente) porque:

✅ **Muy atractiva visualmente**
✅ **Se ve bien en GitHub/GitLab**
✅ **Resalta el comando importante**
✅ **Incluye iconos y colores**
✅ **Responsive y profesional**

¿Cuál te gusta más? ¿O quieres que combine elementos de varias opciones? 🎨
