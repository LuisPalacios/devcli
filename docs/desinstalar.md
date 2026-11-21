# Cómo dar marcha atrás

devcli no incluye un script de desinstalación oficial. La filosofía es
"instala lo que quieres, mantén lo que te sirve, quita lo que no". Esta guía
te dice **qué tocó devcli** para que puedas revertir lo que necesites.

## Lo que devcli ha cambiado en tu sistema

### Software instalado

Las herramientas listadas en [perfiles.md](perfiles.md). Para quitarlas:

- **Windows (scoop):** `scoop uninstall <herramienta>`
- **Windows (winget):** `winget uninstall <Id>` (ej. `winget uninstall pnpm.pnpm`)
- **macOS (brew):** `brew uninstall <herramienta>`
- **Linux/WSL2 (apt):** `sudo apt remove <paquete>`

Si no recuerdas qué se instaló, mira [`install/tools.json`](../install/tools.json).
Tiene una entrada por herramienta con su nombre exacto en cada gestor.

### Archivos en tu HOME

Estos los copia el bootstrap (sobrescribe sin preguntar). Bórralos o
restáuralos desde tu backup según prefieras:

**Linux / macOS / WSL2:**
- `~/.zshrc`
- `~/.tmux.conf`, `~/.tmux-ai.conf`
- `~/.oh-my-posh.json`
- `~/.config/wezterm/wezterm.lua`, `~/.config/wezterm/wezterm.sh`
- `~/.nano/` (creado vacío)
- `~/.config/devcli/sin-descarga-tema` (sólo Linux/WSL2 con el perfil
  `server`: el `.zshrc` no descarga el tema del prompt al abrir sesión)

**Windows:**
- `%USERPROFILE%\.bashrc` (para Git Bash)
- `%USERPROFILE%\.oh-my-posh.json`
- `$PROFILE` de PowerShell 7 (`<Documentos>\PowerShell\Microsoft.PowerShell_profile.ps1`) y de PowerShell 5.1 (`<Documentos>\WindowsPowerShell\...`). `<Documentos>` es tu carpeta Documentos real, que puede estar redirigida a OneDrive; compruébalo con `$PROFILE`
- `%LOCALAPPDATA%\clink\oh-my-posh.lua`
- `%LOCALAPPDATA%\clink\clink_settings`
- `%USERPROFILE%\cmd_aliases.cmd`
- `%USERPROFILE%\.config\wezterm\wezterm.lua`, `wezterm.sh`

> Para `.zshrc`, devcli deja un `~/.zshrc.backup.YYYYMMDD_HHMMSS`, pero lo
> hace **después** de copiar el suyo: contiene la versión de devcli, no tu
> `.zshrc` anterior, así que no sirve para recuperarlo. Haz tu propia copia
> antes de ejecutar el bootstrap.

### Scripts auxiliares en `~/bin/`

devcli copia varios scripts útiles a `~/bin/` (creando el directorio si no
existía). Si quieres limpiarlos:

```bash
rm -rf ~/bin/{e,s,confcat,nerd-setup.sh,nerd-verify.sh}
```

(Y opcionalmente `rmdir ~/bin` si queda vacío.)

En Windows están en `%USERPROFILE%\bin\` con extensión `.ps1`.

### El directorio del repo

Puedes borrar `~/.devcli/` cuando quieras. Es sólo la copia del repo + el
`install.log`:

```bash
rm -rf ~/.devcli
```

Windows:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.devcli"
```

### Atajos estilo Mac (`custom_keys`)

Sólo si activaste `bootstrap.ps1 -CustomKeys on` (Windows). Ver
[teclado-mac.md](teclado-mac.md).

1. Que los siguientes bootstraps no los apliquen: `bootstrap.ps1 -CustomKeys off`.
   Esto **no** deshace nada por sí solo.
2. **Mapa de PowerToys:** abre el editor de Keyboard Manager
   (Win+Ctrl+Shift+Q) y borra los atajos, o restaura tu mapa anterior desde
   `~/.config/devcli/backups/custom-keys-<fecha>/` (`keyboard-manager-default.json`
   → `%LOCALAPPDATA%\Microsoft\PowerToys\Keyboard Manager\default.json`, con
   el editor cerrado) y reinicia PowerToys. Para deshacerlo del todo, apaga
   Keyboard Manager en PowerToys.
