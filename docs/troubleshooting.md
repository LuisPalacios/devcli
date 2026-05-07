# Cuando algo no va

Lista de problemas comunes y cómo resolverlos. Si el tuyo no aparece, abre
una issue con la salida de `~/.devcli/install.log` adjunta.

## Los iconos no salen bien (eza/lsd, prompt)

Síntoma: ejecutas `ls` (o `eza` / `lsd` directamente) o miras el prompt y ves
cuadraditos `▢▢▢`, signos de interrogación `?` o cajas raras en lugar de
iconos.

Causa: tu terminal no está usando una **Nerd Font**. Las Nerd Fonts añaden a
las fuentes monoespaciadas un montón de iconos (símbolos de archivos,
carpetas, ramas de git, etc.) que el resto de la configuración asume.

devcli intenta instalar **FiraCode Nerd Font** automáticamente, pero a veces
no se pega al terminal correctamente. Para arreglarlo:

```bash
# Linux / macOS / WSL2
~/bin/nerd-setup.sh

# Verificar que está instalada
~/bin/nerd-verify.sh
```

```powershell
# Windows
& "$env:USERPROFILE\bin\nerd-setup.ps1"
& "$env:USERPROFILE\bin\nerd-verify.ps1"
```

Después: **abre tu terminal de nuevo** y selecciona "FiraCode Nerd Font" como
fuente del perfil:

- **WezTerm** *(recomendado)*: ya viene configurado con la fuente correcta. Si
  aún ves cuadraditos, asegúrate de que las Nerd Fonts están realmente
  instaladas (`fc-list | grep -i nerd` en Linux/macOS).
- Windows Terminal: *Configuración → tu perfil → Apariencia → Tipo de letra*.
- iTerm2 / Terminal.app (macOS): *Preferences → Profiles → Text → Font*.
- gnome-terminal / konsole (Linux): *Preferencias → Perfil → Texto → Fuente
  personalizada*.

## El antivirus bloquea el bootstrap (Windows)

Síntoma: ejecutas `iex (irm ...)` y Bitdefender / CrowdStrike / Sentinel /
Symantec lo marca como amenaza, o simplemente no pasa nada.

Solución: instalación en dos pasos — descarga el script primero, ejecuta
después.

```powershell
irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1" -OutFile "$env:TEMP\devcli-bootstrap.ps1"
& "$env:TEMP\devcli-bootstrap.ps1"
```

Funcionalmente es idéntico, pero los AVs no lo detectan como sospechoso
porque no es el patrón "descarga y ejecuta en una línea".

Más detalles en [requisitos-windows.md](requisitos-windows.md).

## winget devuelve "Acceso denegado" (Windows)

Es un problema de los AppExecutionAlias de Windows, especialmente en máquinas
recién provisionadas o ARM. devcli detecta el caso y omite los pasos que
dependen de winget — no rompe nada, sólo no instala lo que necesita winget.

Cómo arreglarlo permanentemente: tres opciones en
[requisitos-windows.md](requisitos-windows.md#problema-comun-winget-da-acceso-denegado).

## Una herramienta concreta no se instaló

Síntoma: el bootstrap acaba con "Instalación completada con avisos" y una
lista de fallos como:

```
[2/5] Herramientas de productividad         WARN  3s   14 ok, 1 fallido
      ⚠  kubectl: apt-get falló
```

Cómo investigar:

1. Mira `~/.devcli/install.log`. Cada herramienta tiene su sección, con la
   salida bruta del gestor (apt, scoop, winget...) que falló. Busca el nombre
   de la herramienta y lee qué dijo:

   ```bash
   grep -A 20 "kubectl" ~/.devcli/install.log | head -30
   ```

2. Si es transitorio (red, mirror caído, servidor de releases ocupado),
   simplemente vuelve a ejecutar el bootstrap. Las herramientas ya
   instaladas se saltan; intentará sólo las que faltan.

3. Si es persistente: prueba a instalarla a mano para ver el error real:

   - Linux/WSL2: `sudo apt install <pkg>` 
   - macOS: `brew install <pkg>`
   - Windows: `scoop install <pkg>` o `winget install <Id>`

   Esto te dará el mensaje completo del gestor sin que devcli lo capture.

## Quiero ver todo el detalle en pantalla

Por defecto devcli es silencioso (la salida de los gestores va al log). Si
quieres ver TODO en pantalla en tiempo real:

```bash
# Linux / macOS / WSL2
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) --verbose
```

```powershell
# Windows
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Verbose"
```

`--verbose` deshabilita la barra de progreso interactiva y vuelca todo el
output bruto (apt, scoop, winget, curl). Útil para depurar.

## Git Bash va lento

Conocido: arrancar Git Bash en Windows tarda más que arrancar zsh en Linux.
Las causas más comunes: antivirus escaneando ejecutables MSYS2, plugins
pesados en `.bashrc`, llamadas a `git` en cada prompt.

Si sospechas que tu prompt es la causa, prueba a arrancar con un `.bashrc`
mínimo y reactivar trozos progresivamente. devcli usa Oh-My-Posh, que
generalmente es ágil pero puede ser lento si tu repositorio tiene cientos de
miles de archivos.

## Quiero forzar una descarga limpia del repo

Por defecto devcli hace `git fetch + git reset --hard` (rápido). Si quieres
borrar `~/.devcli` completamente y volver a clonar desde cero (por ejemplo
porque el repo local quedó en un estado raro):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) --reclone
```

```powershell
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Reclone"
```

## La instalación no termina

Si el bootstrap se queda colgado más de unos minutos, lo más probable es que
una descarga esté tardando o que un gestor esté esperando confirmación. Pulsa
`Ctrl+C` para cancelarlo. devcli es idempotente — vuelve a ejecutarlo y
continúa donde lo dejó (las herramientas ya instaladas se saltan).

## Quiero borrarlo todo

Ver [desinstalar.md](desinstalar.md) — explica paso a paso qué tocó devcli y
cómo revertirlo.
