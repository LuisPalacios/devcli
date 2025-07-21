-- =============================================================================
-- Configuración de Oh-My-Posh para CMD con CLINK
-- =============================================================================
-- Ubicación final: %LOCALAPPDATA%\clink\oh-my-posh.lua
-- Propósito: Integrar Oh-My-Posh con CLINK para prompts personalizados en CMD
-- Compatible con: CLINK 1.x en Windows 10/11
-- Dependencias: CLINK, Oh-My-Posh
-- =============================================================================

-- Cargar Oh-My-Posh para personalizar el prompt de CMD
-- Este script se ejecuta automáticamente cuando CLINK inicia
load(io.popen('oh-my-posh init cmd --config %USERPROFILE%\\.oh-my-posh.yaml'):read("*a"))()
