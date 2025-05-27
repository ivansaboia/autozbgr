#!/bin/bash

# Cores
AMARELO="\e[33m"; VERMELHO="\e[31m"; VERDE="\e[32m"; VERDE_LIMAO="\e[92m"
AZUL_CLARO="\e[96m"; ROXO_CLARO="\e[95m"; BRANCO="\e[97m"; NC="\033[0m"

status() {
  if [ $? -eq 0 ]; then echo -e "${VERDE}✅ Concluído${NC}\n"; else echo -e "${VERMELHO}❌ Falhou${NC}\n"; exit 1; fi
}

# Verifica se é root
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${VERMELHO}❌ Este script precisa ser executado como root!"; exit 1
fi

# Detecta distro e versão
OS_ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VERSION_ID=$(grep ^VERSION_ID= /etc/os-release | cut -d= -f2 | tr -d '"')

SUPPORTED_IDS=("rhel" "almalinux" "rocky" "ol" "oracle")
if [[ ! " ${SUPPORTED_IDS[*]} " =~ " ${OS_ID} " || "$OS_VERSION_ID" != 9* ]]; then
  echo -e "${VERMELHO}❌ Distribuição não suportada: ${ROXO_CLARO}${OS_ID} ${OS_VERSION_ID}${NC}"
  echo -e "${BRANCO}✅ Este script suporta: ${AMARELO}RHEL 9, AlmaLinux 9, Rocky Linux 9, Oracle Linux 9${NC}"
  exit 1
fi

# Nome do repositório correto para o Zabbix
case "$OS_ID" in
  rhel) ZABBIX_REPO="rhel" ;;
  almalinux) ZABBIX_REPO="alma" ;;
  rocky) ZABBIX_REPO="rocky" ;;
  ol|oracle) ZABBIX_REPO="oracle" ;;
esac

clear

# Banner ASCII
echo -e "${VERDE_LIMAO}"
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
ZABBIX SERVER AUTO INSTALL with Grafana - RHEL 9 Family Edition
EOF
echo -e "${NC}"

# ⚠️ AVISO OBRIGATÓRIO: EPEL
echo -e "${LARANJA}⚠️  AVISO IMPORTANTE - CONFIGURE O EPEL CORRETAMENTE ANTES DE CONTINUAR${NC}"
echo -e "${BRANCO}Se o repositório EPEL estiver instalado, você DEVE editar o arquivo:${NC}"
echo -e "${AMARELO}/etc/yum.repos.d/epel.repo${NC}"
echo -e "${BRANCO}E adicionar a seguinte linha dentro da seção [epel]:${NC}"
echo -e "${AZUL_CLARO}excludepkgs=zabbix*${NC}\n"
echo -e "${BRANCO}🔧 Verificando repositórios EPEL e aplicando excludepkgs=zabbix*...${NC}"

for repo_file in /etc/yum.repos.d/*epel*.repo; do
    if [ -f "$repo_file" ]; then
        if ! grep -q "^excludepkgs=zabbix\*" "$repo_file"; then
            echo "excludepkgs=zabbix*" >> "$repo_file"
            echo -e "${AZUL_CLARO}✅ Linha adicionada em: ${repo_file}${NC}"
        else
            echo -e "${VERDE}✔️ Já existente: ${repo_file}${NC}"
        fi
    fi
done

echo -e "${VERDE}✅ Ajuste automático do repositório EPEL concluído.${NC}\n"


# Baixa e instala repositório correto do Zabbix
echo -e "${BRANCO}📥 Instalando repositório Zabbix 7.2 para ${OS_ID^} 9...${NC}"
rpm -Uvh https://repo.zabbix.com/zabbix/7.2/release/${ZABBIX_REPO}/9/noarch/zabbix-release-latest-7.2.el9.noarch.rpm
status

dnf clean all
status

# Instala pacotes principais
echo -e "${BRANCO}📦 Instalando Zabbix, MariaDB, PHP-FPM, Nginx...${NC}"
dnf install -y zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent mariadb-server nginx php-fpm php-mysqlnd
status

# Instala Grafana
echo -e "${BRANCO}📦 Instalando Grafana...${NC}"
dnf install -y https://dl.grafana.com/oss/release/grafana-10.2.2-1.x86_64.rpm
status

echo -e "${BRANCO}🚀 Ativando serviços...${NC}"
systemctl enable --now mariadb zabbix-server zabbix-agent nginx php-fpm grafana-server
status

# Banco e permissões
echo -e "${BRANCO}🔑 Criando banco e usuário para Zabbix (senha: zabbix)...${NC}"
mysql -e "
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER zabbix@localhost IDENTIFIED BY 'zabbix';
GRANT ALL PRIVILEGES ON zabbix.* TO zabbix@localhost;
SET GLOBAL log_bin_trust_function_creators = 1;"
status

echo -e "${BRANCO}📥 Importando schema do Zabbix...${NC}"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix zabbix
mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;"
status

echo -e "${BRANCO}⚙️ Configurando zabbix_server.conf...${NC}"
sed -i 's/^# DBPassword=/DBPassword=zabbix/' /etc/zabbix/zabbix_server.conf
status

echo -e "${BRANCO}⚙️ Configurando frontend (timezone)...${NC}"
cp /etc/zabbix/nginx.conf /etc/nginx/conf.d/zabbix.conf
sed -i 's/^# php_value.*/php_value date.timezone America\/Recife/' /etc/php-fpm.d/zabbix.conf
status

systemctl restart zabbix-server zabbix-agent nginx php-fpm grafana-server
status

IP=$(hostname -I | awk '{print $1}')
echo -e "\n${VERDE}🎉 Instalação finalizada com sucesso!\n"
echo -e "${AMARELO}🔗 Zabbix Web: ${BRANCO}http://${AZUL_CLARO}${IP}/zabbix${NC}"
echo -e "${AMARELO}🔗 Grafana:    ${BRANCO}http://${AZUL_CLARO}${IP}:3000${NC}"
echo -e "${AMARELO}👤 Login Zabbix: ${AZUL_CLARO}Admin / zabbix${NC}"
echo -e "${AMARELO}👤 Login Grafana: ${AZUL_CLARO}admin / admin${NC}"
echo -e "\n${BRANCO}Script desenvolvido por: ${VERDE_LIMAO}Ivan Saboia${NC}\n"
