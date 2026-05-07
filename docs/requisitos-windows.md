# Requisitos — Windows

devcli soporta **Windows 10 y 11**, tanto x64 como ARM64.

## Lo que necesitas

- **PowerShell 7** o superior. La versión que viene con Windows (5.1) no vale.
  - Descarga: [GitHub releases](https://github.com/PowerShell/PowerShell/releases)
    o desde Microsoft Store buscando "PowerShell".
  - Compruébalo con `pwsh --version`.

- **`winget`** (gestor de paquetes de Windows). Viene preinstalado en Windows
  11 y en Windows 10 reciente.
  - Compruébalo con `winget list`.
  - Si te dice "Acceso denegado", lee [esta nota sobre AppX](#problema-comun-winget-da-acceso-denegado).

## Recomendado preinstalar

No es estrictamente obligatorio (devcli intenta instalarlos por ti), pero te
ahorra fricción si lo haces antes:

```powershell
# Scoop (gestor de paquetes que devcli usa para casi todo)
irm get.scoop.sh | iex

# Si el comando anterior falla por permisos, prueba en modo administrador:
iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
```

> **Terminal recomendada: WezTerm.** devcli la instala con los perfiles `dev`
> y `full` (vía scoop) y le añade una super-config con selector de shells,
> AI Mode y persistencia de tamaño. Si prefieres seguir con Windows Terminal,
> devcli funciona también — pero pierdes los atajos y la super-config. Ver
> [wezterm.md](wezterm.md).

## Si tu antivirus bloquea el bootstrap

Bitdefender, CrowdStrike, Sentinel, Symantec y similares a veces detectan el
patrón `iex (irm ...)` (descargar y ejecutar en una sola línea) como
sospechoso. Si te pasa, usa la **instalación en dos pasos** — descarga el
script primero y ejecútalo después:

```powershell
irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1" -OutFile "$env:TEMP\devcli-bootstrap.ps1"
& "$env:TEMP\devcli-bootstrap.ps1"
```

Funcionalmente es idéntico, pero el antivirus suele dejarlo pasar.

## Problema común: winget da "Acceso denegado"

En equipos provisionados recientemente (especialmente Windows 11 ARM o
imágenes virtuales), `winget` puede estar instalado pero **roto**: el alias de
ejecución de aplicaciones (AppExecutionAlias) no apunta correctamente al
ejecutable.

Síntoma: `winget --version` o `winget list` devuelve "Acceso denegado".

Cómo arreglarlo (cualquiera de estas funciona):

1. Abre **Microsoft Store** → busca *App Installer* → pulsa *Actualizar*.
2. **Settings → Apps → Advanced app settings → App execution aliases** → activa
   *App Installer (winget.exe)*.
3. **Settings → Apps → App Installer → Advanced options → Reset**.

devcli detecta este caso y, si winget no funciona, salta los pasos que
dependen de él. La instalación continúa con los que sí pueden hacerse vía
scoop.

> 💡 Si abres una sesión SSH a una máquina Windows, `winget` y otros AppX
> aliases NO se activan en sesiones no interactivas. Esto es por diseño de
> Windows, no es un bug de devcli. Si vas a usar el bootstrap por SSH,
> arranca primero una sesión interactiva y luego SSH.

## Si algo falla

- Para ver el detalle de qué falló, mira `~/.devcli/install.log`. Cada fase
  escribe ahí toda la salida bruta de `scoop`, `winget`, `Invoke-WebRequest`, etc.
- Si quieres ver todo en pantalla mientras se ejecuta, añade `-Verbose`:

  ```powershell
  iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Verbose"
  ```

Más en [troubleshooting.md](troubleshooting.md).
