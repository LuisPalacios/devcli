# Deuda técnica

Lo que se sabe que está mal o a medias y todavía no se ha arreglado. Cada
punto dice dónde está, qué pasa y qué haría falta. Cuando se arregle uno,
se borra de aquí.

## Errores

### La copia de seguridad de `.zshrc` no guarda el anterior

- **Dónde:** `customize_zshrc` en `install/03-dotfiles.sh`.
- **Qué pasa:** la fase 03 copia primero el `.zshrc` de devcli y *después*
  hace `~/.zshrc.backup.<fecha>`, así que la copia contiene la versión de
  devcli. El `.zshrc` que tuviera el usuario se pierde sin copia.
- **Arreglo:** hacer la copia antes del `cp -f`, sólo si el destino existe y
  es distinto del que se va a copiar.

### Como root sin `sudo`, el bootstrap se para

- **Dónde:** comprobación `sudo -n true` en `bootstrap.sh` (y
  `check_sudo_access` en `install/utils.sh`).
- **Qué pasa:** se exige `sudo` aunque el usuario sea root.
  `docs/requisitos-unix.md` dice que como root se saltan esas
  comprobaciones, pero en un sistema sin el paquete `sudo` (contenedores,
  instalaciones mínimas) el bootstrap aborta. Visto leyendo el código; sin
  probar en una máquina real.
- **Arreglo:** con `IS_ROOT=true`, no exigir `sudo` y ejecutar las órdenes
  sin él; o corregir la documentación.

### Dentro de un contenedor de Docker Desktop se detecta WSL2

- **Dónde:** `detect_os_type` en `bootstrap.sh` e `install/env.sh`.
- **Qué pasa:** Docker Desktop corre sobre el kernel de WSL2 y
  `/proc/version` contiene «microsoft», así que un contenedor Linux se trata
  como WSL2: sin `-p` se aplica `full` (no se pregunta) y se omite el locale.
- **Arreglo:** distinguir WSL2 de verdad (`WSL_DISTRO_NAME`, `/proc/sys/fs/binfmt_misc/WSLInterop`
  o `/run/WSL`) del kernel compartido. Mientras tanto, en contenedores pasar
  siempre `-p`.

## Seguridad de la cadena de suministro (perfiles `minimal`, `dev`, `full`)

El perfil `server` no tiene ninguno de estos problemas: no añade
repositorios y lo único que descarga fuera de apt son los tres binarios
verificados (versión fija y sha256 comprobada).

### Repositorio azlux con versión de Debian fija y clave sin comprobar

- **Dónde:** `setup_azlux_repo` en `install/utils.sh`.
- **Qué pasa:** mitigado: sólo se añade si `gping` no está en el
  repositorio oficial (por ejemplo, Debian 12 o Ubuntu 22.04); en Debian 13
  ya no. Cuando se usa, la línea de fuentes lleva `bookworm` fijo, así que en
  Ubuntu se instalan paquetes de bookworm, y la clave se descarga con
  `curl -s` sin `-f`: si la descarga falla, se escribe una clave vacía o una
  página de error sin que nadie se entere.
- **Arreglo:** tomar el codename de `/etc/os-release` y usar `curl -fsSL`
  con comprobación del resultado.

### Repositorio de gierens por `http`

- **Dónde:** `setup_gierens_repo` en `install/utils.sh`.
- **Qué pasa:** mitigado: sólo se añade si `eza` no está en el repositorio
  oficial (por ejemplo, Debian 12 o Ubuntu 22.04). Cuando se usa,
  `http://deb.gierens.de`: va firmado, así que no se pueden colar paquetes,
  pero el tráfico no va cifrado (se ve qué se instala y se puede retener una
  actualización).
- **Arreglo:** `https` si el repositorio lo ofrece.

### Descargas sin verificación de integridad

- **Dónde:** `method_github_deb`, `method_github_binary` y
  `method_github_zip` en `install/utils.sh`.
- **Qué pasa:**
  - `wezterm`, y `lsd` donde no está en el repositorio oficial, se
    descargan como `.deb` de GitHub y se instalan con `sudo dpkg -i` sin
    comprobar suma ni firma; al no venir de un repositorio, nunca se
    actualizan.
  - `mkcert` se descarga con `curl -JLo` sin `-f` y sin versión fija
    (`latest`): un error HTTP acaba guardado como si fuera el binario.
  - La Nerd Font se descarga sin comprobar suma.
- **Arreglo:** pasarlas al método `verified-binary` (versión fija y sha256
  en `tools.json`), como `oh-my-posh`, `uv` y `pnpm`; para los `.deb`,
  comprobar la suma antes del `dpkg -i`.

### macOS sigue instalando `oh-my-posh` y `uv` con `curl … | sh`

- **Dónde:** entradas `macos` de `oh-my-posh` y `uv` en `install/tools.json`.
- **Qué pasa:** en Linux y WSL2 ya son binarios verificados; en macOS se
  dejó como estaba (método `curl-sh`, sin versión fija; el instalador de uv
  edita los ficheros de arranque de la shell).
- **Arreglo:** Homebrew (`brew install oh-my-posh uv`), o `verified-binary`
  con los artefactos `darwin` de cada release.

## Detalles menores

### La simulación necesita `git` y `jq`

- **Dónde:** `bootstrap.sh` (modo `-n`).
- **Qué pasa:** sin `git` o `jq`, la simulación dice qué instalaría hasta
  ese punto y se para. En un servidor recién instalado hay que hacer antes
  `sudo apt install git jq` (ambos están en la lista del perfil `server`).
- **Arreglo:** sólo si molesta en la práctica; leer `tools.json` sin `jq` no
  compensa.

### Ruta absoluta en una línea de la simulación

- **Dónde:** `ensure_claude_attribution` en `install/utils.sh`.
- **Qué pasa:** su nota de simulación muestra `/home/<usuario>/.claude/…` en
  lugar de `~/.claude/…` como el resto.
- **Arreglo:** usar `_tilde`, que ya está en `utils.sh`.

### El perfil `server` sigue exigiendo `sudo` sin contraseña

- **Dónde:** `bootstrap.sh` y las fases 01, 02 y 04.
- **Qué pasa:** es una decisión, no un error: se mantuvo el requisito de
  siempre. Pero obliga a tener una regla `NOPASSWD` en sudoers también en
  servidores, donde no siempre se quiere.
- **Arreglo, si se decide cambiarlo:** con terminal, `sudo -v` una vez al
  principio; sin terminal ni `sudo` sin contraseña, listar los paquetes que
  faltan, desplegar sólo los dotfiles y terminar con aviso.

## Sin probar

- **Windows:** los cambios del perfil `server` y de la simulación no tocan
  PowerShell; desde Git Bash sólo se ha comprobado que `-p server` y `-n` se
  rechazan antes de hacer nada.
- **Root sin `sudo`:** ver el error de arriba.
