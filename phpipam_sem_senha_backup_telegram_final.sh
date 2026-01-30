#!/bin/bash

################################################################################
# Backup Automático phpIPAM para Telegram
# Configuração Simplificada - Salvador/BA
################################################################################

# ===== CONFIGURAÇÕES DO BANCO (SEM SENHA) =====
DB_NAME="phpipam"
DB_USER="root"
BACKUP_DIR="/root/backups/phpipam"
RETENTION_DAYS=7

# ===== CONFIGURAÇÕES DO TELEGRAM =====
# ⚠️ ALTERE ESTAS DUAS LINHAS:
TELEGRAM_BOT_TOKEN="SEU_BOT_TOKEN_AQUI"
TELEGRAM_CHAT_ID="SEU_CHAT_ID_AQUI"

# Para obter o BOT_TOKEN:
# 1. Abra o Telegram e procure por @BotFather
# 2. Envie /newbot
# 3. Escolha um nome e username
# 4. Copie o token que ele fornecer
#
# Para obter o CHAT_ID:
# 1. Procure por @userinfobot no Telegram
# 2. Envie /start
# 3. Copie o ID que aparecer

################################################################################

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Verificar configurações
if [ "$TELEGRAM_BOT_TOKEN" = "SEU_BOT_TOKEN_AQUI" ]; then
    log_error "Configure o TELEGRAM_BOT_TOKEN no script!"
    exit 1
fi

if [ "$TELEGRAM_CHAT_ID" = "SEU_CHAT_ID_AQUI" ]; then
    log_error "Configure o TELEGRAM_CHAT_ID no script!"
    exit 1
fi

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Nome do arquivo com data/hora
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="phpipam_backup_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

echo "======================================"
echo "  Backup phpIPAM → Telegram"
echo "  $(date +'%d/%m/%Y %H:%M:%S')"
echo "======================================"
echo ""

# 1. FAZER BACKUP DO BANCO (SEM SENHA)
echo "[1/3] Fazendo backup do banco de dados..."
mysqldump -u "$DB_USER" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_PATH"

if [ $? -ne 0 ]; then
    log_error "Erro no backup do banco de dados!"
    
    # Notificar erro no Telegram
    ERROR_MSG="❌ *ERRO no Backup phpIPAM*%0A%0A"
    ERROR_MSG+="📅 Data: $(date +'%d/%m/%Y %H:%M:%S')%0A"
    ERROR_MSG+="🖥️ Servidor: $(hostname)%0A"
    ERROR_MSG+="⚠️ Falha ao fazer dump do banco de dados"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=${ERROR_MSG}" \
         -d "parse_mode=Markdown" > /dev/null
    
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
FILE_SIZE_MB=$(du -m "$BACKUP_PATH" | cut -f1)
log_info "Backup criado: $BACKUP_FILE ($BACKUP_SIZE)"

# 2. ENVIAR MENSAGEM PARA TELEGRAM
echo ""
echo "[2/3] Enviando notificação para Telegram..."

MESSAGE="✅ *Backup phpIPAM Concluído*%0A%0A"
MESSAGE+="📅 Data: $(date +'%d/%m/%Y %H:%M:%S')%0A"
MESSAGE+="📦 Arquivo: \`${BACKUP_FILE}\`%0A"
MESSAGE+="💾 Tamanho: *${BACKUP_SIZE}*%0A"
MESSAGE+="🖥️ Servidor: \`$(hostname)\`%0A"
MESSAGE+="📍 Salvador/BA"

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
     -d "chat_id=${TELEGRAM_CHAT_ID}" \
     -d "text=${MESSAGE}" \
     -d "parse_mode=Markdown")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    log_info "Mensagem enviada com sucesso!"
else
    log_warn "Erro ao enviar mensagem (verifique TOKEN e CHAT_ID)"
fi

# 3. ENVIAR ARQUIVO PARA TELEGRAM
echo ""
echo "[3/3] Enviando arquivo para Telegram..."

if [ "$FILE_SIZE_MB" -lt 50 ]; then
    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
         -F "chat_id=${TELEGRAM_CHAT_ID}" \
         -F "document=@${BACKUP_PATH}" \
         -F "caption=📦 Backup phpIPAM - $(date +'%d/%m/%Y %H:%M')")
    
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        log_info "Arquivo enviado com sucesso!"
    else
        log_warn "Erro ao enviar arquivo"
    fi
else
    log_warn "Arquivo muito grande (${FILE_SIZE_MB}MB) - Telegram aceita até 50MB"
    
    # Avisar no Telegram que arquivo é muito grande
    MSG_LARGE="⚠️ Backup concluído mas arquivo é muito grande (${FILE_SIZE_MB}MB)%0A"
    MSG_LARGE+="Telegram aceita apenas até 50MB.%0A"
    MSG_LARGE+="Arquivo salvo em: \`${BACKUP_PATH}\`"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=${MSG_LARGE}" \
         -d "parse_mode=Markdown" > /dev/null
fi

# 4. LIMPAR BACKUPS ANTIGOS
echo ""
echo "Removendo backups com mais de $RETENTION_DAYS dias..."
REMOVED=$(find "$BACKUP_DIR" -name "phpipam_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)

if [ "$REMOVED" -gt 0 ]; then
    log_info "Removidos $REMOVED backup(s) antigo(s)"
else
    log_info "Nenhum backup antigo para remover"
fi

# 5. RESUMO FINAL
echo ""
echo "======================================"
echo "  ✅ Backup Concluído!"
echo "======================================"
echo "📦 Arquivo: $BACKUP_FILE"
echo "💾 Tamanho: $BACKUP_SIZE"
echo "📂 Local: $BACKUP_PATH"
echo "📱 Enviado para Telegram: Sim"
echo "======================================"
