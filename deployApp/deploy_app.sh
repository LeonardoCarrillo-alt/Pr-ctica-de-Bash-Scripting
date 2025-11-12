#!/bin/bash

# Script: deploy_app_macos_advanced.sh
# Descripción: Sistema CI/CD con notificaciones Discord y control de errores
# Autor: Leonardo Carlos Carrillo Zubieta

# Configuración
REPO_URL="https://github.com/rayner-villalba-coderoad-com/clash-of-clan"
DEPLOY_DIR="./deployed_app"
LOG_FILE="./deploy.log"
BACKUP_DIR="./backup_deploys"

# Webhook de Discord - REEMPLAZA CON TU WEBHOOK REAL
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1438302085773922447/Y78b9U84TNCJ6sWXiXVErHNL8fff5jLNUklimSbsvt3mE3zDS-nDqe9AYldbwrO0H6B_"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Variables de estado
SCRIPT_START_TIME=$(date +%s)
DEPLOYMENT_STATUS="unknown"
CURRENT_COMMIT=""
ERROR_MESSAGE=""

# Función para logging consistente
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO") color=$BLUE ;;
        "SUCCESS") color=$GREEN ;;
        "WARNING") color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "DEBUG") color=$PURPLE ;;
        *) color=$NC ;;
    esac
    
    echo -e "${color}[$timestamp] [$level]${NC} $message" | tee -a "$LOG_FILE"
}

# Función para enviar notificación a Discord
send_discord_notification() {
    local status=$1
    local message=$2
    local color=$3
    
    # Si no hay webhook configurado, solo logear
    if [[ -z "$DISCORD_WEBHOOK_URL" || "$DISCORD_WEBHOOK_URL" == "https://discord.com/api/webhooks/tu-webhook-aqui" ]]; then
        log "WARNING" "Webhook de Discord no configurado. Skipping notificación."
        return 0
    fi
    
    local embed_data=$(cat << EOF
{
  "embeds": [{
    "title": "🚀 Despliegue Automático",
    "description": "$message",
    "color": $color,
    "fields": [
      {
        "name": "📦 Repositorio",
        "value": "$(basename $REPO_URL)",
        "inline": true
      },
      {
        "name": "🔧 Estado",
        "value": "$status",
        "inline": true
      },
      {
        "name": "⏰ Duración",
        "value": "$(($(date +%s) - $SCRIPT_START_TIME)) segundos",
        "inline": true
      }
    ],
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
    "footer": {
      "text": "CI/CD macOS • $(hostname)"
    }
  }]
}
EOF
)
    
    if curl -s -H "Content-Type: application/json" -X POST -d "$embed_data" "$DISCORD_WEBHOOK_URL" > /dev/null; then
        log "SUCCESS" "Notificación enviada a Discord: $status"
        return 0
    else
        log "ERROR" "Error enviando notificación a Discord"
        return 1
    fi
}

# Función para notificar inicio de despliegue
notify_deployment_start() {
    log "INFO" "Enviando notificación de inicio a Discord..."
    send_discord_notification "🟡 INICIANDO" "El proceso de despliegue ha comenzado" 16776960
}

# Función para notificar éxito
notify_deployment_success() {
    local commit_msg=$1
    local file_count=$2
    log "INFO" "Enviando notificación de éxito a Discord..."
    
    local message="Despliegue completado exitosamente\n📊 Archivos: $file_count\n📝 Commit: $commit_msg"
    send_discord_notification "🟢 EXITOSO" "$message" 65280
}

# Función para notificar error
notify_deployment_error() {
    local error_msg=$1
    local step=$2
    log "ERROR" "Enviando notificación de error a Discord..."
    
    local message="Error en paso: $step\n❌ Error: $error_msg"
    send_discord_notification "🔴 FALLIDO" "$message" 16711680
}

# Función para notificar sin cambios
notify_no_changes() {
    log "INFO" "Enviando notificación sin cambios a Discord..."
    send_discord_notification "🟡 SIN CAMBIOS" "No hay cambios nuevos en el repositorio" 16776960
}

# Función de limpieza en caso de error
cleanup_on_error() {
    local error_step=$1
    local error_msg=$2
    
    log "ERROR" "Ejecutando limpieza por error en: $error_step"
    ERROR_MESSAGE="$error_msg"
    DEPLOYMENT_STATUS="failed"
    
    # Revertir cambios si es posible
    if [[ "$error_step" == "git_update" && -d "$DEPLOY_DIR/.git" ]]; then
        log "INFO" "Intentando revertir cambios git..."
        cd "$DEPLOY_DIR"
        git reset --hard HEAD > /dev/null 2>&1
        cd - > /dev/null
    fi
    
    # Notificar error
    notify_deployment_error "$error_msg" "$error_step"
    exit 1
}

