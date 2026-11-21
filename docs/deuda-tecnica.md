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
repositorios ni descarga nada fuera de apt.

### Repositorio azlux con versión de Debian fija y clave sin comprobar

- **Dónde:** `setup_azlux_repo` en `install/utils.sh`.
- **Qué pasa:** la línea de fuentes lleva `bookworm` fijo, así que en otras
  versiones de Debian o en Ubuntu se instalan paquetes de bookworm. La clave
  se descarga con `curl -s` sin `-f`: si la descarga falla, se escribe una
  clave vacía o una página de error sin que nadie se entere.
- **Arreglo:** tomar el codename de `/etc/os-release` (o quitar el
  repositorio si `gping` ya está en el repositorio oficial de la
  distribución) y usar `curl -fsSL` con comprobación del resultado.

### Repositorio de gierens por `http`

- **Dónde:** `setup_gierens_repo` en `install/utils.sh`.
- **Qué pasa:** `http://deb.gierens.de`. Va firmado, así que no se pueden
  colar paquetes, pero el tráfico no va cifrado (se ve qué se instala y se
  puede retener una actualización).
- **Arreglo:** `https` si el repositorio lo ofrece, o usar `eza` del
  repositorio oficial donde ya exista.

### Descargas sin verificación de integridad

- **Dónde:** `method_github_deb`, `method_github_binary`, `method_curl_sh` y
  `method_github_zip` en `install/utils.sh`.
- **Qué pasa:**
  - `lsd` y `wezterm` se descargan como `.deb` de GitHub y se instalan con
    `sudo dpkg -i` sin comprobar suma ni firma; al no venir de un
    repositorio, nunca se actualizan.
  - `mkcert` se descarga con `curl -JLo` sin `-f`: un error HTTP acaba
    guardado como si fuera el binario.
  - `oh-my-posh`, `pnpm` y `uv` se instalan con `curl … | sh` sin versión
    fija ni verificación. Los instaladores de `pnpm` y `uv` además añaden
    líneas a `~/.bashrc` y `~/.profile`.
  - La Nerd Font se descarga sin comprobar suma.
- **Arreglo:** fijar versiones y comprobar `sha256` publicado por cada
  proyecto; `curl -f` en todas las descargas; preferir el paquete del
  repositorio oficial cuando exista.

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
