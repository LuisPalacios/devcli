# Perfiles de instalación

devcli no te impone una lista cerrada de herramientas. Eliges un **perfil** y se
instala sólo el subconjunto que necesitas. Útil si la máquina es pequeña, si
estás en un servidor sin entorno gráfico, o si simplemente no quieres ruido.

> [!IMPORTANT]
> **En servidores, usa siempre el perfil `server`.** El resto de perfiles están
> pensados para equipos personales (portátiles, estaciones de trabajo, VM de
> desarrollo): pueden añadir repositorios apt de terceros con sus claves,
> descargan cosas fuera del gestor de paquetes (fuentes, `mkcert`) y tocan
> configuración del sistema (locale, `/etc/nanorc`, shell de inicio). Cada
> repositorio de terceros es alguien más que puede instalar o sustituir
> paquetes como root en cada actualización, y queda fuera de las
> actualizaciones automáticas de seguridad limitadas a los orígenes de la
> distribución.

## Qué hay en cada perfil

| Perfil | Qué te llevas | Cuándo elegirlo |
|--------|---------------|-----------------|
| `server` | El mismo entorno de shell que en tu equipo, con software de **origen controlado**: del repositorio oficial de la distribución, `git`, `curl`, `jq`, `ca-certificates`, `vim`, `zsh`, `tmux`, `htop`, `ripgrep`, `lsd`, `eza`, `zoxide`, `fzf`, `bat`, `fd-find`, `tree` y `gping` (con `--diag`, además `tcpdump`, `iperf3` y `socat`); y tres **binarios verificados** (versión fija y suma sha256 comprobada): `oh-my-posh`, `uv` y `pnpm`. Dotfiles: `~/.zshrc`, `~/.tmux.conf` y el tema del prompt. | **Servidores.** Cualquier máquina que no sea tuya y personal. Sólo Linux (Debian y derivados) y WSL2. |
| `minimal` | Lo esencial para vivir en la CLI: `htop`, `tmux`, `fzf`, `bat`, `fd`, `ripgrep`, `eza` (+ `lsd` como fallback), `tree`, `zoxide`, `gping` | Equipos personales pequeños o si quieres probar antes de comprometerte. **No** es para servidores: en Linux cambia el locale, `/etc/nanorc` y la shell de inicio, descarga una Nerd Font y, si la distribución no trae `eza`, `gping` o `lsd`, los saca de un repositorio de terceros o de GitHub. |
| `dev` | Todo lo de `minimal` + **WezTerm** *(la terminal multiplataforma recomendada)* + herramientas de desarrollo: `mkcert`, `nss`, `pnpm`, `uv` | Tu portátil de trabajo. Es el sweet spot para la mayoría de la gente. |
| `full` | Todo lo de `dev` + extras: `kubectl`, y en Windows `clink` y `quicklook` | Tu máquina principal donde vives. |

> En los perfiles `minimal`, `dev` y `full` las herramientas "base" (git, curl,
> wget, nano, zsh, jq, oh-my-posh) **siempre** se instalan. El perfil `server`
> es la excepción: de las base instala git, curl, jq, zsh y oh-my-posh.
>
> **En Linux, el repositorio oficial va primero en todos los perfiles.** `eza`,
> `gping` y `lsd` se instalan del repositorio oficial de la distribución
> cuando está ahí (Debian 13 los trae todos); sólo si no está, los perfiles
> personales recurren al repositorio de terceros (gierens para `eza`, azlux
> para `gping`) o al `.deb` de GitHub (`lsd`). `oh-my-posh`, `uv` y `pnpm` se
> instalan en todos los perfiles como binarios verificados (ver más abajo).
>
> **WezTerm en Linux**: aunque elijas `dev` o `full`, en Linux sólo se instala
> si devcli detecta un entorno de escritorio. En servidores headless se omite
> automáticamente (es una app gráfica). Más detalles en
> [wezterm.md](wezterm.md).

## El perfil `server` en detalle

El criterio es **de dónde viene el software y cómo se verifica**, no cuánto
software es. Un servidor merece el mismo entorno de trabajo que tu equipo
(`ls` con iconos, `cd` inteligente, búsqueda difusa, el prompt, y `uv` y
`pnpm`, que usan también los asistentes de IA), siempre que nada llegue por
un canal sin control:

| Origen | En `server` |
|--------|-------------|
| Repositorio oficial de la distribución | **Sí**, cualquier paquete. |
| Binario descargado con versión fija y sha256 comprobada | **Sí**, sólo los tres con nombre: `oh-my-posh`, `uv`, `pnpm`. |
| Repositorios apt de terceros y sus claves | **No.** |
| `curl \| sh`, descargas sin versión fija o sin comprobar, `.deb` de releases con `dpkg -i` | **No.** |
| Instaladores que editan `~/.bashrc` o `~/.profile` | **No.** |

Lo que **hace**:

- Instala con `apt-get --no-install-recommends` (sin paquetes recomendados y
  sin preguntas de debconf) la lista de arriba, y sólo los que falten. Antes
  comprueba en `apt-cache policy` que cada paquete esté en el **repositorio
  oficial** de esa versión de la distribución (origen `Debian`, `Ubuntu` o
  `Raspbian`, el mismo criterio que unattended-upgrades) e instala esa
  versión exacta, aunque haya un repositorio de terceros con otra mayor. Si
  no está, lo **omite con un aviso** y sigue: nunca añade un repositorio para
  conseguirlo. Debian 13 los trae todos; en Debian 12 faltan `eza` y `gping`
  (el `ls` usa `lsd`) y en Ubuntu 22.04 además `lsd`.
- Crea los enlaces `~/bin/bat` → `batcat` y `~/bin/fd` → `fdfind` (los
  nombres que usa Debian).
