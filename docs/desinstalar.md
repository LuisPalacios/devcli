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

**Windows:**
- `%USERPROFILE%\.bashrc` (para Git Bash)
- `%USERPROFILE%\.oh-my-posh.json`
- `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `%USERPROFILE%\AppData\Local\clink\oh-my-posh.lua`
- `%USERPROFILE%\AppData\Local\clink\clink_settings`
- `%USERPROFILE%\cmd_aliases.cmd`
- `%USERPROFILE%\.config\wezterm\wezterm.lua`, `wezterm.sh`

> Para `.zshrc` específicamente, devcli crea un backup automático
> (`~/.zshrc.backup.YYYYMMDD_HHMMSS`) antes de sobrescribirlo. Mira si tienes
> uno antes de tirarte al monte.

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

## Si quieres una limpieza completa, en orden

1. `rm -rf ~/.devcli` (Linux/macOS/WSL2) o `Remove-Item -Recurse -Force "$env:USERPROFILE\.devcli"` (Windows).
2. `rm -rf ~/bin` (si solo lo usaba devcli).
3. Borra los dotfiles del HOME (lista arriba).
4. Desinstala las herramientas que no quieras conservar (sección anterior).
5. (Linux/WSL2) `chsh -s /bin/bash` para volver a tu shell anterior.
6. Cierra sesión y vuelve a abrir.

## Lo que devcli NO ha tocado

Para tu tranquilidad:

- No ha modificado nada de root salvo `/etc/locale.gen` y `/etc/nanorc` (en
  Linux nativo).
- No ha tocado `/etc/passwd` salvo el `chsh` arriba.
- No ha instalado servicios systemd, demonios, ni nada que arranque en boot.
- No ha modificado tu `.gitconfig`, claves SSH, ni configuración de
  aplicaciones (navegadores, IDEs, etc.).

Si te interesa exactamente qué se ejecuta en cada paso, lee
[auditoria.md](auditoria.md).
