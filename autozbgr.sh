#!/bin/bash

# Cores
AMARELO="\e[33m"
VERMELHO="\e[31m"
VERDE="\e[32m"
VERDE_LIMAO="\e[92m"
AZUL_CLARO="\e[96m"
ROXO_CLARO="\e[95m"
LARANJA="\e[93m" 
BRANCO="\e[97m"
NC="\033[0m"

# Verifica o status (sucesso/falha)
status() {
  if [ $? -eq 0 ]; then
    echo -e "${VERDE}✅ Concluído${NC}\n"
  else
    echo -e "${VERMELHO}❌ Falhou${NC}\n"
  fi
}

# Verifica se é root
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${VERMELHO}❌ Este script precisa ser executado como root!"
  exit 1
fi

# Verifica distribuição e versão
OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_ID=$(grep '^ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_ID_LIKE=$(grep '^ID_LIKE=' /etc/os-release | cut -d '=' -f2 | tr -d '"')

# Verifica se é uma distribuição baseada em RHEL
if [[ "$OS_ID" != "rhel" && "$OS_ID" != "almalinux" && "$OS_ID" != "rocky" && "$OS_ID" != "ol" && ! "$OS_ID_LIKE" =~ "rhel" ]]; then
    echo -e "\n${VERMELHO}❌ Este script é compatível apenas com distribuições baseadas em RHEL 9:${NC}"
    echo -e "${BRANCO}✅ Distribuições suportadas: ${AMARELO}RHEL 9, AlmaLinux 9, Rocky Linux 9, Oracle Linux 9${NC}\n"
    exit 1
fi

# Verifica a versão principal
MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d '.' -f1)
if [[ "$MAJOR_VERSION" != "9" ]]; then
    echo -e "\n${VERMELHO}❌ Este script é compatível apenas com versão 9.x das distribuições RHEL e derivadas.${NC}"
    echo -e "${BRANCO}✅ Versão detectada: ${ROXO_CLARO}${OS_NAME} ${OS_VERSION}${NC}\n"
    exit 1
fi

clear

# Banner ASCII
echo -e "${VERMELHO}"
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
echo
echo

echo -e "${BRANCO}:: Iniciando instalação do ${LARANJA}MariaDB ${BRANCO}+ ${LARANJA}Zabbix ${BRANCO}+ ${LARANJA}Grafana ${BRANCO}::"
echo -e "${BRANCO}:: ${AZUL_CLARO}Aguarde${BRANCO}..."
echo
echo

# Detecta SO e versão
echo -e "${BRANCO}💻 Detectando sistema operacional: ${ROXO_CLARO}${OS_NAME} ${OS_VERSION}"
echo
echo

# Atualiza o sistema
echo -e "${BRANCO}📥 Atualizando o sistema:"
dnf update -y &>/dev/null
status

# Instala dependências necessárias
echo -e "${BRANCO}📦 Instalando dependências necessárias:"
dnf install -y wget httpd httpd-tools php php-mysqlnd php-gd php-xml php-bcmath php-mbstring php-ldap php-json &>/dev/null
status

# Habilita repositórios adicionais se necessário
if [[ "$OS_ID" == "rhel" ]]; then
    echo -e "${BRANCO}📥 Habilitando repositórios adicionais para RHEL:"
    subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms &>/dev/null
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm &>/dev/null
    status
elif [[ "$OS_ID" == "almalinux" || "$OS_ID" == "rocky" ]]; then
    echo -e "${BRANCO}📥 Habilitando repositórios adicionais para ${OS_NAME}:"
    dnf install -y epel-release &>/dev/null
    dnf config-manager --set-enabled crb &>/dev/null
    status
elif [[ "$OS_ID" == "ol" ]]; then
    echo -e "${BRANCO}📥 Habilitando repositórios adicionais para Oracle Linux:"
    dnf install -y oracle-epel-release-el9 &>/dev/null
    dnf config-manager --set-enabled ol9_codeready_builder &>/dev/null
    status
fi

# Baixa repositório Zabbix
echo -e "${BRANCO}📥 Baixando repositório do Zabbix para RHEL 9:"
rpm -Uvh https://repo.zabbix.com/zabbix/7.2/rhel/9/x86_64/zabbix-release-7.2-1.el9.noarch.rpm &>/dev/null
status

# Limpa cache e instala componentes do Zabbix
echo -e "${BRANCO}📦 Instalando pacotes Zabbix:"
dnf clean all &>/dev/null
dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-agent &>/dev/null
status

