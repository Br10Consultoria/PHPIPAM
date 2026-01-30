# 🚀 Guia Rápido - Backup phpIPAM com Telegram

## 📱 Passo 1: Criar o Bot no Telegram

1. Abra o Telegram e procure por **@BotFather**
2. Envie o comando: `/newbot`
3. Escolha um nome para o bot (ex: "Backup phpIPAM")
4. Escolha um username (ex: "phpipam_backup_bot")
5. **Copie o TOKEN** que ele fornecer (algo como: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

## 🆔 Passo 2: Obter seu Chat ID

1. Procure por **@userinfobot** no Telegram
2. Envie `/start`
3. **Copie o ID** que aparecer (ex: `987654321`)

## 💻 Passo 3: Configurar no Servidor

### 3.1 Copiar o script para o servidor

```bash
# Criar diretório
mkdir -p /root/scripts/

# Criar o arquivo
nano /root/scripts/backup_phpipam_telegram.sh
```

Cole o conteúdo do script `phpipam_backup_telegram_final.sh`

### 3.2 Editar as configurações

Altere apenas estas 2 linhas:

```bash
TELEGRAM_BOT_TOKEN="SEU_TOKEN_AQUI"  # Cole o token do BotFather
TELEGRAM_CHAT_ID="SEU_ID_AQUI"       # Cole o ID do userinfobot
```

**Exemplo:**
```bash
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="987654321"
```

### 3.3 Dar permissão de execução

```bash
chmod +x /root/scripts/backup_phpipam_telegram.sh
```

## ✅ Passo 4: Testar

Execute manualmente para testar:

```bash
/root/scripts/backup_phpipam_telegram.sh
```

Você deve receber:
- ✅ Uma mensagem no Telegram com informações do backup
- 📦 O arquivo .sql.gz do backup

## ⏰ Passo 5: Agendar Backup Automático

### Opção 1: Backup Diário às 2h da manhã

```bash
crontab -e
```

Adicione esta linha:
```
0 2 * * * /root/scripts/backup_phpipam_telegram.sh >> /var/log/backup_phpipam.log 2>&1
```

### Opção 2: Backup a cada 12 horas (2h e 14h)

```
0 2,14 * * * /root/scripts/backup_phpipam_telegram.sh >> /var/log/backup_phpipam.log 2>&1
```

### Opção 3: Backup a cada 6 horas

```
0 */6 * * * /root/scripts/backup_phpipam_telegram.sh >> /var/log/backup_phpipam.log 2>&1
```

### Opção 4: Backup Semanal (Domingo às 3h)

```
0 3 * * 0 /root/scripts/backup_phpipam_telegram.sh >> /var/log/backup_phpipam.log 2>&1
```

## 📊 Verificar Logs

Para ver o histórico de backups:

```bash
# Ver últimas execuções
tail -50 /var/log/backup_phpipam.log

# Ver em tempo real (durante teste)
tail -f /var/log/backup_phpipam.log
```

## 🔍 Verificar Backups Salvos

```bash
# Listar backups
ls -lh /root/backups/phpipam/

# Ver tamanho total
du -sh /root/backups/phpipam/

# Contar quantos backups existem
ls /root/backups/phpipam/ | wc -l
```

## 🗑️ Limpeza Automática

O script já remove automaticamente backups com mais de **7 dias**.

Para alterar, edite esta linha no script:
```bash
RETENTION_DAYS=7  # Mudar para 15, 30, etc.
```

## 🛠️ Troubleshooting (Resolução de Problemas)

### Erro: "Configure o TELEGRAM_BOT_TOKEN"
- Você esqueceu de editar o TOKEN no script

### Erro: "Erro ao enviar mensagem"
- Verifique se o TOKEN e CHAT_ID estão corretos
- Teste manualmente:
```bash
curl -X POST "https://api.telegram.org/botSEU_TOKEN/sendMessage" \
     -d "chat_id=SEU_CHAT_ID" \
     -d "text=Teste"
```

### Erro: "Erro no backup do banco de dados"
- Verifique se o MySQL está rodando: `systemctl status mysql`
- Teste o comando: `mysqldump -u root phpipam | head`

### Bot não envia arquivo
- Arquivo maior que 50MB (limite do Telegram)
- Solução: Comprimir mais ou usar Google Drive para arquivos grandes

## 📱 Comandos Úteis do Telegram

Você pode criar comandos personalizados no BotFather:

1. Envie `/setcommands` para @BotFather
2. Escolha seu bot
3. Envie:
```
backup - Fazer backup agora
status - Ver status do servidor
```

Depois implemente no servidor scripts que respondem a esses comandos.

## 🎉 Pronto!

Agora você tem:
- ✅ Backup automático do phpIPAM
- ✅ Notificação no Telegram
- ✅ Arquivo enviado automaticamente
- ✅ Limpeza automática de backups antigos
- ✅ Logs organizados

---

**Dica:** Inicie uma conversa com seu bot no Telegram antes de executar o script pela primeira vez!

crontab -e
opcao 1
cola o conteudo abaixo 

0 22 * * * /root/backup_telegram.sh >> /var/log/backup_phpipam.log 2>&1
salva 
depois  executa 

crontab -l
vai aparecer  o conteudo acima 
