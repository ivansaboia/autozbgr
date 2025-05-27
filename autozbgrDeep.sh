#!/bin/bash

# Configurações iniciais
LOG_FILE="/var/log/zabbix_install_$(date +%Y%m%d_%H%M%S).log"
VERSION="1.2"
AUTHOR="Ivan Saboia"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para registrar logs detalhados
log() {
    local log_type=$1
    local message=$2
    
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$log_type] $message" | tee -a "$LOG_FILE"
    
    if [ "$log_type" == "ERROR" ]; then
        echo -e "${RED}❌ ERRO: $message${NC}" >&2
    elif [ "$log_type" == "WARNING" ]; then
        echo -e "${YELLOW}⚠️ AVISO: $message${NC}" >&2
    fi
}

# Função para verificar e tratar erros
check_error() {
    local exit_code=$1
    local error_message=$2
    local critical=$3
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "$error_message"
        
        if [ "$critical" == "true" ]; then
            log "ERROR" "Falha crítica detectada. Abortando instalação."
            echo -e "\n${RED}=== DETALHES DO ERRO ==="
            tail -n 20 "$LOG_FILE"
            echo -e "=======================${NC}\n"
            exit 1
        fi
        return 1
    fi
    return 0
}

# Função para configurar automaticamente o EPEL
configure_epel() {
    local modified=0
    
    for repo_file in /etc/yum.repos.d/*epel*.repo; do
        if [ -f "$repo_file" ]; then
            log "INFO" "Verificando arquivo EPEL: $repo_file"
            
            if grep -q "^\[epel\]" "$repo_file"; then
                if ! grep -q "excludepkgs=zabbix\*" "$repo_file"; then
                    log "INFO" "Adicionando excludepkgs=zabbix* ao arquivo $repo_file"
                    sed -i '/^\[epel\]/a excludepkgs=zabbix*' "$repo_file"
                    modified=1
                else
                    log "INFO" "A diretiva excludepkgs=zabbix* já existe em $repo_file"
                fi
            else
                log "WARNING" "Seção [epel] não encontrada em $repo_file"
            fi
        fi
    done
    
    if [ $modified -eq 1 ]; then
        log "INFO" "Configuração EPEL atualizada. Limpando cache DNF..."
        dnf clean all >> "$LOG_FILE" 2>&1
    fi
}

# Cabeçalho do script
echo -e "${BLUE}"
cat << "EOF"
███████╗ █████╗ ██████╗ ██████╗ ██╗██╗  ██╗    ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ 
╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██║╚██╗██╔╝    ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
  ███╔╝ ███████║██████╔╝██████╔╝██║ ╚███╔╝     ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
 ███╔╝  ██╔══██║██╔══██╗██╔══██╗██║ ██╔██╗     ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
███████╗██║  ██║██████╔╝██████╔╝██║██╔╝ ██╗    ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
╚══════╝╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚═╝╚═╝  ╚═╝    ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
                                                                                                 
 █████╗ ██╗   ██╗████████╗ ██████╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗        
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║        
███████║██║   ██║   ██║   ██║   ██║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║        
██╔══██║██║   ██║   ██║   ██║   ██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║        
██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗   
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝   
                                                                                                 
██╗    ██╗██╗████████╗██╗  ██╗     ██████╗ ██████╗  █████╗ ███████╗ █████╗ ███╗   ██╗ █████╗    
██║    ██║██║╚══██╔══╝██║  ██║    ██╔════╝ ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗  ██║██╔══██╗   
██║ █╗ ██║██║   ██║   ███████║    ██║  ███╗██████╔╝███████║█████╗  ███████║██╔██╗ ██║███████║   
██║███╗██║██║   ██║   ██╔══██║    ██║   ██║██╔══██╗██╔══██║██╔══╝  ██╔══██║██║╚██╗██║██╔══██║   
╚███╔███╔╝██║   ██║   ██║  ██║    ╚██████╔╝██║  ██║██║  ██║██║     ██║  ██║██║ ╚████║██║  ██║   
 ╚══╝╚══╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝   
EOF
echo -e "${NC}"
echo -e "${YELLOW}ZABBIX SERVER AUTO INSTALL with Automatic EPEL Configuration"
echo -e "Versão: $VERSION"
echo -e "Autor: $AUTHOR${NC}"
echo -e "Log file: $LOG_FILE"
echo -e "Timestamp: $TIMESTAMP\n"

# Verificar se é root
if [[ "$EUID" -ne 0 ]]; then
    log "ERROR" "Este script precisa ser executado como root!"
    exit 1
fi

# Verificar distribuição
log "INFO" "Verificando sistema operacional..."
OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')

if [[ "$OS_NAME" != "Fedora Linux" ]]; then
    check_error 1 "Sistema operacional não suportado: $OS_NAME" true
fi

# Configurar automaticamente o EPEL
log "INFO" "Verificando e configurando repositórios EPEL..."
configure_epel

# Iniciar instalação
log "INFO" "Iniciando processo de instalação no $OS_NAME $OS_VERSION"

# 1. Atualizar sistema
log "INFO" "Atualizando repositórios e pacotes..."
dnf update -y >> "$LOG_FILE" 2>&1
check_error $? "Falha ao atualizar pacotes" true

# 2. Instalar repositório Zabbix
log "INFO" "Configurando repositório Zabbix..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.2/rhel/9/x86_64/zabbix-release-7.2-1.el9.noarch.rpm >> "$LOG_FILE" 2>&1
check_error $? "Falha ao adicionar repositório Zabbix" true

# 3. Instalar componentes principais
log "INFO" "Instalando pacotes Zabbix e dependências..."
dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf \
zabbix-sql-scripts zabbix-agent zabbix-get >> "$LOG_FILE" 2>&1
check_error $? "Falha ao instalar pacotes Zabbix" true

# 4. Instalar e configurar MariaDB
log "INFO" "Instalando e configurando MariaDB..."

dnf install -y mariadb-server >> "$LOG_FILE" 2>&1
check_error $? "Falha ao instalar MariaDB" true

log "INFO" "Iniciando serviço MariaDB..."
systemctl enable --now mariadb >> "$LOG_FILE" 2>&1
check_error $? "Falha ao iniciar MariaDB" true

# Configuração segura do MySQL
log "INFO" "Executando configuração segura do MySQL..."
mysql_secure_installation <<EOF >> "$LOG_FILE" 2>&1

y
y
y
y
y
y
EOF
check_error $? "Falha na configuração segura do MySQL" false

# 5. Criar banco de dados Zabbix
log "INFO" "Criando banco de dados Zabbix..."
mysql -u root <<MYSQL_SCRIPT >> "$LOG_FILE" 2>&1
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
check_error $? "Falha ao criar banco de dados Zabbix" true

# 6. Importar schema
log "INFO" "Importando schema do Zabbix..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u zabbix -pzabbix zabbix >> "$LOG_FILE" 2>&1
check_error $? "Falha ao importar schema do Zabbix" true

# 7. Configurar Zabbix Server
log "INFO" "Configurando arquivo do Zabbix Server..."
sed -i "s/^# DBPassword=/DBPassword=zabbix/" /etc/zabbix/zabbix_server.conf >> "$LOG_FILE" 2>&1
check_error $? "Falha ao configurar zabbix_server.conf" true

# 8. Configurar PHP
log "INFO" "Configurando PHP..."
sed -i 's/^;date.timezone =/date.timezone = America\/Recife/' /etc/php.ini >> "$LOG_FILE" 2>&1
sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php.ini >> "$LOG_FILE" 2>&1
check_error $? "Falha ao configurar PHP" false

# 9. Configurar Apache
log "INFO" "Configurando e iniciando Apache..."
systemctl enable --now httpd >> "$LOG_FILE" 2>&1
check_error $? "Falha ao iniciar Apache" true

# 10. Configurar firewall
log "INFO" "Configurando firewall..."
firewall-cmd --permanent --add-port=80/tcp >> "$LOG_FILE" 2>&1
firewall-cmd --permanent --add-port=10050/tcp >> "$LOG_FILE" 2>&1
firewall-cmd --permanent --add-port=10051/tcp >> "$LOG_FILE" 2>&1
firewall-cmd --reload >> "$LOG_FILE" 2>&1
check_error $? "Falha ao configurar firewall" false

# 11. Iniciar serviços Zabbix
log "INFO" "Iniciando serviços Zabbix..."
systemctl enable --now zabbix-server zabbix-agent httpd >> "$LOG_FILE" 2>&1
check_error $? "Falha ao iniciar serviços Zabbix" true

# 12. Instalar Grafana (Opcional)
log "INFO" "Instalando Grafana..."
dnf install -y grafana >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    systemctl enable --now grafana-server >> "$LOG_FILE" 2>&1
    firewall-cmd --permanent --add-port=3000/tcp >> "$LOG_FILE" 2>&1
    firewall-cmd --reload >> "$LOG_FILE" 2>&1
    log "INFO" "Grafana instalado com sucesso"
else
    log "WARNING" "Falha ao instalar Grafana (continuando sem Grafana)"
fi

# Finalização
IP=$(hostname -I | awk '{print $1}')
log "INFO" "Instalação concluída com sucesso!"
echo -e "${GREEN}"
echo -e "╔══════════════════════════════════════════╗"
echo -e "║          INSTALAÇÃO CONCLUÍDA!           ║"
echo -e "╠══════════════════════════════════════════╣"
echo -e "║ URL Zabbix: http://$IP/zabbix            ║"
echo -e "║ Usuário: Admin                           ║"
echo -e "║ Senha: zabbix                            ║"
echo -e "║                                          ║"
echo -e "║ URL Grafana: http://$IP:3000             ║"
echo -e "║ Usuário: admin                           ║"
echo -e "║ Senha: admin                             ║"
echo -e "║                                          ║"
echo -e "║ Arquivo de log: $LOG_FILE ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo -e "\n${BLUE}Script desenvolvido por: ${YELLOW}$AUTHOR${NC}\n"

exit 0
