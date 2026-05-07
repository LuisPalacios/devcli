# WezTerm con devcli

**WezTerm es mi terminal multiplataforma preferida y la única que devcli
recomienda explícitamente.** Una sola configuración para Windows, macOS y
Linux, con los mismos atajos, los mismos temas y la misma experiencia.
devcli la instala con los perfiles `dev` y `full`, y le añade una
**super-config** (~750 líneas en Lua) con todo lo que quieres pero no
quieres tener que configurar tú.

[WezTerm](https://wezterm.org) es un emulador moderno escrito en Rust: rápido
(GPU acceleration), configuración en Lua (no JSON) y muy extensible. Frente a
las terminales nativas (Windows Terminal, iTerm2, gnome-terminal) gana en
portabilidad — la misma config funciona idéntica en los tres OS — y en
features (layouts complejos, multiplexor integrado, ligaduras de fuente,
shell integration vía OSC-7/133).

## Qué te da devcli encima de WezTerm

- **Selector de shell al abrir una pestaña nueva** *(Windows)* — eliges entre
  Git Bash, PowerShell 7, Ubuntu/WSL, CMD y PowerShell 5 con un picker visual.
- **Persistencia del tamaño de ventana** — WezTerm recuerda el tamaño y el
  estado maximizado entre sesiones. La primera ventana siempre se centra en
  tu pantalla principal.
- **Selector de temas con preview** — más de 900 temas integrados + tus
  propios `LP-*` custom, todos buscables con un picker fuzzy.
- **AI Mode** — un atajo abre una ventana nueva con cuatro paneles de Claude
  pre-configurados (Opus + Sonnet + Haiku + shell). Más en
  [wezterm-ai-mode.md](wezterm-ai-mode.md).
- **Misma fuente, mismo tema, mismo prompt** que tienes en zsh/PowerShell
  fuera de WezTerm — la experiencia es coherente entre terminales.

## Atajos que vas a usar a diario

| Atajo | Qué hace | Plataforma |
|-------|----------|------------|
| `CTRL+SHIFT+T` | Selector de shells (Git Bash, pwsh, WSL, CMD…) | Windows |
| `CTRL+ALT+T` | Nueva pestaña con el mismo shell que la actual | Windows |
| `CTRL+SHIFT+E` | Selector de temas (fuzzy + preview) | Todas |
| `CTRL+ALT+N` | AI Mode (4 paneles Claude) | Windows |
| `CTRL+SUPER+N` | AI Mode (4 paneles Claude) | macOS, Linux |
| `CTRL+SHIFT+R` | Recargar configuración sin reiniciar | Todas |
| `CTRL+SHIFT+L` | Mostrar / ocultar debug overlay | Todas |
| `Click derecho` | Copia si hay selección, pega si no | Todas |

> En Windows usamos `CTRL+ALT+N` para AI Mode porque `WIN+N` colisiona con el
> Centro de notificaciones de Windows. En macOS / Linux usamos `CTRL+SUPER+N`
> porque `ALT+N` produce el carácter `~` en muchos layouts europeos.

## Cómo cambiar el tema

Pulsa `CTRL+SHIFT+E`. Te aparece un picker fuzzy con todos los temas
disponibles — más de 900 integrados de WezTerm + los temas custom que vienen
con devcli (`LP-GitBash`, `LP-Campbell`, `LP-Campbell Powershell`,
`LP-Ubuntu`).

Escribe parte del nombre para filtrar:

- `dracula` → muestra todas las variantes Dracula
- `LP-` → muestra sólo los temas custom de devcli
- `dark` → todos los temas oscuros
- `solarized` → todas las variantes Solarized

`Enter` aplica el tema **a la ventana actual**. El cambio es instantáneo. Si
quieres que sea permanente, edita la línea `color_scheme` en
`~/.config/wezterm/wezterm.lua`.

> Cada ventana puede tener su propio tema (`set_config_overrides` es
> window-scoped en WezTerm). Útil para distinguir visualmente sesiones de
> trabajo vs personales, prod vs staging, etc.

## Cómo elegir qué shell usa una pestaña *(Windows)*

Pulsa `CTRL+SHIFT+T` para abrir el selector. Eliges una de:

- **Git Bash** — bash de MSYS2 con el `.bashrc` que devcli copia.
- **PowerShell 7 (pwsh)** — el moderno, recomendado para uso diario.
- **Ubuntu (WSL2)** — entra directamente a tu distro de WSL.
- **CMD** — el `cmd.exe` clásico, con `clink` activo si lo tienes.
- **PowerShell 5 (Windows PowerShell)** — el legacy.

Cada perfil viene con su propio tema visual asignado para que las distingas
de un vistazo.

Última opción del menú: **"Tab in this window (same shell)"** — abre una
nueva pestaña en la ventana actual con el mismo shell que ya estás usando.
Atajo directo: `CTRL+ALT+T`.

## Tamaño de ventana

WezTerm se acuerda del tamaño que le diste la última vez. Maximiza la
ventana → cierra → abre de nuevo: aparece maximizada. Redimensiona a 120×40
→ cierra → abre: aparece a 120×40.

La primera ventana de cada sesión se centra automáticamente en la pantalla
principal. Las siguientes se abren donde WezTerm decida (no podemos
controlar la posición exacta, sólo el tamaño).

## Para el AI Mode

Es lo bastante grande como para tener su propia guía. Léete
[wezterm-ai-mode.md](wezterm-ai-mode.md).

## Para personalizar más

La configuración completa de WezTerm está en `~/.config/wezterm/wezterm.lua`
después de la instalación. Es un fichero único (~750 líneas), partido en
secciones bien marcadas (§1 helpers, §2 shell choice, §3 appearance, §4 AI
Mode, §5 shell picker, §6 window state, §7 keys, §8 mouse).

> ⚠️ Si haces cambios directamente en `~/.config/wezterm/wezterm.lua`, el
> próximo bootstrap los sobrescribe. Si quieres customizar permanentemente,
> haz fork del repo y edita `dotfiles/wezterm.lua`. O comenta las líneas de
> `wezterm.lua` en `install/03-dotfiles.json` para que devcli no la copie.