# Función para verificar comandos críticos
check_critical_command() {
    local cmd=$1
    local error_msg=$2
    
    if ! $cmd; then
        cleanup_on_error "${FUNCNAME[1]}" "$error_msg"
    fi
}

# Función para inicializar directorios
setup_directories() {
    log "INFO" "Configurando directorios de despliegue..."
    
    mkdir -p "$DEPLOY_DIR" || cleanup_on_error "setup_directories" "No se pudo crear directorio de despliegue"
    mkdir -p "$BACKUP_DIR" || cleanup_on_error "setup_directories" "No se pudo crear directorio de backup"
    mkdir -p "$(dirname "$LOG_FILE")" || cleanup_on_error "setup_directories" "No se pudo crear directorio de logs"
    
    log "SUCCESS" "Directorios configurados correctamente"
}

# Función para crear backup del despliegue actual
create_backup() {
    if [ -d "$DEPLOY_DIR" ] && [ "$(ls -A "$DEPLOY_DIR" 2>/dev/null)" ]; then
        local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
        local backup_path="$BACKUP_DIR/$backup_name"
        
        log "INFO" "Creando backup del despliegue actual..."
        
        if cp -r "$DEPLOY_DIR" "$backup_path"; then
            log "SUCCESS" "Backup creado: $backup_name"
            return 0
        else
            cleanup_on_error "create_backup" "Error creando backup del despliegue actual"
        fi
    else
        log "INFO" "No hay despliegue actual para hacer backup"
        return 0
    fi
}

# Función para clonar o actualizar el repositorio con control de errores
update_repository() {
    log "INFO" "Verificando repositorio..."
    
    if [ -d "$DEPLOY_DIR/.git" ]; then
        log "INFO" "Actualizando repositorio existente..."
        
        cd "$DEPLOY_DIR" || cleanup_on_error "update_repository" "No se pudo acceder al directorio de despliegue"
        
        # Guardar el commit actual para comparar
        local old_commit=$(git rev-parse HEAD 2>/dev/null)
        
        # Pull de los últimos cambios con control de errores
        if git fetch origin main 2>> "../$LOG_FILE"; then
            if git pull origin main 2>> "../$LOG_FILE"; then
                local new_commit=$(git rev-parse HEAD)
                CURRENT_COMMIT=$(git log --oneline -1)
                
                if [ "$old_commit" != "$new_commit" ]; then
                    log "SUCCESS" "Repositorio actualizado. Commit: ${new_commit:0:8}"
                    cd - > /dev/null
                    return 0
                else
                    log "INFO" "No hay cambios nuevos en el repositorio"
                    cd - > /dev/null
                    return 2
                fi
            else
                cleanup_on_error "update_repository" "Error al ejecutar git pull"
            fi
        else
            cleanup_on_error "update_repository" "Error al ejecutar git fetch"
        fi
    else
        log "INFO" "Clonando repositorio por primera vez..."
        
        if git clone "$REPO_URL" "$DEPLOY_DIR" 2>> "$LOG_FILE"; then
            cd "$DEPLOY_DIR" || cleanup_on_error "update_repository" "No se pudo acceder al directorio clonado"
            CURRENT_COMMIT=$(git log --oneline -1)
            cd - > /dev/null
            log "SUCCESS" "Repositorio clonado exitosamente"
            return 0
        else
            cleanup_on_error "update_repository" "Error al clonar el repositorio"
        fi
    fi
}

# Función para verificar dependencias (macOS)
check_dependencies() {
    log "INFO" "Verificando dependencias en macOS..."
    
    local missing_deps=()
    
    # Verificar Git (crítico)
    if ! command -v git &> /dev/null; then
        cleanup_on_error "check_dependencies" "Git no está instalado. Es requerido."
    fi
    
    # Verificar curl (para Discord)
    if ! command -v curl &> /dev/null; then
        log "WARNING" "Curl no está instalado. No se enviarán notificaciones a Discord."
    fi
    
    log "SUCCESS" "Dependencias críticas verificadas"
    return 0
}

