#!/bin/bash
#--------------------------------------------------------------------------
# Script de Instalação do Zabbix com MariaDB, Grafana e Apache (httpd)
# Distribuições baseadas no RHEL 9 (RHEL, AlmaLinux, Oracle Linux, Rocky Linux, etc.)
# Sistema de log detalhado + ajuste automático do repositório EPEL.
#
# Desenvolvido por: Ivan Saboia
# Data: $(date '+%Y-%m-%d %H:%M:%S')
#--------------------------------------------------------------------------

# Cores para saída no terminal
AMARELO="\e[33m"
VERMELHO="\e[31m"
VERDE="\e[32m"
VERDE_LIMAO="\e[92m"
AZUL_CLARO="\e[96m"
ROXO_CLARO="\e[95m"
LARANJA="\e[93m"
BRANCO="\e[97m"
NC="\033[0m"

# Arquivo de log – verifique se o usuário root possui permissão para gravar
LOGFILE="/var/log/zabbix_install.log"
echo "=== Início da instalação do Zabbix: $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOGFILE"

# Funções de log
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [INFO]  $1" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOGFILE" >&2
}

# Função para executar comandos e tratar erros
run_cmd(){
    log_info "Executando: $*"
    output=$("$@" 2>&1)
    status=$?
    if [ $status -ne 0 ]; then
         log_error "Falha ao executar: $*"
         log_error "Saída: $output"
         echo -e "${VERMELHO}❌ Falha ao executar: $*${NC}"
         echo -e "${VERMELHO}Detalhes: $output${NC}"
         echo -e "${VERMELHO}Possíveis causas: problemas de rede, repositório indisponível, dependências ausentes ou permissão insuficiente.${NC}"
         exit 1
    else
         log_info "Executado com sucesso: $*"
         echo -e "${VERDE}✅ Concluído: $*${NC}"
    fi
}

# Verifica se o script está sendo executado como root
if [[ "$EUID" -ne 0 ]]; then
    log_error "Este script precisa ser executado como root!"
    echo -e "${VERMELHO}❌ Este script precisa ser executado como root!${NC}"
    exit 1
fi

# Obtém informações da distribuição
OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_MAIOR=$(echo "$OS_VERSION" | cut -d'.' -f1)

# Verifica se é uma distribuição baseada no RHEL e que a versão major seja 9
case "$OS_NAME" in
  "Red Hat Enterprise Linux" | "AlmaLinux" | "Oracle Linux" | "Rocky Linux")
    if [[ "$OS_MAIOR" != "9" ]]; then
      log_error "Versão incompatível: $OS_VERSION. Este script suporta somente distribuições baseadas no RHEL versão 9."
      echo -e "${VERMELHO}❌ Versão incompatível. Use somente distribuições baseadas no RHEL 9.${NC}"
      exit 1
    fi
    ;;
  *)
    log_error "Distribuição não suportada: $OS_NAME. Utilize RHEL 9, AlmaLinux 9, Oracle Linux 9 ou Rocky Linux 9."
    echo -e "${VERMELHO}❌ Distribuição não suportada. Use uma distribuição baseada no RHEL 9.${NC}"
    exit 1
    ;;
esac

clear

