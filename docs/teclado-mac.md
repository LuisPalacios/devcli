# Atajos estilo Mac en Windows (`custom_keys`)

Si vienes del Mac, esta capa hace que un teclado de PC se use **con los mismos dedos**: Cmd+C copia, Cmd+Q cierra la app, Option+2 escribe `@`, y dentro de WezTerm tienes los atajos de fábrica de iTerm2. Funciona en todas las apps y, dentro de WezTerm, sin pisar Ctrl+C.

Es **opcional** y sólo para Windows. Cambia lo que hacen Alt y Win, así que devcli no la activa si no se lo pides.

## Activarla, desactivarla

```powershell
# Activar (se recuerda: los siguientes bootstraps la mantienen)
iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -CustomKeys on"

# Dejar de aplicarla (no borra nada; ver «Volver atrás»)
iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -CustomKeys off"

# Reescribir aunque hayas editado los ficheros (hace copia antes)
iex "& {`$(irm https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.ps1)} -CustomKeys force"
```

La elección se guarda en `~/.config/devcli/state.json`. La fase **05 · Atajos de teclado** del bootstrap hace el trabajo:

1. **PowerToys.** Si no está, lo instala con `winget install Microsoft.PowerToys --scope user` (sin permisos de administrador). Comprueba que arranca con Windows y que Keyboard Manager está encendido. No toca la opción «ejecutar como administrador»: si la tienes, se queda.
2. **La pareja de ficheros**, con copia de seguridad en `~/.config/devcli/backups/custom-keys-<fecha>/`:
   - `dotfiles/custom_keys.lua` → `~/.config/wezterm/custom_keys.lua`
   - `dotfiles/custom_keys.powertoys.json` → `%LOCALAPPDATA%\Microsoft\PowerToys\Keyboard Manager\<perfil activo>.json`
3. **Atajo del editor** de Keyboard Manager: pasa de Win+Shift+Q a **Win+Ctrl+Shift+Q** (ver «Editor de PowerToys»).
4. **Recarga** PowerToys para que lea el mapa. Si cambió el atajo del editor lo reinicia (con su tarea de autoarranque, así que conserva «ejecutar como administrador»). Si no puede, el resumen final te pide que lo reinicies tú.

## Cómo funciona

Teclado de PC, con las teclas en el sitio físico de las del Mac:

| Mac | Teclado de PC |
| --- | --- |
| Control | Ctrl |
| Option | Win |
| Cmd | Alt izquierdo (junto al espacio) |

**AltGr** y **Ctrl derecho** no se tocan: AltGr sigue escribiendo lo que lleva impreso.

Hay dos capas, y la segunda es un **contrato entre dos ficheros**:

1. **Global (todas las apps)**, en PowerToys: Cmd+letra hace Ctrl+letra, etc. No necesita WezTerm.
2. **WezTerm**, sólo con `wezterm-gui` en primer plano. PowerToys convierte cada Cmd+tecla en **F13–F24** o **Shift+F13–F24** (teclas que el teclado no tiene) y `custom_keys.lua` da una acción a cada una. Así Cmd nunca llega al programa como carácter de control (Cmd+C no interrumpe) y no choca con los CTRL+SHIFT de `wezterm.lua`. Los Cmd+letra sin función van a F24, que no hace nada, como en iTerm2.

Por eso las dos mitades viven juntas en el repo: con PowerToys y sin el `.lua`, Cmd+C en WezTerm no hace nada; con el `.lua` y sin PowerToys, nunca llega ninguna F13–F24.

## En todas las apps

| Atajo del Mac | Teclas | Qué hace en Windows |
| --- | --- | --- |
| Cmd+letra | Alt+letra | Ctrl+letra |
| Cmd+Shift+letra | Alt+Shift+letra | Ctrl+Shift+letra |
| Cmd+número, Cmd++, Cmd+-, Cmd+, | Alt+tecla | Ctrl+tecla |
| Cmd+Q | Alt+Q | Cierra la app (Alt+F4) |
| Cmd+H, Cmd+M | Alt+H, Alt+M | Minimiza (Win+↓) |
| Cmd+Shift+Z | Alt+Shift+Z | Rehacer (Ctrl+Y) |
| Cmd+Tab | Alt+Tab | Cambiar de app (de fábrica) |
| Cmd+Shift+3 | Alt+Shift+3 | Captura de pantalla completa |
| Cmd+Shift+4 | Alt+Shift+4 | Captura de una zona |
| Cmd+← / → | Alt+flecha | Inicio / fin de línea |
| Cmd+↑ / ↓ | Alt+flecha | Inicio / fin del documento |
| Cmd+Shift+flecha | Alt+Shift+flecha | Lo mismo, seleccionando |
| Option+← / → | Win+flecha | Palabra a palabra |
| Option+Shift+← / → | Win+Shift+flecha | Palabra a palabra, seleccionando |
| Option+Borrar | Win+Retroceso | Borra la palabra anterior |

## Símbolos (sólo teclado español de España)

Salen con las mismas teclas que en un Mac español. AltGr también funciona, con lo impreso en el teclado.

| Símbolo | Teclas |
| --- | --- |
| `\|` `@` `#` | Option+1, Option+2, Option+3 |
| `~` | Option+Ñ u Option+4 |
| `¬` | Option+6 |
| `€` | Option+E |
| `[` `]` | Option+tecla `` ` ``, Option+tecla `+` |
| `{` `}` | Option+tecla `´`, Option+Ç |
| `\` | Option+tecla `º` |

Los códigos de estas teclas son los de la disposición española ISO. Con otra disposición saldrían símbolos equivocados, así que el instalador **sólo los incluye si tu teclado principal es español de España** y, si no, lo dice en el resumen final.

## En WezTerm (atajos de iTerm2)

| Atajo de iTerm2 | Acción |
| --- | --- |
| Cmd+C / Cmd+V | Copiar / pegar |
| Control+C | Interrumpir lo que esté corriendo |
| Cmd+T / Cmd+N | Pestaña nueva / ventana nueva |
| Cmd+W | Cerrar panel (pregunta) y luego igualar los que quedan |
| Cmd+Q | Salir de WezTerm |
| Cmd+← / → | Pestaña anterior / siguiente |
| Cmd+1 a 9 | Ir a esa pestaña |
| Cmd+D / Cmd+Shift+D | Dividir a la derecha / hacia abajo, igualando los paneles alineados |
| Cmd+Option+flechas | Moverse entre paneles |
| Cmd+Option+tecla `` ` `` / tecla `+` | Panel anterior / siguiente (Cmd+[ y Cmd+] en el Mac español) |
| Cmd+Control+flechas | Cambiar el tamaño del panel |
| Cmd+Shift+Enter | Maximizar el panel |
| Cmd+Enter | Pantalla completa |
| Cmd+F / Cmd+G / Cmd+Shift+G | Buscar / siguiente / anterior |
| Cmd+K | Limpiar pantalla e historial |
| Cmd+A | Seleccionar todo |
| Cmd++ / Cmd+- / Cmd+0 | Tamaño de letra |
| Cmd+↑ / ↓ | Subir / bajar una línea |
| Cmd+Inicio / Fin | Principio / final del historial |
| Cmd+RePág / AvPág | Subir / bajar una página |

