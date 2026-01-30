#!/bin/bash

################################################################################
# Script de Backup Automático do phpIPAM com Telegram
# Autor: Assistente Claude
################################################################################

# Configurações do Banco
DB_NAME="phpipam"
DB_USER="root"
DB_PASS="SUA_SENHA_AQUI"  # ⚠️ ALTERE AQUI
BACKUP_DIR="/root/backups/phpipam"
RETENTION_DAYS=7

# Configurações do Telegram
# Como obter: https://core.telegram.org/bots#6-botfather
TELEGRAM_BOT_TOKEN="SEU_BOT_TOKEN_AQUI"  # ⚠️ ALTERE AQUI
TELEGRAM_CHAT_ID="SEU_CHAT_ID_AQUI"      # ⚠️ ALTERE AQUI

# Criar diretório
mkdir -p "$BACKUP_DIR"

# Nome do arquivo
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="phpipam_backup_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

echo "Iniciando backup do phpIPAM..."

# 1. Backup do banco
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_PATH"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
    echo "✓ Backup concluído: $BACKUP_FILE ($BACKUP_SIZE)"
    
    # 2. Enviar mensagem para o Telegram
    MESSAGE="✅ *Backup phpIPAM Concluído*%0A%0A"
    MESSAGE+="📅 Data: $(date +'%d/%m/%Y %H:%M:%S')%0A"
    MESSAGE+="📦 Arquivo: ${BACKUP_FILE}%0A"
    MESSAGE+="💾 Tamanho: ${BACKUP_SIZE}%0A"
    MESSAGE+="🖥️ Servidor: $(hostname)"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=${MESSAGE}" \
         -d "parse_mode=Markdown" > /dev/null
    
    # 3. Enviar arquivo (se menor que 50MB)
    FILE_SIZE_MB=$(du -m "$BACKUP_PATH" | cut -f1)
    if [ "$FILE_SIZE_MB" -lt 50 ]; then
        echo "Enviando arquivo para o Telegram..."
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
             -F "chat_id=${TELEGRAM_CHAT_ID}" \
             -F "document=@${BACKUP_PATH}" \
             -F "caption=Backup phpIPAM - $(date +'%d/%m/%Y %H:%M')" > /dev/null
        echo "✓ Arquivo enviado para o Telegram"
    else
        echo "⚠ Arquivo muito grande (${FILE_SIZE_MB}MB) para enviar ao Telegram"
    fi
    
    # 4. Remover backups antigos
    find "$BACKUP_DIR" -name "phpipam_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
    
else
    echo "✗ Erro no backup!"
    # Enviar erro para o Telegram
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=❌ *ERRO no Backup phpIPAM*%0A%0AData: $(date)" \
         -d "parse_mode=Markdown" > /dev/null
    exit 1
fi

echo "Backup concluído!"
