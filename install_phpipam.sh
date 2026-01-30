#!/bin/bash

################################################################################
# Script de Instalação Automática do phpIPAM v1.7.4
# Sistema: Debian 12+
# Autor: Claude Assistant
# Data: Janeiro 2026
################################################################################

set -e  # Para o script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script deve ser executado como root!"
    exit 1
fi

# Verificar Debian 12+
if ! grep -q "Debian" /etc/os-release; then
    log_error "Este script é para Debian 12 ou superior!"
    exit 1
fi

################################################################################
# CONFIGURAÇÕES
################################################################################

# Versão do phpIPAM
PHPIPAM_VERSION="1.7.4"
PHPIPAM_URL="https://github.com/phpipam/phpipam/releases/download/v${PHPIPAM_VERSION}/phpipam-v${PHPIPAM_VERSION}.zip"

# Diretórios
WEB_DIR="/var/www/html"
PHPIPAM_DIR="${WEB_DIR}/phpipam"
BACKUP_DIR="/root/backups/phpipam_install"

# Configurações do Banco de Dados
DB_NAME="phpipam"
DB_USER="phpipam"
DB_PASS=$(openssl rand -base64 16)  # Gera senha aleatória
DB_ROOT_PASS=$(openssl rand -base64 16)  # Senha root MySQL

# Configurações do phpIPAM
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 12)  # Senha admin phpIPAM

# Informações do servidor
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_HOSTNAME=$(hostname -f)

# Arquivo de log
LOG_FILE="${BACKUP_DIR}/install_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# FUNÇÕES
################################################################################

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log_info "Diretório de backup criado: $BACKUP_DIR"
}

show_banner() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     Instalador Automático do phpIPAM v${PHPIPAM_VERSION}            ║"
    echo "║                                                            ║"
    echo "║     Sistema: Debian 12+                                    ║"
    echo "║     Modo: Instalação Completa                              ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

save_credentials() {
    local CRED_FILE="${BACKUP_DIR}/credentials.txt"
    
    cat > "$CRED_FILE" << EOF
╔════════════════════════════════════════════════════════════╗
║           CREDENCIAIS DO PHPIPAM - GUARDE COM SEGURANÇA    ║
╚════════════════════════════════════════════════════════════╝

Data da Instalação: $(date)
Servidor: ${SERVER_HOSTNAME} (${SERVER_IP})

═══════════════════════════════════════════════════════════
ACESSO WEB
═══════════════════════════════════════════════════════════
URL: http://${SERVER_IP}/phpipam
Usuário: ${ADMIN_USER}
Senha: ${ADMIN_PASS}

═══════════════════════════════════════════════════════════
BANCO DE DADOS MySQL/MariaDB
═══════════════════════════════════════════════════════════
Banco: ${DB_NAME}
Usuário: ${DB_USER}
Senha: ${DB_PASS}

Root MySQL:
Usuário: root
Senha: ${DB_ROOT_PASS}

═══════════════════════════════════════════════════════════
ARQUIVOS IMPORTANTES
═══════════════════════════════════════════════════════════
Diretório Web: ${PHPIPAM_DIR}
Config: ${PHPIPAM_DIR}/config.php
Backups: ${BACKUP_DIR}

═══════════════════════════════════════════════════════════
COMANDOS ÚTEIS
═══════════════════════════════════════════════════════════
# Acessar MySQL
mysql -u root -p${DB_ROOT_PASS}

# Backup manual
mysqldump -u ${DB_USER} -p${DB_PASS} ${DB_NAME} > backup.sql

# Verificar logs
tail -f /var/log/apache2/error.log

# Reiniciar Apache
systemctl restart apache2

EOF
    
    chmod 600 "$CRED_FILE"
    log_info "Credenciais salvas em: $CRED_FILE"
}

