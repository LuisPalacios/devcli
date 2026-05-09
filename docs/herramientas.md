# Las herramientas que se instalan

`devcli` no es sólo una configuración bonita del prompt — instala una colección
curada de herramientas CLI modernas que reemplazan o complementan las clásicas
de Unix. Esta guía te dice **qué hace cada una** y **cuándo la vas a usar**.

## Prompt y aspecto visual

### [`oh-my-posh`](https://ohmyposh.dev/) — el prompt unificado

El prompt que ves cuando abres una terminal: rama de git, virtualenv activo,
exit code, duración del último comando, icono del SO… Lo bonito es que devcli
configura **el mismo tema** (`~/.oh-my-posh.json`) para zsh, PowerShell, CMD
(vía Clink) y Git Bash, así que la estética es coherente entre shells y entre
sistemas.

```bash
oh-my-posh --version            # comprueba que está instalado
oh-my-posh print primary --config ~/.oh-my-posh.json   # debug del render
```

Si quieres ver qué indicadores muestra y customizar segmentos (colores,
iconos, qué se enseña a la izquierda vs a la derecha) edita el
`oh-my-posh.json` del repo y haz un fork.

> Si los iconos del prompt salen como cuadraditos, te falta una **Nerd Font**.
> Mira [troubleshooting.md](troubleshooting.md#los-iconos-no-salen-bien-ezalsd-prompt).

## Terminal

### [`wezterm`](https://wezterm.org/) — terminal moderno multiplataforma *(recomendado)*

**Mi terminal preferida en los tres sistemas.** Escrita en Rust con GPU
acceleration, configuración en Lua, y soporte para layouts complejos. Una
sola config funciona idéntica en Windows, macOS y Linux. devcli la instala
con los perfiles `dev` y `full`, y le añade una **super-config** preparada:

- Selector de shells *(Windows)* — Git Bash, PowerShell 7, PowerShell 7
  (admin), WSL, CMD, PS5.
- AI Mode — un atajo abre 4 paneles de Claude (opus/sonnet/haiku + shell).
- Persistencia de tamaño y selector de temas (>900 disponibles).
- Scrollbar lateral arrastrable, shell integration via OSC-7/133, ligaduras
  de fuente, multiplexor integrado.

Detalles en [wezterm.md](wezterm.md) (incluida la sección AI Mode).

> Si no quieres WezTerm, devcli funciona igual en Windows Terminal, iTerm2,
> gnome-terminal, etc. — pero perderás la super-config y los atajos.

## Navegación y archivos

### [`eza`](https://github.com/eza-community/eza) — `ls` con iconos, colores y `--git`

Reemplazo directo de `ls`. Añade iconos (de las Nerd Fonts), colorea por
tipo de archivo, formatea las fechas/tamaños de forma humana y, en modo
long, muestra el estado git de cada archivo (staged/modified/new/etc.).

```bash
ls          # alias → eza con icons + colors + --git + group-dirs-first
eza         # invocación directa
ls -la      # detallado, con columna git al final
eza --tree  # como `tree`, pero con iconos
```

devcli configura `ll`/`la`/`lla` (long, all, long+all) — el alias `ls`
prefiere `eza` y degrada a `lsd` si eza no estuviera disponible.

Los colores replican tu config previa de lsd (vía `EZA_COLORS` env var)
para que la transición sea visualmente continua.

### [`lsd`](https://github.com/lsd-rs/lsd) — fallback legacy (durante una temporada)

Sigue instalado por si algo en `eza` te diera problemas. Puedes invocarlo
directamente como `lsd --tree` o `lsd -la`. El alias `ls` solo cae a lsd
si eza no está en el sistema.

### [`tree`](https://gitlab.com/OldManProgrammer/unix-tree) — árbol de directorios

Lo de siempre, sin sorpresas. Útil para auditar la estructura de un proyecto.

```bash
tree -L 2          # dos niveles
tree -I node_modules  # ignora node_modules
```

### [`fd`](https://github.com/sharkdp/fd) — `find` que no te vuelve loco

Sintaxis natural en lugar de los `-name "*.foo" -type f -exec` infernales.
Por defecto ignora `.git/`, `node_modules/`, etc.

```bash
fd README              # busca cualquier archivo con "README" en el nombre
fd -e py               # todos los .py
fd -t d cache          # directorios llamados "cache"
fd README -x cat       # ejecuta `cat` por cada match
```

> En Debian/Ubuntu el binario se llama `fdfind`; devcli configura el alias
> `fd` para que no tengas que recordarlo.

### [`zoxide`](https://github.com/ajeetdsouza/zoxide) — `cd` con memoria

Aprende qué directorios visitas y te deja saltar a ellos por una palabra
clave. Después de unos días lo usas más que `cd`.

```bash
cd ~/proyectos/cliente-X/backend     # primera vez, normal
# ...horas después...
z backend                            # te lleva ahí
z cli back                           # también vale, busca por substring
zi                                   # picker interactivo (fzf)
```

devcli inicializa zoxide automáticamente en `.zshrc` y en el perfil de
PowerShell.

## Búsqueda en archivos

### [`ripgrep`](https://github.com/BurntSushi/ripgrep) — `grep` ultrarrápido

Busca dentro de archivos a velocidad de SSD. Respeta `.gitignore` por defecto,
sintaxis sensata, salida coloreada.

```bash
rg TODO                       # busca "TODO" en todo el árbol actual
rg -i "user not found"        # case-insensitive
rg -t py "import requests"    # sólo en archivos Python
rg -A 3 ERROR                 # muestra 3 líneas después de cada match
```

Después de probarlo, no vuelves a `grep -r`.

### [`fzf`](https://github.com/junegunn/fzf) — buscador difuso universal

Filtro interactivo que encaja en cualquier sitio donde haya una lista. La
matanza definitiva al "¿cómo se llamaba ese fichero?"

```bash
fzf                          # lista los archivos del cwd, escribe para filtrar
vim $(fzf)                   # abre el resultado en vim
git checkout $(git branch | fzf)   # picker de ramas
history | fzf                # busca en el historial
```

devcli activa el atajo `Ctrl+R` en zsh y bash para buscar el historial con fzf.

### [`bat`](https://github.com/sharkdp/bat) — `cat` con resaltado

Como `cat`, pero con syntax highlighting, números de línea y paginación
automática. Detecta el lenguaje por la extensión.

```bash
bat README.md
bat -l json config.json     # forzar lenguaje
bat --diff archivo.py       # diff style
```

> En Debian/Ubuntu el binario se llama `batcat`; devcli pone el alias `bat`.

## Sistema y monitoreo

### [`htop`](https://htop.dev/) — monitor de procesos interactivo

Como `top`, pero con colores, scroll, búsqueda, y árbol de procesos. Pulsa
`F2` para configurarlo, `F6` para ordenar.

> En Windows se instala [`bottom`](https://github.com/ClementTsang/bottom) en
> su lugar; devcli pone el alias `htop` apuntando a `btm`. Visualmente
> distinto pero la misma idea.

### [`gping`](https://github.com/orf/gping) — `ping` con gráfico ASCII

Mismo `ping` de toda la vida, pero dibuja un gráfico de tiempos de respuesta
en tiempo real. Útil para diagnosticar caídas intermitentes.

```bash
gping google.com
gping 1.1.1.1 8.8.8.8        # varios destinos a la vez
```

### [`tmux`](https://github.com/tmux/tmux) — multiplexor de terminal

Te deja partir tu terminal en panels y, lo más importante, **mantener
sesiones vivas aunque cierres SSH**. Imprescindible para trabajo en
servidores.

```bash
tmux                       # nueva sesión
tmux ls                    # listar sesiones
tmux a -t <nombre>         # adjuntar
# Dentro: Ctrl-b + " (split horizontal), % (vertical), arrow (mover), d (detach)
```

devcli incluye un `.tmux.conf` con bindings sensatos y tema oscuro. También
hay `.tmux-ai.conf`, una configuración alternativa pensada para sesiones de
4 paneles con Claude (más en [wezterm.md#ai-mode](wezterm.md#ai-mode)).

> En Windows no se instala `tmux` (ni hace falta — usa WezTerm para splits y
> pestañas, o WSL si necesitas tmux real).

## Desarrollo

### [`pnpm`](https://pnpm.io/) — gestor de paquetes Node.js

Mucho más rápido que `npm` y muchísimo más eficiente con disco (deduplica
agresivamente). Drop-in replacement.

```bash
pnpm install
pnpm add lodash
pnpm dev
```

### [`uv`](https://docs.astral.sh/uv/) — gestor de paquetes Python (Astral)

Lo que `pip` debería haber sido: rapidísimo, gestiona venvs por ti, instala
versiones de Python por ti. Está reemplazando todo el stack de Python tooling.

```bash
uv venv                    # crea .venv
uv pip install requests    # como pip pero 10× más rápido
uv run script.py           # ejecuta dentro del venv automáticamente
uv tool install ruff       # instala una herramienta CLI globalmente
```

### [`mkcert`](https://github.com/FiloSottile/mkcert) (+ [`nss`](https://firefox-source-docs.mozilla.org/security/nss/)) — certificados SSL locales

Genera certificados SSL válidos para `localhost`, `*.local`, IPs de tu LAN,
etc. y los hace confiar a tu navegador. Indispensable para desarrollo HTTPS
local.

```bash
mkcert -install            # primera vez: añade tu CA local al sistema
mkcert localhost 127.0.0.1 ::1
# genera localhost+2.pem y localhost+2-key.pem
```

> En Linux/macOS/WSL2 devcli también instala `nss` (`libnss3-tools`), que
> mkcert necesita para registrar la CA local en el almacén de Firefox y
> Chromium. En Windows no hace falta.

### [`kubectl`](https://kubernetes.io/docs/reference/kubectl/) — cliente de Kubernetes

Sólo si trabajas con clusters. devcli lo instala con el perfil `full`.

```bash
kubectl get pods
kubectl logs -f <pod>
kubectl exec -it <pod> -- bash
```

## Sólo Windows

### [`clink`](https://chrisant996.github.io/clink/) — autocompletado y aliases para CMD

Si usas `cmd.exe` (no PowerShell, no Git Bash), `clink` lo convierte en algo
usable: autocompletado de comandos y rutas, aliases, historial persistente,
edición tipo readline.

devcli configura `clink` con un set de aliases útiles (`ll`, `gst`, etc.) y lo
engancha como autorun de CMD.

### [`quicklook`](https://github.com/QL-Win/QuickLook) — preview rápido de archivos

Pulsa `Espacio` sobre un archivo en el explorador y te lo previsualiza sin
abrirlo. Como en macOS. Soporta imágenes, PDFs, vídeos, código, JSON, etc.

## Base — siempre instaladas

Estas no aparecen en los perfiles porque son la infraestructura mínima que
devcli necesita para funcionar. Se instalan o se aseguran en la primera fase
del bootstrap, ignorando el perfil que elijas.

| Herramienta | Para qué |
| ----------- | -------- |
| [`git`](https://git-scm.com/) | Clonar el propio repo de devcli y, en general, lo que ya sabes. |
| [`curl`](https://curl.se/) / [`wget`](https://www.gnu.org/software/wget/) | Descargas en los métodos `curl-sh`, `github-deb`, `github-binary`. |
| [`nano`](https://www.nano-editor.org/) | Editor por defecto cuando algo necesita un editor (Linux/macOS/WSL2). |
| [`zsh`](https://www.zsh.org/) | Shell por defecto en Linux/WSL2 tras el bootstrap. macOS ya lo trae. |
| [`jq`](https://jqlang.org/) | Parseo de los JSONs de `install/` desde Bash y PowerShell. |
| [**FiraCode Nerd Font**](https://www.nerdfonts.com/) | La fuente con iconos que `eza`, `lsd` y el prompt asumen. Se instala vía un trigger del post-install de `eza`/`lsd`; si los iconos no salen, usa `~/bin/nerd-setup.{sh,ps1}` para forzar la instalación. |

> El catálogo completo y exacto de qué se instala con qué método en cada
> plataforma vive en [`install/tools.json`](../install/tools.json). Si quieres
> añadir, quitar o customizar herramientas, ése es el sitio.
