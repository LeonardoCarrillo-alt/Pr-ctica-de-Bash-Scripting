#!/bin/bash

echo "🔍 INICIANDO DIAGNÓSTICO COMPLETO"
echo "=================================="

SERVICE_NAME="nginx"
EMAIL_TO="leo.c.c.zubieta@gmail.com"
HOSTNAME=$(hostname)

# 1. Verificar estado del servicio
echo ""
echo "1. VERIFICANDO ESTADO DEL SERVICIO:"
SERVICE_INFO=$(brew services list | grep -w "$SERVICE_NAME")
echo "Información del servicio: $SERVICE_INFO"

if [ -n "$SERVICE_INFO" ]; then
    SERVICE_STATUS=$(echo "$SERVICE_INFO" | awk '{print $2}')
    echo "Estado detectado: $SERVICE_STATUS"
else
    echo "❌ Servicio no encontrado"
    exit 1
fi

# 2. Verificar msmtp
echo ""
echo "2. VERIFICANDO MSMTP:"
if command -v msmtp &> /dev/null; then
    echo "✅ msmtp instalado: $(which msmtp)"
    
    # Verificar configuración
    if [ -f ~/.msmtprc ]; then
        echo "✅ Archivo de configuración existe"
        PERMISSIONS=$(stat -f "%A" ~/.msmtprc)
        echo "   Permisos: $PERMISSIONS"
    else
        echo "❌ No existe ~/.msmtprc"
    fi
else
    echo "❌ msmtp no está instalado"
fi

# 3. Probar envío directo
echo ""
echo "3. PRUEBA DE ENVÍO DIRECTO:"
TEST_SUBJECT="TEST: Diagnóstico $(date '+%H:%M:%S')"
TEST_MESSAGE="Este es un mensaje de prueba del sistema de monitoreo.

Servidor: $HOSTNAME
Fecha: $(date)
Servicio probado: $SERVICE_NAME
Estado: $SERVICE_STATUS"

echo "Enviando correo de prueba..."
(
    echo "To: $EMAIL_TO"
    echo "From: diagnostic@$HOSTNAME"
    echo "Subject: $TEST_SUBJECT"
    echo ""
    echo "$TEST_MESSAGE"
) | msmtp -v "$EMAIL_TO" 2>&1 | grep -E "(OK|Accepted|Error|FAIL)"

# 4. Verificar si el servicio está corriendo para forzar una alerta
echo ""
echo "4. FORZAR ALERTA (si el servicio está activo):"
if [ "$SERVICE_STATUS" = "started" ]; then
    echo "El servicio está ACTIVO. Para probar alertas, puedes detenerlo temporalmente:"
    echo "brew services stop $SERVICE_NAME"
    echo "Luego ejecuta: ./check_service.sh $SERVICE_NAME"
else
    echo "✅ El servicio está INACTIVO - debería enviar alerta"
    echo "Ejecuta: ./check_service.sh $SERVICE_NAME"
fi

# 5. Verificar bandejas de correo
echo ""
echo "5. RECOMENDACIONES:"
echo "   • Revisa la bandeja de SPAM en Gmail"
echo "   • Verifica que el correo esté bien escrito: $EMAIL_TO"
echo "   • Espera 1-2 minutos (puede haber delay)"
echo "   • Revisa el log de msmtp: cat ~/.msmtp.log"

echo ""
echo "=================================="
echo "🔍 DIAGNÓSTICO COMPLETADO"
