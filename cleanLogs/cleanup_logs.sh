#!/bin/bash

# Script: cleanup_logs.sh
# Descripción: Limpia logs antiguos, los comprime y los mueve a backup
# Autor: [Tu nombre]
# Fecha: $(date)

# Configuración
LOG_DIR="/var/log"
BACKUP_DIR="/backup/logs"
RETENTION_DAYS=7
SCRIPT_LOG="/var/log/cleanup_script.log"

# Función para registrar en el log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$SCRIPT_LOG"
}

# Función para crear directorios si no existen
create_directories() {
    if [ ! -d "$BACKUP_DIR" ]; then
        sudo mkdir -p "$BACKUP_DIR"
        log_message "Directorio de backup creado: $BACKUP_DIR"
    fi
    
    # Asegurar que el directorio de logs existe
    sudo mkdir -p "$(dirname "$SCRIPT_LOG")"
}

# Función principal de limpieza
cleanup_logs() {
    local count=0
    local compressed_count=0
    
    log_message "Iniciando limpieza de logs en $LOG_DIR"
    log_message "Buscando archivos con más de $RETENTION_DAYS días"
    
    # Buscar archivos con más de 7 días (excluyendo .gz y directorios)
    while IFS= read -r -d '' file; do
        if [ -f "$file" ] && [[ ! "$file" =~ \.gz$ ]]; then
            local filename=$(basename "$file")
            local backup_name="${filename}_$(date +%Y%m%d).tar.gz"
            local backup_path="$BACKUP_DIR/$backup_name"
            
            log_message "Procesando: $file"
            ((count++))
            
            # Comprimir el archivo
            if sudo tar -czf "$backup_path" -C "$(dirname "$file")" "$filename" 2>/dev/null; then
                log_message "✓ Comprimido: $backup_path"
                ((compressed_count++))
                
                # Verificar que la compresión fue exitosa
                if [ -f "$backup_path" ] && [ -s "$backup_path" ]; then
                    # Eliminar el archivo original
                    if sudo rm "$file"; then
                        log_message "✓ Eliminado original: $file"
                    else
                        log_message "✗ Error eliminando: $file"
                    fi
                else
                    log_message "✗ Error: Archivo comprimido no válido - $backup_path"
                fi
            else
                log_message "✗ Error comprimiendo: $file"
            fi
        fi
    done < <(sudo find "$LOG_DIR" -type f -mtime +$RETENTION_DAYS -not -name "*.gz" -print0 2>/dev/null)
    
    log_message "Limpieza completada. Archivos procesados: $count, Comprimidos: $compressed_count"
}

# Función alternativa para macOS (más compatible)
cleanup_logs_macos() {
    local count=0
    local compressed_count=0
    
    log_message "Iniciando limpieza de logs (método macOS) en $LOG_DIR"
    
    # Usar find de manera más compatible con macOS
    sudo find "$LOG_DIR" -type f -mtime +$RETENTION_DAYS -not -name "*.gz" 2>/dev/null | while read file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local dirname=$(dirname "$file")
            local backup_name="${filename}_$(date +%Y%m%d).tar.gz"
            local backup_path="$BACKUP_DIR/$backup_name"
            
            log_message "Procesando: $file"
            ((count++))
            
            # Comprimir el archivo
            if sudo tar -czf "$backup_path" -C "$dirname" "$filename" 2>/dev/null; then
                log_message "✓ Comprimido: $backup_path"
                ((compressed_count++))
                
                # Verificar compresión
                if [ -f "$backup_path" ] && [ -s "$backup_path" ]; then
                    # Eliminar original
                    if sudo rm "$file"; then
                        log_message "✓ Eliminado original: $file"
                    else
                        log_message "✗ Error eliminando: $file"
                    fi
                else
                    log_message "✗ Error: Archivo comprimido no válido"
                fi
            else
                log_message "✗ Error comprimiendo: $file"
            fi
        fi
    done
    
    log_message "Limpieza completada. Archivos procesados: $count, Comprimidos: $compressed_count"
}

# Verificar si el usuario tiene permisos de sudo
check_privileges() {
    if ! sudo -n true 2>/dev/null; then
        echo "Este script requiere privilegios de administrador."
        echo "Por favor, ejecuta con: sudo ./cleanup_logs.sh"
        exit 1
    fi
}

# Función principal
main() {
    log_message "=== INICIO DEL SCRIPT DE LIMPIEZA ==="
    
    # Verificar privilegios
    check_privileges
    
    # Crear directorios necesarios
    create_directories
    
    # Ejecutar limpieza (usar método alternativo para macOS)
    cleanup_logs_macos
    
    log_message "=== FIN DEL SCRIPT DE LIMPIEZA ==="
    echo "Proceso completado. Ver detalles en: $SCRIPT_LOG"
}

# Ejecutar función principal
main "$@"
