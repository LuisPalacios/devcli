# Perfiles de instalación

devcli no te impone una lista cerrada de herramientas. Eliges un **perfil** y se
instala sólo el subconjunto que necesitas. Útil si la máquina es pequeña, si
estás en un servidor sin entorno gráfico, o si simplemente no quieres ruido.

> [!IMPORTANT]
> **En servidores, usa siempre el perfil `server`.** El resto de perfiles están
> pensados para equipos personales (portátiles, estaciones de trabajo, VM de
> desarrollo): añaden repositorios apt de terceros con sus claves, descargan
> binarios fuera del gestor de paquetes y tocan configuración del sistema.
> Cada repositorio de terceros es alguien más que puede instalar o sustituir
> paquetes como root en cada actualización, y queda fuera de las
> actualizaciones automáticas de seguridad limitadas a los orígenes de la
> distribución.

## Qué hay en cada perfil

| Perfil | Qué te llevas | Cuándo elegirlo |
|--------|---------------|-----------------|
| `server` | Sólo paquetes del **repositorio oficial** de la distribución: `git`, `curl`, `jq`, `ca-certificates`, `vim`, `tmux`, `htop`, `ripgrep`, `zsh`. Con `--diag`, además `tcpdump`, `iperf3` y `socat`. Y los dotfiles `~/.zshrc` y `~/.tmux.conf`. | **Servidores.** Cualquier máquina que no sea tuya y personal. Sólo Linux (Debian y derivados) y WSL2. |
| `minimal` | Lo esencial para vivir en la CLI: `htop`, `tmux`, `fzf`, `bat`, `fd`, `ripgrep`, `eza` (+ `lsd` como fallback), `tree`, `zoxide`, `gping` | Equipos personales pequeños o si quieres probar antes de comprometerte. **No** es para servidores: en Linux añade dos repositorios de terceros (eza, gping) y descarga `lsd`, `oh-my-posh` y una Nerd Font. |
| `dev` | Todo lo de `minimal` + **WezTerm** *(la terminal multiplataforma recomendada)* + herramientas de desarrollo: `mkcert`, `nss`, `pnpm`, `uv` | Tu portátil de trabajo. Es el sweet spot para la mayoría de la gente. |
| `full` | Todo lo de `dev` + extras: `kubectl`, y en Windows `clink` y `quicklook` | Tu máquina principal donde vives. |

> En los perfiles `minimal`, `dev` y `full` las herramientas "base" (git, curl,
> wget, nano, zsh, jq, oh-my-posh) **siempre** se instalan. El perfil `server`
> es la excepción: de las base sólo instala git, curl, jq y zsh.
>
> **WezTerm en Linux**: aunque elijas `dev` o `full`, en Linux sólo se instala
> si devcli detecta un entorno de escritorio. En servidores headless se omite
> automáticamente (es una app gráfica). Más detalles en
> [wezterm.md](wezterm.md).

## El perfil `server` en detalle

Lo que **hace**:

- Instala con `apt-get --no-install-recommends` (sin paquetes recomendados y
  sin preguntas de debconf) sólo la lista de arriba, y sólo los que falten.
- Copia `~/.zshrc` y `~/.tmux.conf` (con copia de seguridad del `.zshrc`), y
  los scripts `~/bin/confcat` y `~/bin/s`.
- Como en todos los perfiles, fija la clave `attribution` en
  `~/.claude/settings.json` (ver [desinstalar.md](desinstalar.md#claude-code-sin-coautor-en-los-commits)).

Lo que **no hace**, nunca:

- No añade repositorios apt ni claves de firma.
- No instala nada fuera de apt: ni `curl | sh`, ni binarios o `.deb` de
  releases, ni cargo/go/npm/pipx, ni snap, flatpak o brew. `oh-my-posh`,
  `lsd`, `eza`, `zoxide` y las Nerd Fonts no se instalan.
- No instala herramientas de Kubernetes ni de contenedores, entornos gráficos
  ni fuentes.
- No toca la configuración del sistema: ni el locale, ni `/etc/nanorc`, ni
  sshd, sudoers, cortafuegos, sysctl, servicios, usuarios ni `/etc` en
  general. **Tampoco cambia tu shell de inicio** (`chsh` escribe en
  `/etc/passwd`): al terminar te dice cómo hacerlo tú si quieres zsh:

  ```bash
  chsh -s /usr/bin/zsh
  ```

Además, aunque alguien etiquete por error en `install/tools.json` una
herramienta que se instale de otra forma, el bootstrap **se niega** a
instalarla en este perfil: sólo acepta el método `apt`, sin hooks.

Los dotfiles funcionan sin las herramientas que faltan: sin `eza`/`lsd`, `ls`
es el de siempre; sin `zoxide`, `cd` es el estándar; sin `oh-my-posh`, el
prompt es uno sencillo (`usuario@servidor-ejemplo:~%`). Sin avisos al abrir
sesión.

Lo que instalan los propios paquetes oficiales es cosa suya, no de devcli: por
ejemplo, `zsh` se añade a `/etc/shells`, y con `--diag` `iperf3` trae una unidad
de systemd que Debian deja desactivada y `tcpdump` un perfil de AppArmor.

> El bootstrap sigue necesitando `sudo` sin contraseña para el usuario que lo
> ejecuta (ver [requisitos-unix.md](requisitos-unix.md)), también en este perfil.

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