# Instala MariaDB Server
echo -e "${BRANCO}📦 Instalando MariaDB Server:"
dnf install -y mariadb-server &>/dev/null
status

# Inicia e habilita o serviço MariaDB
echo -e "${BRANCO}🔄 Iniciando serviço MariaDB:"
systemctl start mariadb &>/dev/null
systemctl enable mariadb &>/dev/null
status

# Solicita senha root do MariaDB
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário ${ROXO_CLARO}ROOT ${BRANCO}do MariaDB: ")" MYSQL_ROOT_PASS
echo
echo -e "${VERDE}✅ Senha digitada: ${AZUL_CLARO}${MYSQL_ROOT_PASS}"
echo

# Solicita senha do usuário Zabbix
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário do banco Zabbix: ")" DB_PASS
echo
echo -e "${VERDE}✅ Senha digitada: ${AZUL_CLARO}${DB_PASS}"
echo

# Configura segurança do MariaDB
echo -e "${BRANCO}🔒 Configurando segurança do MariaDB:"
mysql -u root <<EOF &>/dev/null
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF
status

# Cria base de dados
echo -e "${BRANCO}📦 Criando banco de dados Zabbix:"
mysql -u root -p"${MYSQL_ROOT_PASS}" <<EOF &>/dev/null
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF
status

# Importa schema inicial do Zabbix
echo -e "${BRANCO}🔄 Importando banco de dados do Zabbix:"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p"${DB_PASS}" zabbix &>/dev/null
status

# Restaura config de binlogs e define idioma no banco
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 0; USE zabbix; UPDATE users SET lang = 'pt_BR' WHERE lang != 'pt_BR';" &>/dev/null

# Ajusta password no config do Zabbix Server
echo -e "${BRANCO}⏳ Configurando arquivo ${ROXO_CLARO}ZABBIX.CONF${BRANCO}:"
sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf &>/dev/null
status

# Configura SELinux para permitir conexões do Zabbix
echo -e "${BRANCO}🔒 Configurando SELinux para o Zabbix:"
dnf install -y policycoreutils-python-utils &>/dev/null
setsebool -P httpd_can_connect_zabbix 1 &>/dev/null
setsebool -P httpd_can_network_connect_db 1 &>/dev/null
status

# Configura o fuso horário do PHP
echo -e "${BRANCO}⏳ Configurando fuso horário do PHP:"
sed -i 's/;date.timezone =/date.timezone = America\/Recife/' /etc/php.ini &>/dev/null
status

# Gera locale pt-br
echo -e "${BRANCO}⏳ Configurando idioma ${ROXO_CLARO}PT-BR${BRANCO}:"
dnf install -y glibc-langpack-pt &>/dev/null
localectl set-locale LANG=pt_BR.UTF-8 &>/dev/null
status

# Instala Grafana
echo -e "${BRANCO}📦 Instalando Grafana:"
cat > /etc/yum.repos.d/grafana.repo << EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y grafana &>/dev/null
status

# Configura firewall para permitir serviços
echo -e "${BRANCO}🔥 Configurando firewall:"
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=http &>/dev/null
    firewall-cmd --permanent --add-service=https &>/dev/null
    firewall-cmd --permanent --add-port=10051/tcp &>/dev/null
    firewall-cmd --permanent --add-port=3000/tcp &>/dev/null
    firewall-cmd --reload &>/dev/null
    status
else
    echo -e "${AMARELO}⚠️ Firewalld não encontrado. Verifique manualmente as regras de firewall.${NC}\n"
fi

# Reinicia e habilita serviços
echo -e "${BRANCO}🔁 Ativando e iniciando serviços:"
systemctl restart zabbix-server zabbix-agent httpd grafana-server &>/dev/null
systemctl enable zabbix-server zabbix-agent httpd grafana-server &>/dev/null
status

# Mensagem final
echo -e "${VERDE}🎉 Instalação finalizada com sucesso!"
echo
echo

# URLs de acessos
IP=$(hostname -I | awk '{print $1}')
echo -e "${AMARELO}🔗 Zabbix: ${BRANCO}http://${AZUL_CLARO}${IP}${BRANCO}/zabbix${BRANCO} (${AMARELO}login: ${AZUL_CLARO}Admin / zabbix${BRANCO})"
echo -e "${AMARELO}🔗 Grafana: ${BRANCO}http://${AZUL_CLARO}${IP}${BRANCO}:3000${BRANCO} (${AMARELO}login: ${AZUL_CLARO}admin / admin${BRANCO})"
echo
echo -e "${BRANCO}Script desenvolvido por: ${VERDE_LIMAO}Ivan Saboia${NC}"
echo