3. **Atajo del editor:** la copia `keyboard-manager-settings.json` de esa
   carpeta tiene el original (Win+Shift+Q), o cámbialo en PowerToys →
   Keyboard Manager.
4. **WezTerm:** borra `%USERPROFILE%\.config\wezterm\custom_keys.lua`.
5. **PowerToys** (si lo instaló devcli): `winget uninstall Microsoft.PowerToys`.
6. Opcional: borra `%USERPROFILE%\.config\devcli\` (estado y copias de seguridad).

### Claude Code: sin coautor en los commits

En todas las plataformas, la fase 03 fija en `~/.claude/settings.json`
(`%USERPROFILE%\.claude\settings.json` en Windows) la clave:

```json
"attribution": { "commit": "", "pr": "", "sessionUrl": false }
```

Sin ella, Claude Code añade `Co-Authored-By: Claude …` a cada commit y una
línea de atribución a cada PR, aunque tu `CLAUDE.md` lo prohíba: el ajuste es
por máquina. Sólo toca esa clave (y quita la antigua `includeCoAuthoredBy`);
el resto del fichero se respeta y, si tiene que escribir, deja antes un
`settings.json.backup.<fecha>`. Si el fichero no existe, lo crea con sólo esa
clave. Para deshacerlo, borra la clave `attribution` (o restaura el backup).

### La shell por defecto

En Linux / WSL2, devcli cambia tu shell por defecto a `zsh` con
`chsh -s $(command -v zsh)`. Para volver a bash:

```bash
chsh -s /bin/bash
```

Cierra sesión y vuelve a abrir para que aplique.

En macOS no cambia nada (zsh ya es la default desde Catalina).

En Windows no toca nada.

### Variables de entorno

En Linux / WSL2 (sólo Linux nativo, en realidad), si pasaste un `--lang`
distinto al default, devcli ejecuta `update-locale LANG=...`. Para
revertir:

```bash
sudo update-locale LANG=es_ES.UTF-8
```

En Windows, devcli pone una variable de entorno de usuario `OMP_OS_ICON` con
un emoji. Quítala desde *Settings → System → About → Advanced system settings
→ Environment Variables*, o:

```powershell
[Environment]::SetEnvironmentVariable('OMP_OS_ICON', $null, 'User')
```

### Buckets de scoop / cambios en winget

devcli añade el bucket `extras` a scoop si no estaba. Para quitarlo:

```powershell
scoop bucket rm extras
```

winget no se modifica más allá de instalar paquetes.

## Qué deja el perfil completo en el sistema y cómo retirarlo

Para quien ejecutó un perfil `minimal`, `dev` o `full` en **Linux (Debian y
derivados)** donde no debía, por ejemplo en un servidor. Primero el
inventario; después, las órdenes para seguir línea a línea. Si no estás
seguro de qué hizo exactamente en tu máquina, lanza la simulación del mismo
perfil (`bootstrap.sh -p full -n`): lista lo que haría, y lo que ya está
presente es, casi seguro, lo que dejó.

### Inventario

**Repositorios apt de terceros** (y su clave de firma):

| Repositorio | Fichero de fuentes | Clave | Perfil | Paquete |
|---|---|---|---|---|
| gierens (eza) | `/etc/apt/sources.list.d/gierens.list` | `/etc/apt/keyrings/gierens.gpg` | minimal, dev, full | `eza` |
| azlux | `/etc/apt/sources.list.d/azlux.list` | `/usr/share/keyrings/azlux.gpg` | minimal, dev, full | `gping` |
| kubernetes | `/etc/apt/sources.list.d/kubernetes.list` | `/usr/share/keyrings/kubernetes-apt-keyring.gpg` | full | `kubectl` |

gierens y azlux sólo se añaden ya si la distribución no trae `eza` o `gping`
en su repositorio oficial (Debian 13 trae los dos); las ejecuciones
anteriores los añadían siempre.

**Paquetes del repositorio oficial de la distribución**:

- Todos los perfiles: `git`, `curl`, `unzip`, `jq`, `wget`, `nano`, `zsh`.
- minimal, dev, full: `htop`, `tmux`, `zoxide`, `fzf`, `bat`, `fd-find`,
  `ripgrep`, `tree`, `eza`, `gping` y `lsd` si están en el oficial, y `gpg`
  (para importar las claves de arriba).
- dev, full: `libnss3-tools`.

**Paquetes `.deb` descargados de GitHub e instalados con `dpkg -i`** (sin
repositorio: nunca se actualizan):

- `lsd` (minimal, dev, full, sólo si no está en el repositorio oficial; las
  ejecuciones anteriores lo descargaban siempre) → `/usr/bin/lsd`.
- `wezterm` (dev, full, sólo si había escritorio) → `/usr/bin/wezterm`.

**Instalado fuera del gestor de paquetes, en `$HOME`**:

| Qué | Cómo | Dónde |
|---|---|---|
| oh-my-posh | binario verificado (versión fija, sha256) | `~/bin/oh-my-posh` (+ caché `~/.cache/oh-my-posh`, donde quedan `disable notice` y `disable upgrade`) |
| uv (dev, full) | binario verificado | `~/.local/bin/uv`, `~/.local/bin/uvx` (+ `~/.cache/uv` y `~/.local/share/uv` cuando lo usas) |
| pnpm (dev, full) | binario verificado | `~/.local/share/pnpm/devcli-pnpm/` y el enlace `~/.local/share/pnpm/bin/pnpm` (+ `~/.local/state/pnpm`, `~/.cache/pnpm` cuando lo usas) |
| FiraCode Nerd Font | zip de GitHub | `~/.local/share/fonts/FiraCodeNerdFont*.ttf`, `LICENSE`, `README.md` |
| mkcert (dev, full) | binario de `dl.filippo.io` | `~/bin/mkcert` |
| enlaces | `ln -s` | `~/bin/bat` → `batcat`, `~/bin/fd` → `fdfind` |

Los tres binarios verificados ya **no tocan `~/.bashrc` ni `~/.profile`**.
Las instalaciones anteriores los ponían con `curl … | sh`, y esos
instaladores sí dejaron cosas: pnpm, un bloque `# pnpm … # pnpm end` en
`~/.bashrc` y su instalación en `~/.local/share/pnpm`; uv, la línea
`. "$HOME/.local/bin/env"` en `~/.bashrc` y `~/.profile`, más
`~/.local/bin/{env,env.fish}`, `~/.config/uv/uv-receipt.json` y
`~/.config/fish/conf.d/uv.env.fish`. Volver a ejecutar el bootstrap
sustituye los binarios por los verificados, pero no borra esos restos: las
órdenes del paso 7 sí. Mientras quede `uv-receipt.json`, `uv self update`
puede cambiar la versión fijada.

