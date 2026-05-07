# WezTerm

**WezTerm es mi terminal multiplataforma preferida y que devcli
instala.** Una sola configuración para Windows, macOS y
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
  pre-configurados (Opus + Sonnet + Haiku + shell). Sección
  [AI Mode](#ai-mode) más abajo.
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

## AI Mode

AI Mode es un atajo de WezTerm que abre una ventana con **cuatro paneles
pre-configurados**: tres con sesiones de [Claude Code](https://claude.ai/code)
listas para usar, y un panel de shell para ejecutar comandos. Los tres
modelos diferentes te permiten paralelizar o comparar respuestas sin abrir
terminales nuevas.

Sólo está disponible si tienes WezTerm instalado (perfiles `dev` o `full`)
**y** el binario `claude` accesible en tu PATH (no se instala con devcli — es
un componente aparte de Anthropic).

### Cómo abrirlo

| Atajo | Plataforma |
| ----- | ---------- |
| `CTRL+ALT+N` | Windows |
| `CTRL+SUPER+N` | macOS, Linux |

Lo lanzas desde cualquier pane de WezTerm. Se abre una **ventana nueva**
(no una pestaña) con la siguiente disposición:

```text
┌─────────────────────────────────┬──────────────┐
│                                 │   sonnet     │
│           opus                  │              │
│                                 ├──────────────┤
│                                 │              │
├─────────────────────────────────┤   haiku      │
│  shell                          │              │
└─────────────────────────────────┴──────────────┘
```

- **Pane grande arriba-izquierda:** `claude --model opus`. El más capaz.
  Para problemas complejos, código difícil, análisis profundo.
- **Pane arriba-derecha:** `claude --model sonnet`. Equilibrio velocidad /
  calidad. Para la mayoría de las preguntas.
- **Pane abajo-derecha:** `claude --model haiku`. El más rápido. Para
  preguntas cortas, lookups, generación de código boilerplate.
- **Pane abajo-izquierda:** un shell normal. Para ejecutar lo que los Claudes
  te sugieran sin perder el contexto visual.

La ventana ocupa el 70% del ancho y 80% del alto de tu pantalla principal,
centrada. Es **independiente del tamaño guardado** de tus ventanas normales
de WezTerm — para que no canibalice un layout de 4 paneles si tienes una
ventana muy pequeña como default.

### Cómo se hereda el directorio de trabajo

El directorio de trabajo (cwd) de los cuatro paneles se hereda del pane desde
el que pulsaste el atajo. Si estás en `~/proyectos/cliente-X/backend`, los
cuatro Claudes y el shell arrancan ahí. Útil: el contexto de archivos
relevantes está disponible automáticamente para cada Claude.

### Workflow típico

**Caso 1 — Comparar respuestas:** pegas la misma pregunta en opus y sonnet,
ves cuál te convence más. Útil cuando dudas si vale la pena el coste/latencia
del modelo grande.

**Caso 2 — División de tareas por dificultad:** opus piensa el diseño del
sistema, sonnet implementa los pedazos individuales, haiku se encarga de
generar mocks/fixtures/tests boilerplate. Tú coordinas desde el shell.

**Caso 3 — Investigación paralela:** opus lee y resume un repo grande,
sonnet busca bugs concretos, haiku genera comandos `rg` / `fd` que tú
ejecutas en el shell.

**Caso 4 — Pair programming asíncrono:** mientras opus está pensando una
respuesta larga (puede tardar minutos), preguntas en sonnet algo
secundario en paralelo. No bloquea.

### Navegar entre paneles

Atajos estándar de WezTerm:

| Atajo | Qué hace |
| ----- | -------- |
| `CTRL+SHIFT+↑↓←→` | Mover el foco al pane vecino en esa dirección |
| `CTRL+SHIFT+ALT+↑↓←→` | Redimensionar el pane actual |
| `CTRL+SHIFT+Z` | Maximizar el pane actual (toggle) |
| `CTRL+SHIFT+Q` | Cerrar el pane actual |

Si maximizas un pane (`CTRL+SHIFT+Z`) puedes trabajar a pantalla completa
con un Claude y volver al layout de 4 con el mismo atajo.

### Cuándo se cierra

La ventana de AI Mode no es persistente. Se cierra cuando cierras todos los
paneles que la componen. Si **un pane** de Claude muere (porque escribes
`/exit`, o porque el proceso de Claude crashea), ese pane se cierra pero los
demás siguen vivos. Si todos cierran, la ventana se va con ellos.

> Si quieres "salir" del AI Mode pero no perder lo que tenías, simplemente
> minimiza la ventana o cambia a otra. El contexto de cada Claude vive
> dentro del pane mientras éste esté abierto.

### Si el atajo no hace nada

Comprobaciones, en orden:

1. ¿WezTerm es la terminal activa cuando pulsas el atajo? El atajo está
   definido en la configuración de WezTerm; no funciona desde Windows
   Terminal, iTerm2, etc.
2. ¿El binario `claude` está en tu PATH? Pruébalo: `claude --version`.
   Si no, instálalo desde la [documentación oficial de Claude Code](https://docs.claude.com/en/docs/claude-code/quickstart).
3. ¿Tienes la versión de WezTerm que viene con devcli? Verifica que existe
   `~/.config/wezterm/wezterm.lua` y que es el del repo. Si lo has editado a
   mano y has roto algo, ejecuta `~/bin/nerd-verify.sh` o re-ejecuta el
   bootstrap para restaurarlo.
4. ¿La tecla está siendo capturada por el sistema operativo? En Windows
   `WIN+N` y `WIN+ALT+N` están reservados; por eso usamos `CTRL+ALT+N`. En
   macOS los atajos con `CMD` se reservan también; por eso usamos
   `CTRL+SUPER+N`. Si tienes una utilidad de window manager interceptando,
   puede colisionar.

Si todo lo anterior está bien y sigue sin funcionar, abre `CTRL+SHIFT+L` en
WezTerm — te da un debug overlay con los logs de la configuración. Busca
mensajes de error relacionados con `find_claude_bin` o `open_ai_mode`.

### Limitaciones conocidas

- **No persiste el estado.** Si cierras la ventana, la siguiente vez arrancas
  conversaciones nuevas. Si necesitas mantener una sesión larga viva, usa
  `claude` desde un pane normal (no AI Mode) y déjalo en una ventana
  dedicada.
- **El layout es fijo.** Las proporciones de los paneles están definidas en
  el código (opus 65% horizontal, etc.). Si quieres customizarlas, edita los
  valores `LAYOUT_*` en la sección §4 de `dotfiles/wezterm.lua` y haz fork.
- **Sólo Claude.** No es un panel genérico para cualquier asistente — está
  cableado al binario `claude` de Anthropic. Otros asistentes los abres a
  mano en panes normales.

## Para personalizar más

La configuración completa de WezTerm está en `~/.config/wezterm/wezterm.lua`
después de la instalación. Es un fichero único (~750 líneas), partido en
secciones bien marcadas (§1 helpers, §2 shell choice, §3 appearance, §4 AI
Mode, §5 shell picker, §6 window state, §7 keys, §8 mouse).

> ⚠️ Si haces cambios directamente en `~/.config/wezterm/wezterm.lua`, el
> próximo bootstrap los sobrescribe. Si quieres customizar permanentemente,
> haz fork del repo y edita `dotfiles/wezterm.lua`. O comenta las líneas de
> `wezterm.lua` en `install/03-dotfiles.json` para que devcli no la copie.