# --- Ajuste Automático do Repositório EPEL ---
log_info "Verificando e ajustando repositórios EPEL para evitar conflitos de pacotes do Zabbix..."
for repo_file in /etc/yum.repos.d/*epel*.repo; do
    if [ -f "$repo_file" ]; then  # Verifica se o arquivo é regular
        if ! grep -q "excludepkgs=zabbix\*" "$repo_file"; then
            echo "excludepkgs=zabbix*" >> "$repo_file"
            log_info "Linha 'excludepkgs=zabbix*' adicionada em: $repo_file"
        else
            log_info "Linha 'excludepkgs=zabbix*' já existe em: $repo_file"
        fi
    fi
done
log_info "Processo concluído para todos os arquivos de repositório EPEL encontrados."
# --- Fim do Ajuste EPEL ---

# Define o URL do repositório do Zabbix de acordo com a distribuição
case "$OS_NAME" in
  "Red Hat Enterprise Linux")
      REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/rhel/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm"
      ;;
  "Oracle Linux")
      REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/oracle/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm"
      ;;
  "Rocky Linux")
      REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/rocky/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm"
      ;;
  "AlmaLinux")
      REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/alma/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm"
      ;;
esac
log_info "Repositório do Zabbix definido para: $REPO_URL"

# Instala o repositório do Zabbix e atualiza o cache
run_cmd rpm -Uvh "$REPO_URL"
run_cmd dnf clean all
run_cmd dnf makecache -y

# Instala os componentes do Zabbix (servidor, frontend, scripts e agente)
run_cmd dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent

# Instala o MariaDB Server e o Apache (httpd)
run_cmd dnf install -y mariadb-server httpd

# Inicia e habilita o MariaDB
run_cmd systemctl enable --now mariadb

# Solicita a senha do usuário ROOT do MariaDB
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário ${ROXO_CLARO}ROOT${BRANCO} do MariaDB: ")" MYSQL_ROOT_PASS
echo ""
log_info "Senha para o root do MariaDB fornecida."

# Solicita a senha para o usuário do banco Zabbix
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário do banco Zabbix: ")" DB_PASS
echo ""
log_info "Senha para o usuário Zabbix capturada (não exibida)."

# Cria o banco de dados Zabbix e configura o usuário root do MariaDB
cat <<EOF > /tmp/zabbix_db.sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
EOF
run_cmd mysql -u root < /tmp/zabbix_db.sql
rm -f /tmp/zabbix_db.sql

# Cria o usuário Zabbix e concede os privilégios necessários
cat <<EOF > /tmp/zabbix_user.sql
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
EOF
run_cmd mysql -u root -p"${MYSQL_ROOT_PASS}" < /tmp/zabbix_user.sql
rm -f /tmp/zabbix_user.sql

# Importa o schema inicial do Zabbix
run_cmd bash -c "zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p'${DB_PASS}' zabbix"

# Restaura configuração de binlogs e define o idioma PT-BR no banco
run_cmd bash -c "mysql -u root -p'${MYSQL_ROOT_PASS}' -e \"SET GLOBAL log_bin_trust_function_creators = 0; USE zabbix; UPDATE users SET lang = 'pt_BR' WHERE lang != 'pt_BR';\""

# Ajusta a senha no arquivo de configuração do Zabbix Server
run_cmd sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf

# Configura o locale para PT-BR utilizando localedef
run_cmd localedef -v -c -i pt_BR -f UTF-8 pt_BR.UTF-8

# Cria o arquivo de configuração do frontend do Zabbix
cat <<EOF > /etc/zabbix/web/zabbix.conf.php
<?php
\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '${DB_PASS}';

\$DB['SCHEMA'] = '';
\$DB['ENCRYPTION'] = false;
\$DB['KEY_FILE'] = '';
\$DB['CERT_FILE'] = '';
\$DB['CA_FILE'] = '';
\$DB['VERIFY_HOST'] = false;
\$DB['CIPHER_LIST'] = '';
\$DB['FLOAT64'] = true;

\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Zabbix Server';

\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
EOF

if [ $? -eq 0 ]; then
    log_info "Arquivo /etc/zabbix/web/zabbix.conf.php criado com sucesso."
else
    log_error "Falha ao criar o arquivo /etc/zabbix/web/zabbix.conf.php."
    exit 1
fi

# Adiciona o repositório do Grafana para sistemas baseados em RPM
log_info "Adicionando repositório do Grafana..."
cat <<EOF > /etc/yum.repos.d/grafana.repo
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
EOF
run_cmd dnf makecache -y

# Instala o Grafana
run_cmd dnf install -y grafana

# Reinicia e habilita os serviços: Zabbix Server, Zabbix Agent, Apache (httpd), Grafana e MariaDB
run_cmd systemctl restart zabbix-server zabbix-agent httpd grafana-server mariadb
run_cmd systemctl enable zabbix-server zabbix-agent httpd grafana-server mariadb

# Exibe as URLs de acesso para Zabbix e Grafana
IP=$(hostname -I | awk '{print $1}')
echo -e "${AMARELO}🔗 Zabbix: ${BRANCO}http://${AZUL_CLARO}${IP}${BRANCO}/zabbix ${AMARELO}(login: ${AZUL_CLARO}Admin / zabbix${AMARELO})"
echo -e "${AMARELO}🔗 Grafana: ${BRANCO}http://${AZUL_CLARO}${IP}${BRANCO}:3000 ${AMARELO}(login: ${AZUL_CLARO}admin / admin${AMARELO})"

log_info "Instalação finalizada com sucesso."
echo -e "${VERDE}🎉 Instalação finalizada com sucesso!${NC}"
