# devcli

![devcli](assets/old-hacker.jpg)

He pasado años instalando sistemas operativos, y al terminar, otras dos horas extra para dejar el entorno CLI como me gusta. Hice este proyecto para tener todo listo en un minuto, con una experiencia casi idéntica en **PowerShell, Git Bash, CMD** de Windows y por supuesto en **Linux, macOS y WSL2**.

Mi terminal multiplataforma preferida — y la que recomiendo — es **[WezTerm](https://wezterm.org)**. devcli la instala con los perfiles `dev` y `full` y añade una super-config (selector de shells, AI Mode, persistencia de tamaño, selector de temas). La super noticia es que funciona de forma idéntica en Windows, macOS y Linux. Ver [docs/wezterm.md](docs/wezterm.md).

> [!WARNING]
> **Aviso Importante: Lee antes de ejecutar**

Este proyecto realiza cambios significativos en tu sistema, entre los que se incluyen:

* Instalación de software de terceros.
* Modificación de archivos de configuración en tu directorio `$HOME`.
* Cambio de tu *shell* por defecto.

**Úsalo bajo tu propia responsabilidad.** Aunque utilizo esta configuración a diario en mis máquinas, cada entorno es distinto. Como se especifica en la licencia MIT, este software se proporciona "tal cual", sin garantías. **Si no estás de acuerdo con estos cambios o no comprendes el código, por favor, no lo utilices.**

**Recomendaciones antes de empezar:**

1. **Haz una copia de seguridad:** Respalda tus archivos de configuración actuales de tu directorio `$HOME` antes de ejecutar cualquier script.
2. **Audita el código:** Revisa el código fuente y el script de arranque. Lee detenidamente [`docs/auditoria.md`](docs/auditoria.md).
3. **Adáptalo:** Si alguna configuración no te convence, haz un *fork* y personalízalo a tu gusto, eliminando lo que no necesites.

## Instalación

**Linux, macOS, WSL2 y Git Bash en Windows**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)
```

**Windows 10/11** *(PowerShell 7)*:

```powershell
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")
```

> Windows: Si tu antivirus bloquea el comando, prueba la
> [instalación en dos pasos](docs/requisitos-windows.md#si-tu-antivirus-bloquea-el-bootstrap). </br>
> Mira opciones adicionales con `--help` y detalle de cada perfil en [docs/perfiles.md](docs/perfiles.md). </br>
> Las herramientas que se instalan están en [docs/herramientas.md](docs/herramientas.md).

## Después de instalar

- **Reinicia el terminal** para aplicar los cambios de PATH.
- Si los iconos no salen bien (prueba con `ls`, que ahora va por `eza`), ejecuta `~/bin/nerd-setup.sh`
  (Linux/macOS/WSL2) o `~/bin/nerd-setup.ps1` (Windows). Más en
  [docs/troubleshooting.md](docs/troubleshooting.md).
- **Abre WezTerm** (instalado con perfiles `dev`/`full`) — es la terminal
  recomendada del proyecto. Atajos, selector de temas, AI Mode y demás en
  [docs/wezterm.md](docs/wezterm.md).

## Documentación

| Guía | De qué va |
|------|-----------|
| [Perfiles](docs/perfiles.md) | Qué hay en cada perfil y cuándo elegir cada uno. |
| [Herramientas](docs/herramientas.md) | Las herramientas CLI que se instalan, con ejemplos de uso. |
| [WezTerm](docs/wezterm.md) | **Terminal recomendada de devcli.** Atajos, selector de shells, selector de temas, persistencia de tamaño. |
| [Wezterm modo IA](docs/wezterm-ai-mode.md) | AI Mode: cuatro paneles de Claude (opus + sonnet + haiku + shell) en una ventana, en un atajo. |
| [Requisitos Windows](docs/requisitos-windows.md) | PowerShell 7, winget, scoop. Soluciones a "Acceso denegado" de winget y bloqueos del antivirus. |
| [Requisitos Unix](docs/requisitos-unix.md) | Linux Debian/Ubuntu, macOS con Homebrew, WSL2. `sudo` sin contraseña. |
| [Troubleshooting](docs/troubleshooting.md) | Iconos rotos, fallos de instalación de una herramienta concreta, antivirus, modo verbose, log file. |
| [Auditoria](docs/auditoria.md) | Para auditar el bootstrap antes de ejecutarlo: fases, JSONs, contrato de errores. |
| [Desinstalar](docs/desinstalar.md) | Cómo dar marcha atrás: qué tocó devcli y cómo revertirlo. |

## Licencia

[MIT](MIT)
