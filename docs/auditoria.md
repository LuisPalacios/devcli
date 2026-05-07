# Auditar el bootstrap antes de ejecutarlo

Esta guía es para usuarios técnicos que prefieren leer el código antes de
darle permiso de instalar software en su máquina. Toda la decisión de **qué**
se instala vive en cuatro JSONs muy legibles. La decisión de **cómo** vive en
scripts cortos.

## Vista general

`bootstrap.{sh,ps1}` clona el repo a `~/.devcli` y ejecuta cinco fases en
orden. Cada fase es un script independiente con un código de salida (`0` ok,
`1` warning, `2` fail). El bootstrap suma los resultados y muestra el
resumen final.

| Fase | Script (Linux/macOS/WSL2) | Script (Windows) | Qué hace |
|------|---------------------------|------------------|----------|
| Bootstrap | [`bootstrap.sh`](../bootstrap.sh) | [`bootstrap.ps1`](../bootstrap.ps1) | Clona/actualiza el repo, lanza las fases, contabiliza el resultado. |
| 01 | [`install/01-system.sh`](../install/01-system.sh) | [`install/01-system.ps1`](../install/01-system.ps1) | Paquetes base (`git`, `curl`, `zsh`, `jq`, `oh-my-posh`, ...) y configuración de locale en Linux nativo. |
| 02 | [`install/02-packages.sh`](../install/02-packages.sh) | [`install/02-packages.ps1`](../install/02-packages.ps1) | Herramientas CLI según el perfil (`fzf`, `bat`, `lsd`, `ripgrep`, `fd`, ...). |
| 03 | [`install/03-dotfiles.sh`](../install/03-dotfiles.sh) | [`install/03-dotfiles.ps1`](../install/03-dotfiles.ps1) | Copia los dotfiles a `$HOME` (`.zshrc`, `.tmux.conf`, prompt, ...). |
| 04 | [`install/04-gitfiles.sh`](../install/04-gitfiles.sh) | [`install/04-gitfiles.ps1`](../install/04-gitfiles.ps1) | Descarga binarios desde GitHub Releases (gitbox, etc.). |
| 05 | [`install/05-localtools.sh`](../install/05-localtools.sh) | [`install/05-localtools.ps1`](../install/05-localtools.ps1) | Copia los scripts auxiliares a `~/bin` (`e`, `s`, `confcat`, `nerd-setup`, `nerd-verify`). |

## Las cuatro fuentes de verdad

| JSON | Para qué |
|------|----------|
| [`install/tools.json`](../install/tools.json) | Catálogo único de herramientas. Cada entrada declara `phase` (`"system"` para fase 01, ausente o `"tools"` para fase 02), `tags` (filtros del profile en fase 02), métodos por plataforma (`apt` / `brew` / `scoop` / `winget` / `curl-sh` / `github-deb` / `github-binary`), y opcionalmente `pre_install` / `post_install`. La sección `profiles` mapea `minimal` / `dev` / `full` a una lista de tags. |
| [`install/03-dotfiles.json`](../install/03-dotfiles.json) | Dotfiles a copiar: `file` (origen en `dotfiles/`), `dst` (ruta relativa a `$HOME`), `platforms`. |
| [`install/04-gitfiles.json`](../install/04-gitfiles.json) | Binarios de GitHub Releases: `repo`, `binary`, `assets` (mapa por arquitectura). |
| [`install/05-localtools.json`](../install/05-localtools.json) | Scripts auxiliares en `files/bin/` que se copian a `~/bin`. |

Si quieres añadir, quitar o customizar herramientas, **edita el JSON**. Los
scripts no necesitan tocarse.

## Helpers compartidos

| Path | Para qué |
|------|----------|
| [`install/env.sh`](../install/env.sh) / [`env.ps1`](../install/env.ps1) | Detección de OS, usuario, paths (`BIN_DIR`, `FILES_DIR`, ...), locale. |
| [`install/utils.sh`](../install/utils.sh) / [`utils.ps1`](../install/utils.ps1) | Logging, dispatcher de métodos (`install_tool` / `Install-Tool`), capa UX (banner, fases, summary), runner (`run_phase_items` / `Invoke-PhaseItems`). |

El [contrato de errores](../install/utils.sh) está documentado en cabecera de
ambos `utils.{sh,ps1}` — qué devuelve cada nivel (handler / runner / phase
script) y dónde aterriza la salida bruta de los gestores (`apt`, `scoop`...).

## Qué pasa con el repo local

`~/.devcli` es una clonación gestionada por bootstrap. Cada vez que ejecutas
el bootstrap:

1. Si `~/.devcli/.git` existe: `git fetch + git reset --hard origin/main`. Es
   rápido (~1s) y descarta cualquier edición local que hayas hecho.
2. Si no existe: clone fresco.

Si necesitas forzar una descarga limpia (por ejemplo tras un `git reset`
problemático), añade `--reclone` (Bash) o `-Reclone` (PowerShell). Borra y
re-clona.

> Si haces edits locales en `~/.devcli/` se sobreescriben en cada bootstrap.
> El sitio para customizar es **tu fork** del repo, no la clonación local.

## El log de instalación

Toda la salida bruta de los gestores (`apt-get install`, `scoop install`,
`winget install`, `curl ...`) va a `~/.devcli/install.log` con un header por
sesión. Útil para diagnosticar por qué falló una herramienta concreta.

Si quieres ver toda esa salida en pantalla en lugar de en el log, añade
`--verbose` (Bash) o `-Verbose` (PowerShell).