**Fuera de `$HOME`** (además de lo que instalan los paquetes):

- Las fuentes y claves de la tabla de repositorios.
- `/etc/nanorc`, sobrescrito con el de devcli, y `/root/.nano/`.
- Sólo en Linux nativo y si el locale no existía: activa `es_ES.UTF-8` (o el
  de `-l`) en `/etc/locale.gen`, ejecuta `locale-gen` y fija
  `LANG` en `/etc/default/locale` con `update-locale`.
- Tu shell de inicio pasa a zsh (`chsh`, en `/etc/passwd`). Si lo ejecutaste
  como root, la de root.
- Efectos de los propios paquetes: por ejemplo `zsh` se añade a `/etc/shells`
  y `gpg` habilita sockets de usuario de systemd (`gpg-agent`, `dirmngr`). Se
  van al purgarlos.

**En `$HOME`**: los dotfiles y scripts de las secciones de arriba, `~/.zshenv`
(lo genera el `.zshrc` al abrir zsh), `~/.devcli/` y `~/.claude/settings.json`
(ver [su sección](#claude-code-sin-coautor-en-los-commits)).

### Órdenes, en este orden

Como el usuario que ejecutó el bootstrap (con `sudo`). Si lo ejecutaste como
root, cambia `"$USER"` por `root` en el paso 1. Cada orden es independiente:
si un paquete no está instalado, `apt-get` lo dice y sigue.

```bash
# --- 1. Shell de inicio (antes de quitar zsh) ---
sudo chsh -s /bin/bash "$USER"

# --- 2. Paquetes de repositorios de terceros (antes de quitar los repositorios) ---
sudo apt-get purge -y eza
sudo apt-get purge -y gping
sudo apt-get purge -y kubectl

# --- 3. Repositorios de terceros y sus claves ---
sudo rm -f /etc/apt/sources.list.d/azlux.list /usr/share/keyrings/azlux.gpg
sudo rm -f /etc/apt/sources.list.d/gierens.list /etc/apt/keyrings/gierens.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list /usr/share/keyrings/kubernetes-apt-keyring.gpg
sudo apt-get update

# --- 4. Paquetes .deb descargados de GitHub (sin repositorio) ---
dpkg -s lsd >/dev/null 2>&1 && sudo apt-get purge -y lsd
dpkg -s wezterm >/dev/null 2>&1 && sudo apt-get purge -y wezterm

# --- 5. /etc/nanorc, /root/.nano y locale ---
sudo apt-get purge -y nano          # se lleva el /etc/nanorc de devcli
sudo rmdir /root/.nano
cat /etc/default/locale             # LANG que dejó devcli
sudo sed -i 's/^es_ES.UTF-8 UTF-8/# es_ES.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
sudo update-locale --reset LANG=C.UTF-8   # o el LANG que tuvieras antes

# --- 6. Paquetes del repositorio oficial que añadió devcli ---
# Mira qué instaló (y cuándo) y quita de la lista lo que ya tuvieras o uses:
zgrep -hE '^Commandline: apt(-get)? install' /var/log/apt/history.log*
sudo apt-get purge -y htop tmux zoxide fzf bat fd-find tree libnss3-tools gpg unzip wget zsh
# Opcional, sólo si no los tenías antes y no los usas:
sudo apt-get purge -y git curl jq ripgrep
sudo apt-get autoremove --purge -y

# --- 7. Binarios y datos fuera del gestor de paquetes, en $HOME ---
rm -f ~/bin/oh-my-posh ~/bin/mkcert ~/bin/bat ~/bin/fd
rm -rf ~/.cache/oh-my-posh
rm -f ~/.local/bin/uv ~/.local/bin/uvx ~/.local/bin/env ~/.local/bin/env.fish
rm -f ~/.config/fish/conf.d/uv.env.fish ~/.config/uv/uv-receipt.json
rm -rf ~/.local/share/pnpm ~/.local/state/pnpm ~/.cache/pnpm
rm -f ~/.local/share/fonts/FiraCodeNerdFont*.ttf ~/.local/share/fonts/LICENSE ~/.local/share/fonts/README.md
# Líneas que añadieron los instaladores de pnpm y uv en instalaciones
# anteriores (las nuevas no las añaden; míralas antes de borrar):
grep -nE 'local/bin/env|PNPM_HOME|pnpm' ~/.bashrc ~/.profile ~/.bash_profile ~/.zshrc 2>/dev/null
sed -i '/^# pnpm$/,/^# pnpm end$/d' ~/.bashrc
sed -i '\|^\. "\$HOME/\.local/bin/env"$|d' ~/.bashrc ~/.profile

# --- 8. Dotfiles, scripts de ~/bin y la copia del repo ---
rm -f ~/.zshrc ~/.zshrc.backup.* ~/.zshenv ~/.tmux.conf ~/.tmux-ai.conf ~/.oh-my-posh.json
rm -rf ~/.config/wezterm ~/.nano
rm -f ~/bin/e ~/bin/s ~/bin/confcat ~/bin/ia ~/bin/nerd-setup.sh ~/bin/nerd-verify.sh
rmdir ~/bin
rm -rf ~/.devcli
# Directorios que quedan vacíos (rmdir nunca borra uno con contenido):
rmdir --ignore-fail-on-non-empty ~/.config/fish/conf.d ~/.config/fish ~/.config/uv ~/.config ~/.local/share/fonts ~/.local/share ~/.local/bin ~/.local/state ~/.local ~/.cache
```

Después, cierra la sesión y vuelve a entrar. Notas:

- No borres `/etc/apt/keyrings/`: el directorio es de apt, sólo sobra la
  clave de gierens.
- `apt-get autoremove` puede dejar alguna dependencia pequeña (por ejemplo
  `ca-certificates` u `openssl`) si otro paquete instalado la recomienda. Es
  lo normal en apt y no es un tercero.
- `~/.claude/settings.json` no se toca aquí: ver
  [su sección](#claude-code-sin-coautor-en-los-commits).
- Si después quieres el entorno en ese servidor, usa `-p server` (ver
  [perfiles.md](perfiles.md#el-perfil-server-en-detalle)).

### El perfil `server`

Si usaste `-p server`, no hay repositorios ni claves que quitar, ni nada en
`/etc` ni en tu shell de inicio. Hay que retirar lo de `$HOME` y, si quieres,
los paquetes oficiales que instaló:

```bash
# Binarios verificados y sus datos
rm -f ~/bin/oh-my-posh ~/.local/bin/uv ~/.local/bin/uvx
rm -rf ~/.cache/oh-my-posh ~/.local/share/pnpm ~/.local/state/pnpm ~/.cache/pnpm ~/.cache/uv ~/.local/share/uv
# Enlaces, dotfiles, scripts, marcador y la copia del repo
rm -f ~/bin/bat ~/bin/fd ~/bin/confcat ~/bin/s
rm -f ~/.zshrc ~/.zshrc.backup.* ~/.zshenv ~/.tmux.conf ~/.oh-my-posh.json
rm -f ~/.config/devcli/sin-descarga-tema
rm -rf ~/.devcli
rmdir --ignore-fail-on-non-empty ~/bin ~/.local/bin ~/.config/devcli
# Paquetes oficiales (quita de la lista lo que ya tuvieras o uses)
sudo apt-get purge -y vim tmux htop ripgrep zsh lsd eza zoxide fzf bat fd-find tree gping
# Sólo si no los tenías antes: git curl jq ca-certificates
sudo apt-get autoremove --purge -y
```

`~/.bashrc` y `~/.profile` no se tocan en este perfil.

## Si quieres una limpieza completa, en orden

1. `rm -rf ~/.devcli` (Linux/macOS/WSL2) o `Remove-Item -Recurse -Force "$env:USERPROFILE\.devcli"` (Windows).
2. `rm -rf ~/bin` (si solo lo usaba devcli).
3. Borra los dotfiles del HOME (lista arriba).
4. Desinstala las herramientas que no quieras conservar (sección anterior).
5. (Linux/WSL2) `chsh -s /bin/bash` para volver a tu shell anterior.
6. Cierra sesión y vuelve a abrir.

## Lo que devcli NO ha tocado

Para tu tranquilidad:

- Fuera de `$HOME`, en Linux con los perfiles `minimal`/`dev`/`full`, sólo lo
  que lista el [inventario](#inventario): paquetes, los repositorios de
  terceros con sus claves, los `.deb` de `lsd`/`wezterm`, `/etc/nanorc`,
  `/root/.nano`, el locale y el `chsh`. Con `server`, sólo paquetes oficiales.
- No ha tocado `/etc/passwd` salvo el `chsh` arriba (nunca con `server`).
- No ha instalado servicios systemd, demonios, ni nada que arranque en boot
  (salvo PowerToys en Windows, y sólo si activaste `-CustomKeys on`).
- No ha modificado tu `.gitconfig`, claves SSH, ni configuración de
  aplicaciones (navegadores, IDEs, etc.), salvo la clave `attribution` de
  Claude Code descrita arriba.

Si te interesa exactamente qué se ejecuta en cada paso, lee
[auditoria.md](auditoria.md).
