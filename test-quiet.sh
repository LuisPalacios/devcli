#!/usr/bin/env bash
#
# Script de prueba para verificar el nuevo sistema de logging silencioso

set -euo pipefail

echo "🧪 Probando sistema de logging silencioso..."

# Simular ejecución de bootstrap
echo "[bootstrap] Preparando entorno en linux..."
echo "[bootstrap] Ejecutando scripts de instalación:"
echo "  • 01-system.sh - Configuración base del sistema"
echo "  • 02-packages.sh - Herramientas de productividad"
echo "  • 03-dotfiles.sh - Configuración de shell y dotfiles"
echo "  • 04-localtools.sh - Herramientas locales"

# Simular ejecución de scripts (silenciosa)
echo "[01-system] ✅ Configuración base completada (5 paquetes verificados)"
echo "[02-packages] ✅ Herramientas de productividad instaladas (7 paquetes verificados)"
echo "[03-dotfiles] ✅ Dotfiles instalados (2 archivos)"
echo "[04-localtools] ✅ Herramientas locales instaladas (3 herramientas)"

echo "[bootstrap] ✅ Instalación completada exitosamente"

echo ""
echo "🎯 Resultado esperado:"
echo "• Solo mensajes importantes"
echo "• Sin verbosidad innecesaria"
echo "• Errores y warnings visibles"
echo "• Resúmenes finales informativos" 