Siguen funcionando los atajos propios de devcli: CTRL+SHIFT+A copia todo el historial, CTRL+SHIFT+E cambia el tema, CTRL+SHIFT+T elige el shell y Shift+Enter inserta una línea en Claude Code. Ver [wezterm.md](wezterm.md).

## Limitaciones conocidas

- **Alt ya no abre los menús** de las apps.
- **Win+E y Win+1, 2, 3, 4 y 6** ya no hacen lo de Windows: escriben símbolos. **Win+← / →** pasan a ser «palabra a palabra», así que pierdes Snap (y FancyZones si lo usas con Win+flechas). Win+↑ / ↓ siguen maximizando y minimizando.
- **Win+L** siempre bloquea el equipo: Windows no deja cambiarlo.
- **Cmd+Borrar** (borrar hasta el principio de la línea) no está: PowerToys no encadena dos acciones.
- **Cmd+H / Cmd+M** con una ventana maximizada sólo la reducen; hay que pulsar dos veces.
- **Paneles iguales.** WezTerm no puede mover un divisor que tiene paneles ya divididos a los dos lados. Con 5 o más columnas creadas en cierto orden, o mezclando divisiones de columnas en varios sitios, puede quedar desigual (en algún caso extremo, un panel muy estrecho). Dividir siempre desde el último panel da columnas iguales.
- **Cmd+W** espera tu respuesta hasta 60 segundos; si tardas más, los paneles no se igualan. Cerrar con `exit` tampoco los iguala.
- Alguna vez se ha visto que los atajos dejan de convertirse y sólo lo arregla reiniciar Windows (causa desconocida).
- **Logi Options+** (teclados Logitech) puede tragarse combinaciones de Win+flecha antes de que lleguen a PowerToys: Option+→ deja el teclado «capturado» hasta pulsar Esc. Si no usas sus funciones extra, ciérralo y quítalo del arranque.
- **Apps con atajos traducidos**: Cmd+letra hace exactamente Ctrl+letra, y algunas apps cambian Ctrl+letra según el idioma. En el Bloc de notas en español, por ejemplo, Ctrl+A es Abrir y Ctrl+E Seleccionar todo, así que Cmd+A abre un fichero.
- **WezTerm en Windows no reconoce F21–F24** (las recibe como código crudo, VK 132–135). `custom_keys.lua` duplica esos atajos con `raw:132`…`raw:135`; si editas el fichero y añades atajos con F21–F24, hazlo con la función `with_raw_twins` o no funcionarán.