- Instala `oh-my-posh`, `uv` y `pnpm` como binarios verificados (ver
  [abajo](#binarios-verificados-oh-my-posh-uv-y-pnpm)) y apaga el aviso de
  versión nueva de oh-my-posh (`oh-my-posh disable notice` y `disable
  upgrade`, que se guardan en su caché local, `~/.cache/oh-my-posh`).
- Copia `~/.zshrc`, `~/.tmux.conf` y el tema del prompt `~/.oh-my-posh.json`
  (con copia de seguridad del `.zshrc`), y los scripts `~/bin/confcat` y
  `~/bin/s`.
- Crea `~/.config/devcli/sin-descarga-tema`: con él, el `.zshrc` no descarga
  el tema de GitHub al abrir sesión (en los equipos personales sí lo
  actualiza una vez al día). Al abrir sesión no hay tráfico de red.
- Como en todos los perfiles, fija la clave `attribution` en
  `~/.claude/settings.json` (ver [desinstalar.md](desinstalar.md#claude-code-sin-coautor-en-los-commits)).

Lo que **no hace**, nunca:

- No añade repositorios apt ni claves de firma.
- No ejecuta `curl | sh` ni instaladores de proyectos, no instala `.deb` de
  releases ni nada de cargo/go/npm/pipx, snap, flatpak o brew. No toca
  `~/.bashrc` ni `~/.profile`.
- No instala herramientas de Kubernetes ni de contenedores (`kubectl`), ni
  `mkcert`, ni WezTerm, ni entornos gráficos ni fuentes.
- No toca la configuración del sistema: ni el locale, ni `/etc/nanorc`, ni
  sshd, sudoers, cortafuegos, sysctl, servicios, usuarios ni `/etc` en
  general. **Tampoco cambia tu shell de inicio** (`chsh` escribe en
  `/etc/passwd`): al terminar te dice cómo hacerlo tú si quieres zsh:

  ```bash
  chsh -s /usr/bin/zsh
  ```

  Si el locale del `.zshrc` (`es_ES.UTF-8`) no está generado en la máquina,
  el `.zshrc` usa `C.UTF-8`, para que el prompt y los iconos se vean bien
  sin tocar `/etc`.

Además, aunque alguien etiquete por error en `install/tools.json` una
herramienta que se instale de otra forma, el bootstrap **se niega** a
instalarla en este perfil: sólo acepta el método `apt`, sin hooks. Las
excepciones están escritas con nombre en `install/utils.sh`
(`DEVCLI_SERVER_VERIFIED_TOOLS` para los tres binarios y
`DEVCLI_SERVER_HOOKS` para los dos enlaces); una herramienta nueva que use
el método de binarios verificados no entra en `server` sola.

Los dotfiles funcionan sin las herramientas que falten (por ejemplo, si la
distribución no trae alguna): sin `eza`/`lsd`, `ls` es el de siempre; sin
`zoxide`, `cd` es el estándar; sin `oh-my-posh`, el prompt es uno sencillo
(`usuario@servidor-ejemplo:~%`). Sin avisos al abrir sesión.

Lo que instalan los propios paquetes oficiales es cosa suya, no de devcli: por
ejemplo, `zsh` se añade a `/etc/shells`, y con `--diag` `iperf3` trae una unidad
de systemd que Debian deja desactivada y `tcpdump` un perfil de AppArmor.

> El bootstrap sigue necesitando `sudo` sin contraseña para el usuario que lo
> ejecuta (ver [requisitos-unix.md](requisitos-unix.md)), también en este perfil.

## Binarios verificados: oh-my-posh, uv y pnpm

Ninguno de los tres está en el repositorio oficial de Debian (12 y 13) ni de
Ubuntu (22.04 y 24.04), así que en Linux y WSL2 se instalan, **en todos los
perfiles**, con el método `verified-binary` de `install/utils.sh`:

1. Versión fija y sumas sha256 por arquitectura (amd64 y arm64), guardadas
   en `install/tools.json`.
2. Descarga del artefacto de esa versión desde las releases oficiales del
   proyecto en GitHub, con `curl -f` y sólo `https`, a un directorio
   temporal.
3. Comprobación de la suma **antes** de instalar. Si no coincide: se borra
   lo descargado, no se instala nada, el bootstrap lo dice en una línea
   amarilla y sigue con lo demás.
4. Instalación sin privilegios, en las rutas de siempre: `~/bin/oh-my-posh`;
   `~/.local/bin/uv` y `~/.local/bin/uvx`; pnpm en
   `~/.local/share/pnpm/devcli-pnpm/` con el enlace
   `~/.local/share/pnpm/bin/pnpm`. **No se ejecuta el instalador del
   proyecto**, así que nada se añade a `~/.bashrc` ni a `~/.profile`: el
   `PATH` lo pone el `.zshrc`.

Si la versión instalada ya es la fijada, no se descarga nada. Si es otra (por
ejemplo, una instalación anterior con el instalador del proyecto), se
sustituye por la fijada.

**Sin actualizaciones por su cuenta.** Subir de versión es un cambio en el
repo, no algo que pase solo en cada máquina:

| Herramienta | Aviso o actualización automática | Qué hace devcli |
|-------------|----------------------------------|-----------------|
| oh-my-posh | El tema activa el aviso de versión nueva (consulta su CDN una vez por semana al abrir sesión) y existe `oh-my-posh upgrade`. | `oh-my-posh disable notice` y `oh-my-posh disable upgrade` en cada bootstrap (caché local, manda sobre el tema). El tema compartido con macOS y Windows no se toca. |
| uv | No avisa ni se actualiza solo. `uv self update` sólo funciona si lo instaló su instalador. | Nada que apagar: sin el recibo del instalador, `uv self update` se niega. |
| pnpm | `pnpm install` y `pnpm add` consultan el registro npm una vez al día y avisan de versión nueva. `pnpm self-update` existe, pero sólo a mano. | El `.zshrc` exporta `pnpm_config_update_notifier=false` en Linux. |

**Cómo subir de versión** (en `install/tools.json`, entradas `linux` y `wsl2`
de cada herramienta: `version` y las dos `sha256`):

| Herramienta | Artefactos | De dónde sale la suma |
|-------------|------------|-----------------------|
| oh-my-posh | `posh-linux-amd64`, `posh-linux-arm64` (binario suelto) | `checksums.txt` de la release (el proyecto lo publica firmado, `checksums.txt.sig`). |
| uv | `uv-x86_64-unknown-linux-gnu.tar.gz`, `uv-aarch64-unknown-linux-gnu.tar.gz` | `sha256.sum` (o el `.sha256` de cada artefacto) de la release. |
| pnpm | `pnpm-linux-x64.tar.gz`, `pnpm-linux-arm64.tar.gz` | pnpm **no publica sumas** en sus releases de GitHub: se calcula una vez con `sha256sum` sobre el artefacto de la versión fijada y se contrasta con el `digest` que GitHub muestra para ese asset (`gh release view v<versión> -R pnpm/pnpm --json assets`). |

Después, `bootstrap.sh -p server -n` muestra la versión y el principio de
cada suma, y en una máquina de prueba el bootstrap debe decir que la suma es
correcta (queda en `~/.devcli/install.log`).

## Cómo elegir un perfil

**Linux, macOS, WSL2, Git Bash:**

```bash
# Servidor: primero simula, luego instala
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p server -n
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p server
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p server --diag

# Equipos personales
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p minimal
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p dev
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p full
```

También vale la variable de entorno `DEVCLI_PROFILE=server` (y `DEVCLI_DIAG=1`
para el grupo de diagnóstico), útil en cloud-init o en scripts.

**Windows (PowerShell 7):**

```powershell
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile minimal"
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile dev"
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")                  # full
```

El perfil `server` no existe en Windows ni en macOS.

## Si no indicas perfil

devcli no aplica el perfil completo a ciegas:

| Dónde | Perfil sin `-p` |
|-------|-----------------|
| macOS, WSL2, Windows | `full`, como siempre. |
| Linux nativo **con sesión gráfica local** (`DISPLAY`, `WAYLAND_DISPLAY` o `XDG_SESSION_TYPE` x11/wayland, y **no** por SSH) | `full` |
| Linux nativo sin sesión gráfica local, **con terminal** | Pregunta. Enter = `server`. |
| Linux nativo sin sesión gráfica local **ni terminal** (cloud-init, tuberías, cron) | `server` |

El banner indica siempre el perfil aplicado y por qué.

Límites de la detección, para que sepas cuándo te va a preguntar o a
equivocarse:

- Una estación de trabajo a la que entras **por SSH** no cuenta como sesión
  gráfica local (aunque reenvíes X11): te preguntará.
- Una **VM de desarrollo sin escritorio** se trata como servidor: pasa
  `-p full` (o el perfil que quieras).
- Si lanzas el bootstrap desde un terminal **dentro de una sesión gráfica de
  un servidor**, se tomará por equipo personal. Por eso en servidores hay que
  pasar siempre `-p server`.
- No se usan como pista los paquetes gráficos instalados (hay servidores que
  los tienen), la virtualización (servidores y VM de desarrollo son igual de
  virtuales) ni el nombre de la máquina.

## Simular antes de instalar

`-n` (o `--dry-run`, o `DEVCLI_DRY_RUN=1`) ejecuta el bootstrap entero **sin
cambiar nada** y, al final, lista lo que haría, agrupado:

- paquetes del repositorio oficial y de repositorios de terceros;
- repositorios apt de terceros y claves de firma que añadiría;
- instalaciones fuera del gestor de paquetes (con su URL y destino);
- cambios fuera de `$HOME`;
- ficheros y directorios en `$HOME`;
- lo que ya está instalado.

Funciona con todos los perfiles en Linux, macOS y WSL2 (no desde Git Bash en
Windows). No toca `~/.devcli`: usa la copia del repo desde la que lo lances o,
con `bash <(curl …)`, un clon temporal que borra al terminar. Necesita `git` y
`jq`; si faltan, dice que los instalaría y se para (en un servidor:
`sudo apt install git jq`, ambos están en la lista del perfil `server`).

## Cambiar de perfil más tarde

No hay un perfil "guardado" en disco — devcli no recuerda qué elegiste la
última vez. Si quieres más herramientas, vuelve a ejecutar el bootstrap con
el perfil mayor (`dev` o `full`). Las que ya tenías no se reinstalan
(idempotente, una de las virtudes del enfoque).

Si has pasado de `full` a algo menor y quieres **quitar** las herramientas que
ya no necesitas, devcli no las desinstala por ti. Quítalas a mano con `scoop`
(Windows), `brew uninstall` (macOS) o `apt remove` (Linux/WSL2). Si ejecutaste
un perfil completo en un servidor por error, sigue
[Qué deja el perfil completo en el sistema y cómo retirarlo](desinstalar.md#qué-deja-el-perfil-completo-en-el-sistema-y-cómo-retirarlo).

## Para ver exactamente qué hace cada herramienta

Lee [herramientas.md](herramientas.md) — explica con ejemplos qué te aporta
cada una y cuándo la vas a usar.
