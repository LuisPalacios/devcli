#Requires -Version 7.0
#
# DespiertaPantalla.ps1 — despierta el monitor dormido de este Windows con un
# micro-movimiento del ratón. Útil antes de entrar por RustDesk: ejecútalo
# por SSH en el equipo remoto y la imagen deja de llegar en negro.
#
# Uso: DespiertaPantalla (PowerShell 7) · pwsh -NoProfile -File ~/bin/DespiertaPantalla.ps1 (bash)

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public class Mouse {
    [DllImport("user32.dll")]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);
}
'@

[Mouse]::mouse_event(0x0001, 1, 1, 0, 0)   # MOUSEEVENTF_MOVE, 1 píxel
Write-Host "[+] Señal enviada. El monitor debería estar encendido." -ForegroundColor Green