## Editor de PowerToys

Mientras el editor de Keyboard Manager está abierto, **no funciona ningún atajo** del mapa, y al guardar reescribe los ficheros. Si de repente dejan de funcionar todos, mira si está abierto y ciérralo.

Se abre con **Win+Ctrl+Shift+Q**. De fábrica es Win+Shift+Q, pero con Win = Option eso es Option+Shift+Q y se pulsa sin querer.

El bootstrap no aplica el mapa si el editor está abierto.

## Personalizarlo

- **WezTerm:** edita `~/.config/wezterm/custom_keys.lua`. Es la ranura de personalización de `wezterm.lua` (sección §9), que es igual en todas las máquinas: cualquier módulo que devuelva una tabla con `apply(config)` vale. Para no usar nada: `return { apply = function() end }`.
- **PowerToys:** cambia el mapa en el editor de Keyboard Manager o, para que viaje con tu fork, edita las tablas de [`install/build-custom-keys.ps1`](../install/build-custom-keys.ps1) y regenera `dotfiles/custom_keys.powertoys.json` (`-Check` comprueba que está al día).
- En los dos casos devcli **no pisa tus cambios**: recuerda lo que desplegó y, si el fichero ya no coincide, avisa y lo deja. `-CustomKeys force` lo reescribe (con copia).

## Volver atrás

Ver [desinstalar.md](desinstalar.md#atajos-estilo-mac-custom_keys).

## Por qué está hecho así

- **Opt-in y recordado.** El mapa cambia lo que hacen Alt y Win: no puede llegar a nadie sin pedirlo. Una vez activado, los bootstraps siguientes lo mantienen y traen las mejoras sin repetir el parámetro.
- **No pisar personalizaciones.** Un fichero «custom» que se sobrescribe en cada bootstrap no sirve. devcli guarda el hash de lo que desplegó y sólo escribe si el destino no existe, si sigue igual o si nunca lo desplegó él (en ese caso, con copia de seguridad).
- **Generador en PowerShell y JSON commiteado.** devcli no exige Python en Windows. El generador tiene las tablas legibles arriba y valida el mapa (sin duplicados y sin tocar AltGr: el código 18, «cualquier Alt», también coincide con AltGr). Lo que se despliega es el JSON generado, revisable en cada commit.
- **PowerToys sólo con la capa**, instalado por usuario: no hace falta ser administrador. La elevación se deja como esté: hace falta para que los atajos actúen en ventanas de administrador, pero un usuario estándar no puede activarla.
- **Nombres en pareja:** `custom_keys.lua` y `custom_keys.powertoys.json`.
- **Sólo Windows.** En macOS Cmd ya es SUPER en WezTerm; el gancho de `wezterm.lua` funciona en los tres sistemas, pero el `custom_keys.lua` de serie no hace nada fuera de Windows.
- **Símbolos según la disposición**, porque sus códigos de tecla son los del teclado español ISO.
- **F13–F24 dentro de WezTerm**, y no Ctrl+Shift, porque `wezterm.lua` ya usa CTRL+SHIFT+A, E y T.

## Prueba en el teclado real

Una tecla sólo cuenta como probada cuando la pulsas.

**En el Bloc de notas**

- [ ] Option+2 escribe `@`, y Option+3 `#`
- [ ] Option+E escribe `€`, y Option+tecla `` ` `` escribe `[`
- [ ] Cmd+A, Cmd+C y Cmd+V seleccionan, copian y pegan (con el Bloc de notas en español, Cmd+E selecciona y Cmd+A abre)
- [ ] Cmd+Z deshace y Cmd+Shift+Z rehace
- [ ] Cmd+← y Cmd+→ van al inicio y al final de la línea
- [ ] Option+← y Option+→ saltan de palabra en palabra
- [ ] Option+Borrar borra una palabra
- [ ] Cmd+Tab cambia de app y Cmd+Q cierra el Bloc de notas
- [ ] La tecla Windows sola abre el menú Inicio

**En WezTerm**

- [ ] Escribe `ping -t localhost`: Cmd+C no lo para y Control+C sí
- [ ] Selecciona texto con el ratón, Cmd+C lo copia y Cmd+V lo pega
- [ ] Option+2 escribe `@`
- [ ] Cmd+T abre pestaña, Cmd+→ cambia de pestaña y Cmd+1 vuelve a la primera
- [ ] Cmd+D divide a la derecha, Cmd+Shift+D divide hacia abajo
- [ ] Cmd+Option+flechas mueve entre paneles
- [ ] Cmd+F busca y Cmd+G va a la siguiente coincidencia
- [ ] Cmd+K limpia la pantalla
- [ ] Con 3 paneles, Cmd+W pregunta. Con «n» no cambia nada; con «y» los 2 que quedan se igualan
- [ ] Cmd+Enter pone pantalla completa
- [ ] CTRL+SHIFT+A sigue copiando todo el historial
