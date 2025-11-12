#!/bin/bash

# Script: cleanup_logs_test.sh
# Versión para testing con archivos locales

LOG_DIR="./test_logs"
BACKUP_DIR="./backup/logs"
RETENTION_DAYS=7
SCRIPT_LOG="./cleanup_script.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SCRIPT_LOG"
}

create_directories() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_message "Directorio de backup creado: $BACKUP_DIR"
    fi
}

cleanup_logs() {
    local count=0
    local compressed_count=0
    
    log_message "=== INICIO DE LIMPIEZA ==="
    log_message "Directorio de logs: $LOG_DIR"
    log_message "Días de retención: $RETENTION_DAYS"
   
    log_message "Archivos encontrados antes de limpieza:"
    find "$LOG_DIR" -type f -name "*.log" | while read file; do
        log_message "  - $file ($(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || echo "fecha desconocida"))"
    done

    find "$LOG_DIR" -type f -name "*.log" -mtime +$RETENTION_DAYS | while read file; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local backup_name="${filename}_$(date +%Y%m%d_%H%M%S).tar.gz"
            local backup_path="$BACKUP_DIR/$backup_name"
            
            log_message "Procesando: $file"
            ((count++))
            
            if tar -czf "$backup_path" -C "$(dirname "$file")" "$filename" 2>/dev/null; then
                log_message "✓ Comprimido: $backup_path ($(du -h "$backup_path" | cut -f1))"
                ((compressed_count++))
                
                if [ -f "$backup_path" ] && [ -s "$backup_path" ]; then
                    if rm "$file"; then
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
    done
    
    log_message "Limpieza completada. Archivos procesados: $count, Comprimidos: $compressed_count"
    
    log_message "Archivos restantes después de limpieza:"
    find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | while read file; do
        log_message "  - $file"
    done || log_message "  (ningún archivo encontrado)"
    
    log_message "Archivos en backup:"
    find "$BACKUP_DIR" -type f -name "*.tar.gz" 2>/dev/null | while read file; do
        log_message "  - $file ($(du -h "$file" | cut -f1))"
    done || log_message "  (ningún archivo en backup)"
}

# Función principal
main() {
    log_message "=== SCRIPT DE LIMPIEZA DE LOGS (TEST) ==="
    
    if [ ! -d "$LOG_DIR" ]; then
        log_message "Error: Directorio $LOG_DIR no existe"
        exit 1
    fi
    
    # Crear directorios necesarios
    create_directories
    
    # Ejecutar limpieza
    cleanup_logs
    
    log_message "=== FIN DEL SCRIPT ==="
}

main "$@"
