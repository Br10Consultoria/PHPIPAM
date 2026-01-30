#!/bin/bash

################################################################################
# Script de Backup Completo do phpIPAM
# Suporta: Email, Telegram, Google Drive
################################################################################

# ===== CONFIGURAÇÕES DO BANCO =====
DB_NAME="phpipam"
DB_USER="root"
DB_PASS="SUA_SENHA_AQUI"  # ⚠️ ALTERE AQUI
BACKUP_DIR="/root/backups/phpipam"
RETENTION_DAYS=7

# ===== HABILITAR/DESABILITAR MÉTODOS =====
ENABLE_EMAIL=false
ENABLE_TELEGRAM=true
ENABLE_GDRIVE=false

# ===== CONFIGURAÇÕES EMAIL =====
EMAIL_TO="seu_email@exemplo.com"

# ===== CONFIGURAÇÕES TELEGRAM =====
TELEGRAM_BOT_TOKEN="SEU_BOT_TOKEN"  # ⚠️ ALTERE AQUI
TELEGRAM_CHAT_ID="SEU_CHAT_ID"      # ⚠️ ALTERE AQUI

# ===== CONFIGURAÇÕES GOOGLE DRIVE =====
GDRIVE_REMOTE="gdrive"
GDRIVE_PATH="Backups/phpIPAM"

################################################################################
# NÃO EDITE ABAIXO DESTA LINHA
################################################################################

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Criar diretório
mkdir -p "$BACKUP_DIR"

# Nome do arquivo
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="phpipam_backup_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

echo "======================================"
echo "  Backup phpIPAM - $(date +'%d/%m/%Y %H:%M')"
echo "======================================"

# 1. BACKUP DO BANCO
echo ""
echo "[1/4] Fazendo backup do banco de dados..."
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_PATH"

if [ $? -ne 0 ]; then
    log_error "Erro no backup do banco de dados!"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
FILE_SIZE_MB=$(du -m "$BACKUP_PATH" | cut -f1)
log_info "Backup concluído: $BACKUP_FILE ($BACKUP_SIZE)"

# 2. ENVIAR POR EMAIL
if [ "$ENABLE_EMAIL" = true ]; then
    echo ""
    echo "[2/4] Enviando por email..."
    if command -v mail &> /dev/null; then
        echo "Backup automático do phpIPAM" | \
        mail -s "✓ Backup phpIPAM - $(date +%Y-%m-%d)" \
             -A "$BACKUP_PATH" \
             "$EMAIL_TO"
        
        [ $? -eq 0 ] && log_info "Email enviado" || log_warn "Erro ao enviar email"
    else
        log_warn "Comando 'mail' não encontrado. Instale: apt install mailutils"
    fi
else
    echo ""
    echo "[2/4] Email desabilitado (ENABLE_EMAIL=false)"
fi

# 3. ENVIAR PARA TELEGRAM
if [ "$ENABLE_TELEGRAM" = true ]; then
    echo ""
    echo "[3/4] Enviando para Telegram..."
    
    # Mensagem
    MESSAGE="✅ *Backup phpIPAM Concluído*%0A%0A"
    MESSAGE+="📅 Data: $(date +'%d/%m/%Y %H:%M:%S')%0A"
    MESSAGE+="📦 Arquivo: ${BACKUP_FILE}%0A"
    MESSAGE+="💾 Tamanho: ${BACKUP_SIZE}%0A"
    MESSAGE+="🖥️ Servidor: $(hostname)"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=${MESSAGE}" \
         -d "parse_mode=Markdown" > /dev/null
    
    # Enviar arquivo se menor que 50MB
    if [ "$FILE_SIZE_MB" -lt 50 ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
             -F "chat_id=${TELEGRAM_CHAT_ID}" \
             -F "document=@${BACKUP_PATH}" \
             -F "caption=Backup phpIPAM - $(date +'%d/%m/%Y %H:%M')" > /dev/null
        log_info "Enviado para Telegram"
    else
        log_warn "Arquivo muito grande (${FILE_SIZE_MB}MB) para Telegram"
    fi
else
    echo ""
    echo "[3/4] Telegram desabilitado (ENABLE_TELEGRAM=false)"
fi

# 4. ENVIAR PARA GOOGLE DRIVE
if [ "$ENABLE_GDRIVE" = true ]; then
    echo ""
    echo "[4/4] Enviando para Google Drive..."
    
    if command -v rclone &> /dev/null; then
        rclone copy "$BACKUP_PATH" "${GDRIVE_REMOTE}:${GDRIVE_PATH}" -q
        [ $? -eq 0 ] && log_info "Upload para Google Drive concluído" || log_error "Erro no upload"
    else
        log_warn "rclone não instalado. Instale: apt install rclone"
    fi
else
    echo ""
    echo "[4/4] Google Drive desabilitado (ENABLE_GDRIVE=false)"
fi

# 5. LIMPEZA
echo ""
echo "Removendo backups com mais de $RETENTION_DAYS dias..."
REMOVED=$(find "$BACKUP_DIR" -name "phpipam_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log_info "Removidos $REMOVED backup(s) antigo(s)"

echo ""
echo "======================================"
echo "  ✓ Backup concluído com sucesso!"
echo "======================================"
echo "Arquivo: $BACKUP_FILE"
echo "Tamanho: $BACKUP_SIZE"
echo "Caminho: $BACKUP_PATH"
echo "======================================"
