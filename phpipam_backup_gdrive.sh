#!/bin/bash

################################################################################
# Script de Backup Automático do phpIPAM com Google Drive
# Requer: rclone configurado (apt install rclone)
################################################################################

# Configurações
DB_NAME="phpipam"
DB_USER="root"
DB_PASS="SUA_SENHA_AQUI"  # ⚠️ ALTERE AQUI
BACKUP_DIR="/root/backups/phpipam"
RETENTION_DAYS=30
GDRIVE_REMOTE="gdrive"  # Nome do remote configurado no rclone
GDRIVE_PATH="Backups/phpIPAM"  # Pasta no Google Drive

# Criar diretório
mkdir -p "$BACKUP_DIR"

# Nome do arquivo
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="phpipam_backup_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

echo "======================================"
echo "Backup phpIPAM para Google Drive"
echo "======================================"

# 1. Backup do banco
echo "[1/3] Fazendo backup do banco..."
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null | gzip > "$BACKUP_PATH"

if [ $? -ne 0 ]; then
    echo "✗ Erro no backup!"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
echo "✓ Backup concluído: $BACKUP_FILE ($BACKUP_SIZE)"

# 2. Enviar para Google Drive
echo "[2/3] Enviando para Google Drive..."

if command -v rclone &> /dev/null; then
    rclone copy "$BACKUP_PATH" "${GDRIVE_REMOTE}:${GDRIVE_PATH}" --progress
    
    if [ $? -eq 0 ]; then
        echo "✓ Upload concluído para Google Drive"
    else
        echo "✗ Erro no upload para Google Drive"
        exit 1
    fi
else
    echo "✗ rclone não está instalado!"
    echo "Instale com: apt install rclone"
    echo "Configure com: rclone config"
    exit 1
fi

# 3. Remover backups locais antigos
echo "[3/3] Limpando backups antigos..."
find "$BACKUP_DIR" -name "phpipam_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# 4. Remover backups antigos do Google Drive (opcional)
# rclone delete "${GDRIVE_REMOTE}:${GDRIVE_PATH}" --min-age ${RETENTION_DAYS}d

echo ""
echo "======================================"
echo "✓ Backup concluído com sucesso!"
echo "Local: $BACKUP_FILE"
echo "Tamanho: $BACKUP_SIZE"
echo "Google Drive: ${GDRIVE_PATH}/${BACKUP_FILE}"
echo "======================================"
