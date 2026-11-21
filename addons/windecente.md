# Windows decente

INSTRUCCIONES - WINDOWS DECENTE SCRIPT - Contexto para desarrollo

Este proyecto implementa la automatización del apunte técnico "Un Windows decente" del blog de Luis Palacios ([https://www.luispa.com/posts/2024-08-24-win-decente/](https://www.luispa.com/posts/2024-08-24-win-decente/)).

El script "windecente.ps1" automatiza la configuración de Windows 11 para eliminar bloatware, optimizar privacidad/seguridad, y preparar el sistema para desarrollo.

El apunte "Un Windows decente" describe un proceso manual para:

1. **Debloat**: Eliminar aplicaciones y servicios preinstalados innecesarios
2. **Privacy**: Desactivar telemetría, anuncios y recopilación de datos
3. **Security**: Configurar opciones de seguridad y firewall
4. **Performance**: Optimizar configuraciones para mejor rendimiento
5. **Development**: Preparar el sistema para desarrollo de software

ANÁLISIS DE AUTOMATIZACIÓN

El script automatiza aproximadamente el 95% del proceso manual:

✅ COMPLETAMENTE AUTOMATIZADO (85%):

• Privacy & Security settings via Registry
• Eliminación de Apps preinstaladas (Edge, Xbox, Spotify, etc.)
• Configuraciones del Explorador de archivos
• Desactivar Cortana y telemetría
• Configuraciones del Firewall
• Deshabilitar servicios innecesarios
• Instalación de software esencial
• UAC configuration
• Windows Update settings

🔶 PARCIALMENTE AUTOMATIZADO (10%):

• Instalación de software (URLs pueden cambiar)
• Configuraciones de red (depende del entorno)
• Drivers específicos

❌ NO AUTOMATIZADO (5%):

• Eliminación del PIN (requiere autenticación manual)
• Cambio de nombre del directorio HOME (proceso crítico)
• Cambio a cuenta local (decisión del usuario)
• Configuración Magic Trackpad (hardware específico)
• Primera configuración de Bluetooth/Hardware

ESTRUCTURA DEL SCRIPT ACTUAL

windecente.ps1 está organizado en regiones:

1. **Configuración y variables globales**
   - Parámetros del script
   - Configuración de logging
   - Variables de paths

2. **Funciones auxiliares**
   - Write-Log: Sistema de logging con colores
   - Test-RegistryPath: Verificación de claves de registro
   - Set-RegistryValue: Configuración segura de registro
   - Remove-AppxPackageSafe: Desinstalación segura de apps
   - Install-Software: Descarga e instalación automatizada

3. **Funciones principales**
   - Initialize-Script: Inicialización y punto de restauración
   - Set-PrivacyAndSecurity: Configuraciones de privacidad
   - Remove-Bloatware: Eliminación de aplicaciones innecesarias
   - Set-FileExplorerConfig: Configuración del explorador
   - Disable-WindowsAds: Desactivación de anuncios
   - Disable-CortanaAndTelemetry: Desactivación telemetría
   - Set-TaskbarAndStartMenu: Configuración de interfaz
   - Set-NetworkAndFirewall: Configuración de red
   - Disable-UnnecessaryServices: Desactivación de servicios
   - Set-UserAccountControl: Configuración UAC
   - Install-EssentialSoftware: Instalación de software básico
   - Enable-DeveloperMode: Activación modo desarrollador
   - Enable-SMBFileSharing: Configuración compartición archivos
   - Set-WindowsUpdateSettings: Configuración actualizaciones
   - Invoke-SystemMaintenance: Mantenimiento del sistema
   - Show-Summary: Resumen final

SOFTWARE QUE INSTALA AUTOMÁTICAMENTE

• 7-Zip: Compresor de archivos esencial
• Google Chrome: Navegador principal (reemplaza Edge)
• Visual Studio Code: Editor de código
• PowerShell 7: Versión moderna multiplataforma
• Microsoft PowerToys: Utilidades avanzadas para desarrolladores

APLICACIONES QUE ELIMINA

Bloatware eliminado automáticamente:
• Microsoft Edge (disponible en Europa)
• Xbox apps (XboxApp, XboxGameOverlay, etc.)
• Bing apps (BingNews, BingWeather)
• Office apps (MicrosoftOfficeHub, OneNote)
• Entertainment (ZuneMusic, ZuneVideo, Spotify)
• Utility apps (3DViewer, Print3D, WindowsAlarms)
• Social apps (People, YourPhone, Skype)
• Feedback apps (WindowsFeedbackHub, GetHelp)

CARACTERÍSTICAS TÉCNICAS DEL SCRIPT

✅ Mejor prácticas PowerShell:
• CmdletBinding() con soporte -WhatIf
• Manejo robusto de errores con try-catch
• Sistema de logging estructurado con timestamps
• Verificación de privilegios de administrador
• Creación automática de punto de restauración
• PascalCase naming convention
• Documentación completa con help comments

✅ Seguridad:
• Verificación de prerrequisitos
• Backup automático de configuraciones
• Modo simulación con -WhatIf
• Logging detallado para auditoria
• Manejo graceful de errores

MÉTODOS DE EJECUCIÓN

Ejecución remota (método principal):

`iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/windecente.ps1")`

Ejecución local:

`.\windecente.ps1`

Modo simulación:

`.\windecente.ps1 -WhatIf`

Con información detallada:

`.\windecente.ps1 -Verbose`

CONSIDERACIONES PARA DESARROLLO FUTURO

🔧 MEJORAS POTENCIALES:
• Verificación de URLs de software antes de descarga
• Configuración modular (perfiles: básico, completo, desarrollo)
• Soporte para diferentes versiones de Windows
• Integración con Windows Package Manager (winget)
• Configuración de Windows Terminal automática
• Setup de WSL2 automático
• Configuración de Git automática
• Integración con devcli

🚨 LIMITACIONES CONOCIDAS:
• URLs de software pueden cambiar y requerir actualización
• Algunas configuraciones requieren reinicio para aplicarse
• Configuraciones de red dependen del entorno específico
• Algunos cambios de registro pueden no aplicarse inmediatamente

📋 TESTING RECOMENDADO:
• VM Windows 11 limpia para testing
• Diferentes ediciones de Windows (Home, Pro, Enterprise)
• Entornos de dominio vs workgroup
• Sistemas con diferentes configuraciones de hardware

REFERENCIAS Y DOCUMENTACIÓN

• Apunte original: [https://www.luispa.com/posts/2024-08-24-win-decente/](https://www.luispa.com/posts/2024-08-24-win-decente/)
• Blog LuisPa: [https://www.luispa.com/](https://www.luispa.com/)
• PowerShell docs: [https://docs.microsoft.com/powershell/](https://docs.microsoft.com/powershell/)
• Windows Registry docs: [https://docs.microsoft.com/windows/win32/sysinfo/registry](https://docs.microsoft.com/windows/win32/sysinfo/registry)

FILOSOFÍA DEL PROYECTO

El script sigue la filosofía del apunte original:
• "Windows en su esencia", sin florituras
• Optimización para desarrollo multiplataforma
• Eliminación de distracciones y bloatware
• Configuración consistente y reproducible
• Documentación clara y mantenible

## Step by Step

- Creo una VM con Windows 11
- Instalo VMWare Tools
- Abro una sesión de terminal como administrador y ejecuto
- Opcional:  habilitar System Restore primero en tu VM:
   Enable-ComputerRestore -Drive "C:\"
   vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10GB
- Opcional: Eliminar bloqueo
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

```console
iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/addons/windecente.ps1")
```
