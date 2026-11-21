# Auditar el bootstrap antes de ejecutarlo

Esta guía es para usuarios técnicos que prefieren leer el código antes de
darle permiso de instalar software en su máquina. Toda la decisión de **qué**
se instala vive en cuatro JSONs muy legibles. La decisión de **cómo** vive en
scripts cortos.

## Vista general

`bootstrap.{sh,ps1}` clona el repo a `~/.devcli` y ejecuta cuatro fases en
orden (cinco en Windows). Cada fase es un script independiente con un código de salida (`0` ok,
`1` warning, `2` fail). El bootstrap suma los resultados y muestra el
resumen final.

| Fase | Script (Linux/macOS/WSL2) | Script (Windows) | Qué hace |
|------|---------------------------|------------------|----------|
| Bootstrap | [`bootstrap.sh`](../bootstrap.sh) | [`bootstrap.ps1`](../bootstrap.ps1) | Clona/actualiza el repo, lanza las fases, contabiliza el resultado. En Git Bash, `bootstrap.sh` delega en `bootstrap.ps1` traduciendo sus opciones y lo descarga del commit exacto de `main` (resuelto con `git ls-remote`), porque la CDN de `raw.githubusercontent.com` puede servir la versión anterior hasta 5 minutos después de un push. En Windows PowerShell 5.1, antes de nada, instala PowerShell 7 con `winget` si falta y se relanza en `pwsh`; bajo `iex` vuelve a descargarse de `raw.githubusercontent.com` a un temporal que borra al terminar. |
| 01 | [`install/01-system.sh`](../install/01-system.sh) | [`install/01-system.ps1`](../install/01-system.ps1) | Paquetes base (`git`, `curl`, `zsh`, `jq`, `oh-my-posh`, ...) y configuración de locale en Linux nativo. |
| 02 | [`install/02-packages.sh`](../install/02-packages.sh) | [`install/02-packages.ps1`](../install/02-packages.ps1) | Herramientas CLI según el perfil (`fzf`, `bat`, `lsd`, `ripgrep`, `fd`, ...). |
| 03 | [`install/03-dotfiles.sh`](../install/03-dotfiles.sh) | [`install/03-dotfiles.ps1`](../install/03-dotfiles.ps1) | Copia los dotfiles a `$HOME` (`.zshrc`, `.tmux.conf`, prompt, ...) y fija `attribution` vacío en `~/.claude/settings.json` (Claude Code sin coautor en commits). |
| 04 | [`install/04-localtools.sh`](../install/04-localtools.sh) | [`install/04-localtools.ps1`](../install/04-localtools.ps1) | Copia los scripts auxiliares a `~/bin` (`e`, `s`, `confcat`, `nerd-setup`, `nerd-verify`). |
| 05 | — | [`install/05-customkeys.ps1`](../install/05-customkeys.ps1) | Sólo con `-CustomKeys on`: instala PowerToys si falta, despliega `custom_keys.lua` y el mapa de Keyboard Manager sin pisar tus ediciones (copia de seguridad en `~/.config/devcli/backups/`), y recarga PowerToys. Sin la opción, no toca nada. Ver [teclado-mac.md](teclado-mac.md). |

### Con el perfil `server`

Mismas fases, con otro alcance (ver [perfiles.md](perfiles.md#el-perfil-server-en-detalle)):
prerrequisitos y fases 01-02 sólo con `apt-get --no-install-recommends` de la
lista etiquetada `server` en `tools.json`, comprobando antes que cada paquete
esté en el repositorio oficial (si no, se omite con aviso), más los tres
binarios verificados (`oh-my-posh`, `uv`, `pnpm`); sin locale (01), sin
`chsh` (03), sin `/etc/nanorc` ni aviso de fuentes (04); y en 03/04 no se
despliega lo marcado con `"skip_profiles": ["server"]` en sus JSON. Además
`install_tool` (`utils.sh`) rechaza en este perfil cualquier método que no
sea `apt` y cualquier `pre_install`/`post_install`, diga lo que diga el JSON,
salvo las excepciones escritas con nombre (`DEVCLI_SERVER_VERIFIED_TOOLS` y
`DEVCLI_SERVER_HOOKS`).

## Simulación

`bootstrap.sh -n` (Linux, macOS, WSL2) recorre las mismas fases sin escribir
nada: cada punto que instalaría, descargaría o copiaría llama a `dry_note`
(`utils.sh`) en lugar de actuar, y al final se imprime la lista agrupada
(paquetes por origen, repositorios y claves, descargas, cambios fuera de
`$HOME`, ficheros en `$HOME`). No toca `~/.devcli`: usa la copia desde la que
lo lances o un clon temporal. Es la forma recomendada de auditar un perfil en
la propia máquina antes de ejecutarlo.

## Las tres fuentes de verdad

| JSON | Para qué |
|------|----------|
| [`install/tools.json`](../install/tools.json) | Catálogo único de herramientas. Cada entrada declara `phase` (`"system"` para fase 01, ausente o `"tools"` para fase 02), `tags` (filtros del profile en fase 02), métodos por plataforma (`apt` / `brew` / `scoop` / `winget` / `curl-sh` / `github-deb` / `github-binary` / `verified-binary`, este último con versión fija y sha256 por arquitectura), opcionalmente `pre_install` / `post_install` y, en bloques `apt` de Linux, un `fallback` que sólo se usa si el paquete no está en el repositorio oficial. La sección `profiles` mapea `minimal` / `dev` / `full` a una lista de tags. |
| [`install/03-dotfiles.json`](../install/03-dotfiles.json) | Dotfiles a copiar: `file` (origen en `dotfiles/`), `dst` (ruta relativa a `$HOME`), `platforms`. |
| [`install/04-localtools.json`](../install/04-localtools.json) | Scripts auxiliares en `files/bin/` que se copian a `~/bin`. |

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