# Función para simular reinicio de servicios en macOS
restart_services_macos() {
    log "INFO" "Simulando reinicio de servicios en macOS..."
    
    # Detectar tipo de aplicación y simular reinicio apropiado
    if [ -f "$DEPLOY_DIR/package.json" ]; then
        log "INFO" "📦 Aplicación Node.js detectada"
        
        # Intentar instalar dependencias
        if [ -f "$DEPLOY_DIR/package.json" ]; then
            log "INFO" "Instalando dependencias Node.js..."
            cd "$DEPLOY_DIR"
            if npm install 2>> "../$LOG_FILE"; then
                log "SUCCESS" "Dependencias Node.js instaladas"
            else
                log "WARNING" "No se pudieron instalar dependencias Node.js"
            fi
            cd - > /dev/null
        fi
        
    elif [ -f "$DEPLOY_DIR/requirements.txt" ]; then
        log "INFO" "🐍 Aplicación Python detectada"
        
        # Intentar instalar dependencias Python
        if [ -f "$DEPLOY_DIR/requirements.txt" ]; then
            log "INFO" "Instalando dependencias Python..."
            cd "$DEPLOY_DIR"
            if pip3 install -r requirements.txt 2>> "../$LOG_FILE"; then
                log "SUCCESS" "Dependencias Python instaladas"
            else
                log "WARNING" "No se pudieron instalar dependencias Python"
            fi
            cd - > /dev/null
        fi
        
    elif [ -f "$DEPLOY_DIR/index.html" ]; then
        log "INFO" "🌐 Aplicación Web estática detectada"
        log "SUCCESS" "Aplicación web lista para servir"
        
    else
        log "INFO" "📁 Proyecto genérico detectado"
    fi
    
    # Simular "reinicio" creando un archivo de timestamp
    local restart_indicator="$DEPLOY_DIR/.last_restart"
    date > "$restart_indicator" || log "WARNING" "No se pudo crear timestamp de reinicio"
    log "INFO" "Timestamp de reinicio creado: $restart_indicator"
    
    return 0
}

# Función para verificar el despliegue
verify_deployment() {
    log "INFO" "Verificando despliegue..."
    
    # Verificar que los archivos están presentes
    if [ ! -d "$DEPLOY_DIR" ] || [ -z "$(ls -A "$DEPLOY_DIR" 2>/dev/null)" ]; then
        cleanup_on_error "verify_deployment" "El directorio de despliegue está vacío o no existe"
    fi
    
    # Contar archivos desplegados
    local file_count=$(find "$DEPLOY_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    local dir_count=$(find "$DEPLOY_DIR" -type d 2>/dev/null | wc -l | tr -d ' ')
    
    log "INFO" "Estadísticas del despliegue:"
    log "INFO" "  📂 Directorios: $dir_count"
    log "INFO" "  📄 Archivos: $file_count"
    
    # Verificar que el repositorio git está intacto
    if [ ! -d "$DEPLOY_DIR/.git" ]; then
        log "WARNING" "Directorio .git no encontrado después del despliegue"
    fi
    
    log "SUCCESS" "Verificación completada exitosamente"
    return $file_count
}

# Función para mostrar resumen final
show_summary() {
    local file_count=$1
    log "INFO" "=== 📊 RESUMEN FINAL DEL DESPLIEGUE ==="
    log "INFO" "📍 Directorio: $(pwd)/$DEPLOY_DIR"
    log "INFO" "📂 Total archivos: $file_count"
    log "INFO" "🕐 Duración: $(($(date +%s) - $SCRIPT_START_TIME)) segundos"
    log "INFO" "📝 Log completo: $LOG_FILE"
    log "INFO" "🔔 Notificaciones: Discord"
    log "INFO" "========================================"
}

# Función principal con manejo completo de errores
main() {
    local file_count=0
    
    trap 'cleanup_on_error "script_interrupt" "Script interrumpido por el usuario"' INT TERM
    
    log "INFO" "🚀 INICIANDO PROCESO DE DESPLIEGUE AVANZADO"
    log "INFO" "Repositorio: $REPO_URL"
    
    # Paso 1: Notificar inicio
    notify_deployment_start
    
    # Paso 2: Verificar dependencias
    check_dependencies
    
    # Paso 3: Configurar directorios
    setup_directories
    
    # Paso 4: Crear backup
    create_backup
    
    # Paso 5: Actualizar repositorio
    update_repository
    local update_result=$?
    
    case $update_result in
        0)
            # Cambios detectados, proceder con despliegue completo
            log "INFO" "Cambios detectados, procediendo con despliegue completo..."
            ;;
        1)
            # Error (ya manejado por cleanup_on_error)
            ;;
        2)
            # Sin cambios
            log "INFO" "No hay cambios nuevos. Finalizando despliegue."
            notify_no_changes
            log "SUCCESS" "✅ DESPLIEGUE COMPLETADO (sin cambios)"
            exit 0
            ;;
    esac
    
    # Paso 6: Verificar despliegue
    verify_deployment
    file_count=$?
    
    # Paso 7: Simular reinicio de servicios
    restart_services_macos
    
    # Paso 8: Notificar éxito
    DEPLOYMENT_STATUS="success"
    notify_deployment_success "$CURRENT_COMMIT" "$file_count"
    
    # Paso 9: Mostrar resumen
    show_summary "$file_count"
    
    log "SUCCESS" "✅ DESPLIEGUE COMPLETADO EXITOSAMENTE"
}

# Ejecutar función principal
main "$@"
