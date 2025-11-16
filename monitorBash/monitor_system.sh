#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Límites modificables
CPU_LIMIT=80
RAM_LIMIT=80
DISK_LIMIT=80

# logs
ALERTS_LOG="alerts.log"
METRICS_LOG="metrics_$(date +%Y%m%d).log"

# Función para loggear métricas
log_metrics() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status=$1
    local message=$2
    
    echo "[$timestamp] $status - $message" >> "$METRICS_LOG"
}

# Función para loggear alertas
log_alert() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local component=$1
    local usage=$2
    local limit=$3
    
    local alert_message="ALERTA: $usage% de uso en $component (Límite: $limit%)"
    echo "[$timestamp] $alert_message" >> "$ALERTS_LOG"
    
    # Mostrar en terminal con color rojo
    echo -e "${RED}⚠ $alert_message${NC}"
    
    # Aquí puedes agregar el envío de correo o webhook
    send_alert "$alert_message"
}

# Función para enviar alertas (placeholder para correo/webhook)
send_alert() {
    local message=$1
    # Para enviar por correo (descomenta y configura):
    # echo "$message" | mail -s "Alerta del Sistema" tu@email.com
    
    # Para webhook (ejemplo con curl):
    # curl -X POST -H "Content-Type: application/json" -d "{\"text\":\"$message\"}" https://tu-webhook.com
    
    echo "Alerta registrada: $message"
}

# Función para obtener uso de CPU
get_cpu_usage() {
    # Usamos 'top' para obtener el uso de CPU
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    # Redondear a entero
    cpu_usage=$(printf "%.0f" "$cpu_usage")
    echo "$cpu_usage"
}

# Función para obtener uso de RAM
get_ram_usage() {
    # Usamos 'vm_stat' para calcular uso de memoria
    local total_mem=$(sysctl -n hw.memsize)
    local page_size=$(vm_stat | grep "page size" | awk '{print $8}' | sed 's/\.//')
    
    # Memoria libre
    local free_pages=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local free_mem=$((free_pages * page_size))
    
    # Memoria usada
    local used_mem=$((total_mem - free_mem))
    local ram_usage=$((used_mem * 100 / total_mem))
    
    echo "$ram_usage"
}

# Función para obtener uso de disco
get_disk_usage() {
    # Obtiene el uso del disco principal
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$disk_usage"
}

# Función para mostrar métricas con colores
show_metric() {
    local component=$1
    local usage=$2
    local limit=$3
    
    if [ "$usage" -ge "$limit" ]; then
        echo -e "${RED}✗ $component: ${usage}%${NC}"
        log_alert "$component" "$usage" "$limit"
    else
        echo -e "${GREEN}✓ $component: ${usage}%${NC}"
        log_metrics "OK" "$component: ${usage}%"
    fi
}

# Función principal de monitoreo
monitor_system() {
    echo "=== Monitoreo del Sistema ==="
    echo "Fecha: $(date)"
    echo "Límites: CPU($CPU_LIMIT%) RAM($RAM_LIMIT%) Disco($DISK_LIMIT%)"
    echo "----------------------------"
    
    # Obtener métricas
    local cpu_usage=$(get_cpu_usage)
    local ram_usage=$(get_ram_usage)
    local disk_usage=$(get_disk_usage)
    
    # Mostrar métricas
    show_metric "CPU" "$cpu_usage" "$CPU_LIMIT"
    show_metric "RAM" "$ram_usage" "$RAM_LIMIT"
    show_metric "Disco" "$disk_usage" "$DISK_LIMIT"
    
    echo "----------------------------"
    echo "Logs: $METRICS_LOG | Alertas: $ALERTS_LOG"
}

# Función para monitoreo continuo
monitor_continuous() {
    local interval=${1:-5} 
    echo "Iniciando monitoreo continuo cada ${interval}s (Ctrl+C para detener)"
    
    while true; do
        clear
        monitor_system
        sleep "$interval"
    done
}

# Función de ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -c, --continuous [segundos]  Monitoreo continuo"
    echo "  -h, --help                   Mostrar esta ayuda"
    echo "  --cpu-limit [porcentaje]     Cambiar límite de CPU (default: 80)"
    echo "  --ram-limit [porcentaje]     Cambiar límite de RAM (default: 80)"
    echo "  --disk-limit [porcentaje]    Cambiar límite de disco (default: 80)"
    echo ""
    echo "Ejemplos:"
    echo "  $0                           Monitoreo único"
    echo "  $0 -c 10                     Monitoreo cada 10 segundos"
    echo "  $0 --cpu-limit 90            Cambiar límite de CPU a 90%"
}

# Procesar argumentos
case "$1" in
    -c|--continuous)
        interval=${2:-5}
        monitor_continuous "$interval"
        ;;
    -h|--help)
        show_help
        ;;
    --cpu-limit)
        CPU_LIMIT="$2"
        monitor_system
        ;;
    --ram-limit)
        RAM_LIMIT="$2"
        monitor_system
        ;;
    --disk-limit)
        DISK_LIMIT="$2"
        monitor_system
        ;;
    *)
        monitor_system
        ;;
esac
