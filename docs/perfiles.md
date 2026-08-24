# Perfiles de instalación

devcli no te impone una lista cerrada de herramientas. Eliges un **perfil** y se
instala sólo el subconjunto que necesitas. Útil si la máquina es pequeña, si
estás en un servidor sin entorno gráfico, o si simplemente no quieres ruido.

## Qué hay en cada perfil

| Perfil | Qué te llevas | Cuándo elegirlo |
|--------|---------------|-----------------|
| `minimal` | Lo esencial para vivir en la CLI: `htop`, `tmux`, `fzf`, `bat`, `fd`, `ripgrep`, `eza` (+ `lsd` como fallback), `tree`, `zoxide`, `gping` | Servidores, contenedores, máquinas que sólo abres por SSH, o si quieres probar antes de comprometerte. |
| `dev` | Todo lo de `minimal` + **WezTerm** *(la terminal multiplataforma recomendada)* + herramientas de desarrollo: `mkcert`, `nss`, `pnpm`, `uv` | Tu portátil de trabajo. Es el sweet spot para la mayoría de la gente. |
| `full` *(por defecto)* | Todo lo de `dev` + extras: `kubectl`, y en Windows `clink` y `quicklook` | Tu máquina principal donde vives. Si tienes dudas, este. |

> Las herramientas "base" (git, curl, wget, nano, zsh, jq, oh-my-posh) **siempre**
> se instalan, independientemente del perfil. Sin ellas, devcli no funciona.
>
> **WezTerm en Linux**: aunque elijas `dev` o `full`, en Linux sólo se instala
> si devcli detecta un entorno de escritorio. En servidores headless se omite
> automáticamente (es una app gráfica). Más detalles en
> [wezterm.md](wezterm.md).

## Cómo elegir un perfil

**Linux, macOS, WSL2, Git Bash:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p minimal
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) -p dev
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh)            # full
```

**Windows (PowerShell 7):**

```powershell
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile minimal"
iex "& {$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -Profile dev"
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1")                  # full
```

## Cambiar de perfil más tarde

No hay un perfil "guardado" en disco — devcli no recuerda qué elegiste la
última vez. Si quieres más herramientas, vuelve a ejecutar el bootstrap con
el perfil mayor (`dev` o `full`). Las que ya tenías no se reinstalan
(idempotente, una de las virtudes del enfoque).

Si has pasado de `full` a algo menor y quieres **quitar** las herramientas que
ya no necesitas, devcli no las desinstala por ti. Quítalas a mano con `scoop`
(Windows), `brew uninstall` (macOS) o `apt remove` (Linux/WSL2). Ver
[desinstalar.md](desinstalar.md) para más contexto.

## Para ver exactamente qué hace cada herramienta

Lee [herramientas.md](herramientas.md) — explica con ejemplos qué te aporta
cada una y cuándo la vas a usar.