install_dependencies() {
    log_step "Instalando dependências do sistema..."
    
    # Atualizar repositórios
    apt update -qq
    
    # Instalar pacotes necessários
    DEBIAN_FRONTEND=noninteractive apt install -y \
        apache2 \
        mariadb-server \
        php \
        php-mysql \
        php-curl \
        php-gd \
        php-intl \
        php-pear \
        php-imap \
        php-memcache \
        php-pspell \
        php-tidy \
        php-xmlrpc \
        php-mbstring \
        php-gmp \
        php-json \
        php-xml \
        php-ldap \
        php-snmp \
        libapache2-mod-php \
        git \
        unzip \
        wget \
        curl \
        openssl \
        cron \
        > /dev/null 2>&1
    
    log_info "Dependências instaladas com sucesso"
}

configure_mysql() {
    log_step "Configurando MySQL/MariaDB..."
    
    # Iniciar MySQL
    systemctl start mariadb
    systemctl enable mariadb > /dev/null 2>&1
    
    # Configurar senha root do MySQL
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" 2>/dev/null || \
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASS}');" 2>/dev/null
    
    # Remover usuários anônimos
    mysql -u root -p"${DB_ROOT_PASS}" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null
    
    # Remover banco de teste
    mysql -u root -p"${DB_ROOT_PASS}" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null
    
    # Criar banco e usuário do phpIPAM
    mysql -u root -p"${DB_ROOT_PASS}" << MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    
    log_info "MySQL configurado com sucesso"
}

download_phpipam() {
    log_step "Baixando phpIPAM v${PHPIPAM_VERSION}..."
    
    cd /tmp
    
    # Baixar phpIPAM
    wget -q --show-progress "${PHPIPAM_URL}" -O phpipam.zip
    
    # Extrair
    unzip -q phpipam.zip -d /tmp/
    
    # Mover para diretório web
    rm -rf "${PHPIPAM_DIR}"
    mv /tmp/phpipam "${PHPIPAM_DIR}"
    
    # Limpar
    rm -f phpipam.zip
    
    log_info "phpIPAM baixado e extraído"
}

configure_phpipam() {
    log_step "Configurando phpIPAM..."
    
    cd "${PHPIPAM_DIR}"
    
    # Copiar arquivo de configuração
    cp config.dist.php config.php
    
    # Configurar banco de dados
    sed -i "s/\$db\['host'\] = 'localhost';/\$db['host'] = 'localhost';/" config.php
    sed -i "s/\$db\['user'\] = 'phpipam';/\$db['user'] = '${DB_USER}';/" config.php
    sed -i "s/\$db\['pass'\] = 'phpipamadmin';/\$db['pass'] = '${DB_PASS}';/" config.php
    sed -i "s/\$db\['name'\] = 'phpipam';/\$db['name'] = '${DB_NAME}';/" config.php
    
    # Ajustar permissões
    chown -R www-data:www-data "${PHPIPAM_DIR}"
    chmod -R 755 "${PHPIPAM_DIR}"
    
    log_info "phpIPAM configurado"
}

import_database() {
    log_step "Importando schema do banco de dados..."
    
    # Importar schema
    mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}" < "${PHPIPAM_DIR}/db/SCHEMA.sql"
    
    # Atualizar senha do admin
    ADMIN_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_DEFAULT);")
    
    mysql -u root -p"${DB_ROOT_PASS}" "${DB_NAME}" << SQL_UPDATE
UPDATE users SET password='${ADMIN_HASH}' WHERE username='Admin';
SQL_UPDATE
    
    log_info "Banco de dados importado e configurado"
}

configure_apache() {
    log_step "Configurando Apache..."
    
    # Criar VirtualHost
    cat > /etc/apache2/sites-available/phpipam.conf << APACHE_CONF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot ${PHPIPAM_DIR}
    ServerName ${SERVER_HOSTNAME}
    ServerAlias ${SERVER_IP}

    <Directory ${PHPIPAM_DIR}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/phpipam_error.log
    CustomLog \${APACHE_LOG_DIR}/phpipam_access.log combined
</VirtualHost>
APACHE_CONF
    
    # Habilitar módulos
    a2enmod rewrite > /dev/null 2>&1
    a2enmod php8.2 > /dev/null 2>&1 || a2enmod php > /dev/null 2>&1
    
    # Desabilitar site padrão
    a2dissite 000-default > /dev/null 2>&1
    
    # Habilitar phpIPAM
    a2ensite phpipam > /dev/null 2>&1
    
    # Reiniciar Apache
    systemctl restart apache2
    systemctl enable apache2 > /dev/null 2>&1
    
    log_info "Apache configurado"
}

