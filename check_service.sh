#!/bin/bash

# Verificar que se haya proporcionado un parámetro
if [ $# -eq 0 ]; then
    echo "Error: Debes proporcionar el nombre del servicio como parámetro."
    echo "Uso: ./check_service.sh <nombre-del-servicio>"
    echo "Ejemplo: ./check_service.sh nginx"
    exit 1
fi

SERVICE_NAME="$1"
LOG_FILE="service_status.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Verificar si brew services está disponible
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew no está instalado o no está en el PATH"
    exit 1
fi

# Verificar el estado del servicio usando brew services list
SERVICE_INFO=$(brew services list | grep -w "$SERVICE_NAME")

if [ -z "$SERVICE_INFO" ]; then
    echo "Error: El servicio '$SERVICE_NAME' no está gestionado por brew services"
    echo "Servicios disponibles:"
    brew services list
    exit 1
fi

# Extraer el estado - la segunda columna en brew services list
SERVICE_STATUS=$(echo "$SERVICE_INFO" | awk '{print $2}')

# Debug: mostrar información completa del servicio
echo "Debug - Información completa del servicio:"
echo "$SERVICE_INFO"
echo "Debug - Estado extraído: '$SERVICE_STATUS'"

# Mostrar resultado y guardar en el log
if [ "$SERVICE_STATUS" = "started" ]; then
    echo "El servicio $SERVICE_NAME está ACTIVO!!!"
    echo "$TIMESTAMP - $SERVICE_NAME - ACTIVO" >> "$LOG_FILE"
else
    echo "ALERTA!!!: El servicio $SERVICE_NAME está INACTIVO (Estado: $SERVICE_STATUS)"
    echo "$TIMESTAMP - $SERVICE_NAME - INACTIVO ($SERVICE_STATUS)" >> "$LOG_FILE"
fi  
