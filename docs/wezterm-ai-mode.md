# AI Mode — cuatro Claudes en una ventana

AI Mode es un atajo de WezTerm que abre una ventana con **cuatro paneles
pre-configurados**: tres con sesiones de [Claude Code](https://claude.ai/code)
listas para usar, y un panel de shell para ejecutar comandos. Los tres
modelos diferentes te permiten paralelizar o comparar respuestas sin abrir
terminales nuevas.

Sólo está disponible si tienes WezTerm instalado (perfiles `dev` o `full`)
**y** el binario `claude` accesible en tu PATH (no se instala con devcli — es
un componente aparte de Anthropic).

## Cómo abrirlo

| Atajo | Plataforma |
|-------|------------|
| `CTRL+ALT+N` | Windows |
| `CTRL+SUPER+N` | macOS, Linux |

Lo lanzas desde cualquier pane de WezTerm. Se abre una **ventana nueva**
(no una pestaña) con la siguiente disposición:

```
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

## Cómo se hereda el directorio de trabajo

El directorio de trabajo (cwd) de los cuatro paneles se hereda del pane desde
el que pulsaste el atajo. Si estás en `~/proyectos/cliente-X/backend`, los
cuatro Claudes y el shell arrancan ahí. Útil: el contexto de archivos
relevantes está disponible automáticamente para cada Claude.

## Workflow típico

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

## Navegar entre paneles

Atajos estándar de WezTerm:

| Atajo | Qué hace |
|-------|----------|
| `CTRL+SHIFT+↑↓←→` | Mover el foco al pane vecino en esa dirección |
| `CTRL+SHIFT+ALT+↑↓←→` | Redimensionar el pane actual |
| `CTRL+SHIFT+Z` | Maximizar el pane actual (toggle) |
| `CTRL+SHIFT+Q` | Cerrar el pane actual |

Si maximizas un pane (`CTRL+SHIFT+Z`) puedes trabajar a pantalla completa
con un Claude y volver al layout de 4 con el mismo atajo.

## Cuándo se cierra

La ventana de AI Mode no es persistente. Se cierra cuando cierras todos los
paneles que la componen. Si **un pane** de Claude muere (porque escribes
`/exit`, o porque el proceso de Claude crashea), ese pane se cierra pero los
demás siguen vivos. Si todos cierran, la ventana se va con ellos.

> Si quieres "salir" del AI Mode pero no perder lo que tenías, simplemente
> minimiza la ventana o cambia a otra. El contexto de cada Claude vive
> dentro del pane mientras éste esté abierto.

## Si el atajo no hace nada

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

## Limitaciones conocidas

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
