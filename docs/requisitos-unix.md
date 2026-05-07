# Requisitos — Linux, macOS y WSL2

## Linux

> ⚠️ Sólo soporta **Debian / Ubuntu** (usa `apt` para instalar). Si usas Arch,
> Fedora, openSUSE u otra distro, el bootstrap fallará en el segundo paso.

Necesitas:

- `curl` o `wget` instalado.
- Tu usuario debe tener acceso a `sudo` **sin contraseña**:

  ```bash
  sudo apt install sudo
  sudo usermod -aG sudo <tu-usuario>
  echo "<tu-usuario> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-<tu-usuario>
  ```

- `zsh` se instala automáticamente y se cambia tu shell por defecto. Si nunca
  has usado zsh, está bien — la configuración que devcli copia (`.zshrc`) la
  hace muy parecida a bash en lo cotidiano. Si quieres entender cómo funciona
  zsh por dentro, [aquí tienes un apunte técnico](https://luispa.com/posts/2024-04-23-zsh/).

> También puedes ejecutar el bootstrap **como root** directamente. Útil para
> entornos headless / Docker / cloud-init. devcli detecta el caso y se salta
> los chequeos de sudo.

## macOS

Necesitas:

- **Homebrew** instalado. Si no lo tienes:

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

  Más detalles en [brew.sh](https://brew.sh).

- `zsh` ya viene por defecto en macOS desde Catalina, no tienes que hacer nada.

- macOS pasa el bootstrap **sin necesitar `sudo` sin contraseña** porque casi
  todo se instala vía Homebrew (que no requiere sudo).

> El bootstrap funciona con el bash 3.2 que trae macOS por defecto. No
> necesitas instalar `bash` desde brew.

## WSL2

Funciona igual que Linux nativo (es Ubuntu por debajo en el caso típico). El
bootstrap detecta automáticamente que está dentro de WSL2 (lee
`$WSL_DISTRO_NAME` o `/proc/version`).

Una sola diferencia: en WSL2 **no** se reconfigura el locale del sistema
(`locale-gen`, `update-locale`). Es algo de Linux nativo solamente. Si
necesitas un locale específico en WSL2, configúralo a mano vía
`/etc/default/locale` o exporta `LANG` en tu `.zshrc`.

## Si algo falla

- Errores de red al descargar paquetes: revisa que tienes salida HTTPS y que
  no estás detrás de un proxy corporativo que rompa `apt-get update`.
- Errores de permisos: vuelve a leer la sección de `sudo` arriba — la mayoría
  de fallos en Linux vienen de esto.
- Para ver el detalle de qué falló, mira `~/.devcli/install.log`. Cada fase
  escribe ahí toda la salida bruta de `apt`, `brew`, `curl`, etc.
- Si quieres ver todo en pantalla mientras se ejecuta, añade `--verbose`:

  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/devcli/main/bootstrap.sh) --verbose
  ```

Más en [troubleshooting.md](troubleshooting.md).
