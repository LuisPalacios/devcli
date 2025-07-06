# Linux Setup

Este repositorio contiene los scripts necesarios para configurar desde cero un sistema Linux personal (principalmente Ubuntu), usando una sola línea de bootstrap remoto.

## ¿Qué hace este proyecto?

Aquí iré documentando las acciones realizadas por los scripts de instalación:

- Instalación de paquetes base
- Configuración de entorno `.zshrc`
- Aplicación de dotfiles personalizados
- Más por venir...

## Instalación remota rápida

Puedes preparar un equipo nuevo con el comando siguiente (recomendado):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh)
```

O si prefieres `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/LuisPalacios/linux-setup/main/bootstrap.sh | bash
```

Este comando clonará el repositorio en `~/.linux-setup`, ejecutará los scripts bajo `install/` y dejará todo listo.

## 🧠 Principios del diseño idempotente

- Los scripts pueden ejecutarse múltiples veces sin causar errores.
- Las instalaciones se repiten solo si es necesario.
- Los archivos de configuración (como .zshrc) se sobreescriben con advertencia.
- Se informa claramente al usuario de cada acción, especialmente si se sobrescribe algo.
- Todo debe funcionar correctamente desde un sistema Ubuntu recién instalado.
