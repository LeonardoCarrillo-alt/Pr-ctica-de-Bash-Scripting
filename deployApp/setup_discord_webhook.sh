#!/bin/bash
# setup_discord_webhook.sh

echo "Configuración de Webhook de Discord"
echo "======================================"

# Solicitar webhook URL
read -p "Ingresa tu webhook URL de Discord: " webhook_url

if [[ -z "$webhook_url" ]]; then
    echo "❌ No se ingresó webhook URL"
    exit 1
fi

# Actualizar el script de despliegue
sed -i '' "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=\"$webhook_url\"|" deploy_app.sh

echo "✅ Webhook configurado correctamente"
echo "URL: $webhook_url"

# Probar el webhook
echo "Probando webhook..."
./deploy_app.sh --test-webhook
