# Linux Setup

Este repositorio contiene los scripts necesarios para configurar desde cero un sistema Linux personal (principalmente Ubuntu), usando una sola línea de bootstrap remoto.

## ¿Qué hace este proyecto?

Aquí iré documentando las acciones realizadas por los scripts de instalación:

- Instalación de paquetes base
- Configuración de entorno `.zshrc`
- Aplicación de dotfiles personalizados
- Más por venir...

## Instalación remota rápida

Puedes preparar un equipo nuevo con:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

O si prefieres `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh | bash
```

Este comando clonará el repositorio en `~/.linux-setup`, ejecutará los scripts bajo `install/` y dejará todo listo.