configure_php() {
    log_step "Configurando PHP..."
    
    PHP_INI=$(php -i | grep "Loaded Configuration File" | awk '{print $5}')
    
    # Ajustar configurações PHP
    sed -i 's/;date.timezone =/date.timezone = America\/Bahia/' "$PHP_INI"
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/' "$PHP_INI"
    sed -i 's/post_max_size = 8M/post_max_size = 20M/' "$PHP_INI"
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' "$PHP_INI"
    
    systemctl restart apache2
    
    log_info "PHP configurado"
}

setup_firewall() {
    log_step "Configurando firewall (opcional)..."
    
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        log_info "Firewall configurado (portas 80 e 443)"
    else
        log_warn "UFW não instalado, pulando configuração de firewall"
    fi
}

create_backup_script() {
    log_step "Criando script de backup automático..."
    
    cat > /root/scripts/backup_phpipam.sh << 'BACKUP_SCRIPT'
#!/bin/bash
BACKUP_DIR="/root/backups/phpipam"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mysqldump -u phpipam -p'DBPASS' phpipam | gzip > "${BACKUP_DIR}/phpipam_${TIMESTAMP}.sql.gz"
find "$BACKUP_DIR" -name "phpipam_*.sql.gz" -mtime +7 -delete
BACKUP_SCRIPT
    
    sed -i "s/DBPASS/${DB_PASS}/" /root/scripts/backup_phpipam.sh
    chmod +x /root/scripts/backup_phpipam.sh
    
    # Adicionar ao crontab (backup diário às 2h)
    (crontab -l 2>/dev/null; echo "0 2 * * * /root/scripts/backup_phpipam.sh >> /var/log/backup_phpipam.log 2>&1") | crontab -
    
    log_info "Script de backup criado e agendado"
}

show_final_info() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                   ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}ACESSO AO PHPIPAM:${NC}"
    echo "  URL: http://${SERVER_IP}/phpipam"
    echo "  Usuário: ${ADMIN_USER}"
    echo "  Senha: ${ADMIN_PASS}"
    echo ""
    echo -e "${YELLOW}BANCO DE DADOS:${NC}"
    echo "  Host: localhost"
    echo "  Banco: ${DB_NAME}"
    echo "  Usuário: ${DB_USER}"
    echo "  Senha: ${DB_PASS}"
    echo ""
    echo -e "${BLUE}ARQUIVOS IMPORTANTES:${NC}"
    echo "  Credenciais: ${BACKUP_DIR}/credentials.txt"
    echo "  Log: ${LOG_FILE}"
    echo "  Config: ${PHPIPAM_DIR}/config.php"
    echo ""
    echo -e "${GREEN}PRÓXIMOS PASSOS:${NC}"
    echo "  1. Acesse http://${SERVER_IP}/phpipam"
    echo "  2. Faça login com as credenciais acima"
    echo "  3. Configure suas redes e subnets"
    echo "  4. Backup automático já está agendado (diário às 2h)"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Guarde bem as credenciais!${NC}"
    echo ""
}

################################################################################
# EXECUÇÃO PRINCIPAL
################################################################################

main() {
    # Mostrar banner
    show_banner
    
    # Criar diretório de backup e log
    create_backup_dir
    
    # Redirecionar output para log
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    log_info "Iniciando instalação do phpIPAM v${PHPIPAM_VERSION}"
    log_info "Servidor: ${SERVER_HOSTNAME} (${SERVER_IP})"
    
    # Instalação passo a passo
    install_dependencies
    configure_mysql
    download_phpipam
    configure_phpipam
    import_database
    configure_php
    configure_apache
    setup_firewall
    create_backup_script
    
    # Salvar credenciais
    save_credentials
    
    # Mostrar informações finais
    show_final_info
    
    log_info "Instalação concluída em: $(date)"
}

# Executar
main

exit 0
