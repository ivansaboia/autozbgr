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

# Nome do arquivo de log
LOG_FILE="/var/log/zabbix_install_$(date +%Y%m%d_%H%M%S).log"

# Função para registrar e executar comandos com tolerância a falhas
# Uso: exec_step "Descrição da etapa" "comando a ser executado" [true para parar em caso de falha crítica]
exec_step() {
  local desc="$1"
  local cmd="$2"
  local halt_on_fail="$3" # true para parar o script em caso de falha crítica
  local result

  echo -e "${AZUL_CLARO}:: ${desc}...${NC}" | tee -a "$LOG_FILE"
  echo -e "${BRANCO}Comando: ${cmd}${NC}" | tee -a "$LOG_FILE"

  # Executa o comando e redireciona stdout e stderr para o log
  # Usamos 'eval' para garantir que comandos complexos ou com pipes funcionem
  eval "$cmd" >> "$LOG_FILE" 2>&1
  result=$?

  if [ $result -eq 0 ]; then
    echo -e "${VERDE}✅ Concluído: ${desc}${NC}\n" | tee -a "$LOG_FILE"
    return 0 # Sucesso
  else
    echo -e "${VERMELHO}❌ Falhou: ${desc}${NC}\n" | tee -a "$LOG_FILE"
    echo -e "${VERMELHO}Detalhes do erro (verifique o log '$LOG_FILE' para mais informações):${NC}" | tee -a "$LOG_FILE"
    # Tenta mostrar as últimas linhas do log que contêm o erro
    tail -n 20 "$LOG_FILE" | grep -E "error|failed|denied|No such|unknown|refused|permission|exist" --color=always | tee -a "$LOG_FILE"

    if [ "$halt_on_fail" = true ]; then
      echo -e "${VERMELHO}Erro crítico: A instalação não pode continuar. Abortando script.${NC}" | tee -a "$LOG_FILE"
      exit 1
    else
      echo -e "${AMARELO}⚠️ Aviso: Esta etapa falhou, mas o script tentará continuar.${NC}" | tee -a "$LOG_FILE"
      return 1 # Falha não crítica, continuar
    fi
  fi
}

# Início do script
clear
echo -e "${BRANCO}Iniciando a execução do script. Log será salvo em: ${ROXO_CLARO}$LOG_FILE${NC}\n"
touch "$LOG_FILE"
echo "--- Início do Log de Instalação do Zabbix ---" >> "$LOG_FILE"
echo "Data: $(date)" >> "$LOG_FILE"
echo "Usuário: $USER" >> "$LOG_FILE"
echo "ID do Processo: $$" >> "$LOG_FILE"
echo "---------------------------------------------" >> "$LOG_FILE"

# Verifica se é root
exec_step "Verificando privilégios de root" "[[ \"\$EUID\" -ne 0 ]]" true
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${VERMELHO}❌ Este script precisa ser executado como root!${NC}" | tee -a "$LOG_FILE"
  exit 1
fi

# Detecta distribuição e versão
echo -e "${BRANCO}Detectando sistema operacional...${NC}" | tee -a "$LOG_FILE"
OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')
OS_MAIOR=$(echo "$OS_VERSION" | cut -d '.' -f1)
OS_ID=$(grep '^ID=' /etc/os-release | cut -d '=' -f2 | tr -d '"')

echo -e "${BRANCO}💻 Sistema Operacional Detectado: ${ROXO_CLARO}${OS_NAME} ${OS_VERSION}${NC}\n" | tee -a "$LOG_FILE"

# Verifica se é uma distribuição RHEL 9-based
if [[ "$OS_NAME" != "Red Hat Enterprise Linux" && "$OS_NAME" != "AlmaLinux" && "$OS_NAME" != "Oracle Linux" && "$OS_NAME" != "Rocky Linux" ]]; then
    echo -e "\n${VERMELHO}❌ Distribuição não suportada: ${ROXO_CLARO}${OS_NAME} ${OS_VERSION}${NC}" | tee -a "$LOG_FILE"
    echo -e "\n${BRANCO}✅ Este script é suportado apenas para: ${AMARELO}RHEL 9, AlmaLinux 9, Oracle Linux 9, Rocky Linux 9${NC}\n" | tee -a "$LOG_FILE"
    exit 1
fi

# Verifica se é versão 9
if (( OS_MAIOR < 9 )); then
    echo -e "\n${VERMELHO}❌ Versão ${OS_MAIOR} do ${OS_NAME} não suportada. Por favor, use a versão ${AMARELO}9 ${VERMELHO}ou superior.${NC}\n" | tee -a "$LOG_FILE"
    exit 1
fi

# Banner ASCII
echo -e "${ROXO_CLARO}"
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
echo -e "${NC}"
echo -e "${BRANCO}:: Iniciando instalação do ${LARANJA}MariaDB ${BRANCO}+ ${LARANJA}Zabbix ${BRANJA}7.2 ${BRANCO}+ ${LARANJA}Grafana ${BRANCO}::"
echo -e "${BRANCO}:: Este script irá instalar e configurar Zabbix Server 7.2 com MariaDB, Apache e Grafana."
echo -e "${BRANCO}:: ${AZUL_CLARO}Aguarde${BRANCO}...\n"

# --- ETAPA CRÍTICA: EXCLUSÃO DE PACOTES ZABBIX DO EPEL (AUTOMATIZADO) ---
echo -e "${AMARELO}===================================================================================================${NC}" | tee -a "$LOG_FILE"
echo -e "${AMARELO}!!! ATENÇÃO: CONFIGURAÇÃO AUTOMÁTICA DO REPOSITÓRIO EPEL PARA EVITAR CONFLITOS !!!${NC}" | tee -a "$LOG_FILE"
echo -e "${AMARELO}===================================================================================================${NC}\n" | tee -a "$LOG_FILE"
echo -e "${BRANCO}O script irá agora configurar automaticamente os arquivos de repositório EPEL para excluir pacotes Zabbix." | tee -a "$LOG_FILE"
echo -e "${BRANCO}Isso é crucial para evitar conflitos de versões e garantir a instalação correta do Zabbix 7.2.${NC}\n" | tee -a "$LOG_FILE"

exec_step "Configurando exclusão de pacotes Zabbix no(s) repositório(s) EPEL" \
"for repo_file in /etc/yum.repos.d/*epel*.repo; do
    if [ -f \"\$repo_file\" ]; then
        if ! grep -q \"excludepkgs=zabbix\\*\" \"\$repo_file\"; then
            echo \"excludepkgs=zabbix*\" | sudo tee -a \"\$repo_file\" >> \"\$LOG_FILE\" 2>&1
            echo \"Linha 'excludepkgs=zabbix*' adicionada a: \$repo_file\" | tee -a \"\$LOG_FILE\"
        else
            echo \"Linha 'excludepkgs=zabbix*' já existe em: \$repo_file\" | tee -a \"\$LOG_FILE\"
        fi
    fi
done" false # Não para o script se a configuração falhar em algum arquivo, mas o log registrará.

# Limpa o cache DNF após a edição do repositório
exec_step "Limpando o cache DNF após configuração dos repositórios" "dnf clean all" true

# Seleciona o link do repositório Zabbix baseado no ID da distribuição
case "$OS_ID" in
  "rhel") ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/rhel/9/noarch/zabbix-release-7.2-1.el9.noarch.rpm" ;;
  "almalinux") ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/alma/9/noarch/zabbix-release-7.2-1.el9.noarch.rpm" ;;
  "oraclelinux") ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/oracle/9/noarch/zabbix-release-7.2-1.el9.noarch.rpm" ;;
  "rocky") ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.2/release/rocky/9/noarch/zabbix-release-7.2-1.el9.noarch.rpm" ;;
  *) echo -e "${VERMELHO}❌ Erro: Não foi possível determinar o link do repositório Zabbix para ${OS_NAME}. Verifique a compatibilidade.${NC}" | tee -a "$LOG_FILE"; exit 1 ;;
esac

# --- Verificação e instalação/reinstalação do repositório Zabbix ---
if rpm -q zabbix-release &>/dev/null; then
    echo -e "${AMARELO}⚠️ Repositório Zabbix já parece instalado. Verificando versão...${NC}" | tee -a "$LOG_FILE"
    # Se já está instalado, verifica se é a versão correta (7.2)
    if ! rpm -q zabbix-release | grep -q "7.2"; then
        echo -e "${VERMELHO}❌ Versão do repositório Zabbix instalada (${AMARELO}$(rpm -q zabbix-release 2>/dev/null)${VERMELHO}) não é 7.2. Removendo para instalar a correta.${NC}" | tee -a "$LOG_FILE"
        exec_step "Removendo repositório Zabbix obsoleto/incorreto" "dnf -y remove zabbix-release" false
        exec_step "Adicionando repositório oficial do Zabbix 7.2 para ${OS_NAME} ${OS_VERSION}" \
        "sudo rpm -Uvh $ZABBIX_REPO_URL" true
    else
        echo -e "${VERDE}✅ Repositório Zabbix 7.2 já instalado e correto. Prosseguindo.${NC}" | tee -a "$LOG_FILE"
    fi
else
    exec_step "Adicionando repositório oficial do Zabbix 7.2 para ${OS_NAME} ${OS_VERSION}" \
    "sudo rpm -Uvh $ZABBIX_REPO_URL" true
fi

# Lista de pacotes Zabbix para instalação/verificação
ZABBIX_PACKAGES="zabbix-server-mysql zabbix-web-apache-mysql zabbix-sql-scripts zabbix-selinux-policy zabbix-agent"

# --- Verificação e instalação/reinstalação de pacotes Zabbix ---
echo -e "${BRANCO}Verificando pacotes Zabbix...${NC}" | tee -a "$LOG_FILE"
TO_INSTALL_ZABBIX=""
TO_REMOVE_ZABBIX=""

for package in $ZABBIX_PACKAGES; do
    if rpm -q "$package" &>/dev/null; then
        echo -e "${AMARELO}Pacote ${package} já está instalado. Verificando se é do repositório Zabbix.${NC}" | tee -a "$LOG_FILE"
        # Verifica se o pacote instalado é do repo zabbix (não do EPEL, por exemplo)
        if ! rpm -qi "$package" | grep -q "From repo.*zabbix"; then
             echo -e "${VERMELHO}❌ Pacote ${package} parece ser de um repositório incorreto. Será removido e reinstalado.${NC}" | tee -a "$LOG_FILE"
             TO_REMOVE_ZABBIX+=" $package"
             TO_INSTALL_ZABBIX+=" $package" # Marcar para reinstalar do repo correto
        else
            echo -e "${VERDE}✅ Pacote ${package} já está instalado e do repositório Zabbix. Não será reinstalado.${NC}" | tee -a "$LOG_FILE"
        fi
    else
        echo -e "${BRANCO}Pacote ${package} não está instalado. Será adicionado para instalação.${NC}" | tee -a "$LOG_FILE"
        TO_INSTALL_ZABBIX+=" $package"
    fi
done

if [ -n "$TO_REMOVE_ZABBIX" ]; then
    exec_step "Removendo pacotes Zabbix de repositórios incorretos" "dnf -y remove $TO_REMOVE_ZABBIX" false
fi

if [ -n "$TO_INSTALL_ZABBIX" ]; then
    exec_step "Instalando/reinstalando pacotes Zabbix necessários: $TO_INSTALL_ZABBIX" \
    "dnf -y install $TO_INSTALL_ZABBIX" true
else
    echo -e "${VERDE}Todos os pacotes Zabbix necessários já estão instalados e corretos. Prosseguindo.${NC}" | tee -a "$LOG_FILE"
fi

# Instala MariaDB Server (dnf)
exec_step "Instalando MariaDB Server (se não estiver instalado)" \
"dnf -y install mariadb-server" true

# Habilita e inicia MariaDB
exec_step "Ativando e iniciando serviço MariaDB" \
"systemctl enable --now mariadb" true

# Solicita senha root do MariaDB
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário ${ROXO_CLARO}ROOT ${BRANCO}do MariaDB: ")" MYSQL_ROOT_PASS
echo
echo -e "${VERDE}✅ Senha do ROOT MariaDB digitada: ${AZUL_CLARO}${MYSQL_ROOT_PASS}${NC}"
echo

# Configura senha root do MariaDB (se não configurada)
exec_step "Configurando senha ROOT do MariaDB (pode exigir interação manual ou falhar se autenticação por socket for usada)" \
"mysql -u root -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}'; FLUSH PRIVILEGES;\"" false

# Solicita senha do usuário Zabbix
read -sp "$(echo -e "${BRANCO}🔑 Digite uma senha para o usuário do banco Zabbix: ")" DB_PASS
echo
echo -e "${VERDE}✅ Senha do usuário Zabbix digitada: ${AZUL_CLARO}${DB_PASS}${NC}"
echo

# Cria base de dados e usuário Zabbix no MariaDB
exec_step "Criando banco de dados 'zabbix' e usuário 'zabbix' no MariaDB" \
"mysql -u root -p\"${MYSQL_ROOT_PASS}\" <<EOF
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF" true

# Importa schema inicial do Zabbix
exec_step "Importando esquema inicial do banco de dados Zabbix (isso pode levar alguns minutos)" \
"zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p\"${DB_PASS}\" zabbix" true

# Restaura config de binlogs e define idioma no banco
exec_step "Restaurando configurações do MariaDB e definindo idioma pt_BR no Zabbix" \
"mysql -u root -p\"${MYSQL_ROOT_PASS}\" -e \"SET GLOBAL log_bin_trust_function_creators = 0; USE zabbix; UPDATE users SET lang = 'pt_BR' WHERE lang != 'pt_BR';\"" false

# Ajusta password no config do Zabbix Server
exec_step "Configurando senha do banco de dados no arquivo zabbix_server.conf" \
"sed -i \"s/# DBPassword=/DBPassword=${DB_PASS}/\" /etc/zabbix/zabbix_server.conf" true

# Configura PHP para o frontend (RHEL 9 usa php-fpm.d/zabbix.conf)
exec_step "Configurando fuso horário no PHP-FPM para Zabbix Frontend (America/Fortaleza)" \
"sed -i 's/^;php_value\[date\.timezone\].*/php_value\[date\.timezone\] = America\/Fortaleza/' /etc/php-fpm.d/zabbix.conf" true

# Cria arquivo de configuração do frontend para pular setup inicial
exec_step "Criando arquivo de configuração inicial para o frontend do Zabbix (zabbix.conf.php)" \
"cat <<EOF > /etc/zabbix/web/zabbix.conf.php
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
EOF" true

# Instala Grafana
exec_step "Instalando Grafana (se não estiver instalado)" \
"dnf -y install grafana" true

# Adiciona o repositório Grafana.com e importa GPG key (caso não tenha sido feito por 'dnf install grafana' já)
exec_step "Adicionando repositório Grafana.com e chave GPG (se necessário)" \
"wget -q -O /etc/yum.repos.d/grafana.repo https://rpm.grafana.com/release/grafana.repo && rpm --import https://rpm.grafana.com/gpg.key" false

# Configura Firewalld e adiciona regras
exec_step "Configurando Firewalld (habilitando e adicionando regras para HTTP, HTTPS, Zabbix e Grafana)" \
"systemctl enable --now firewalld && firewall-cmd --add-service=http --permanent && firewall-cmd --add-service=https --permanent && firewall-cmd --add-port=10050/tcp --permanent && firewall-cmd --add-port=10051/tcp --permanent && firewall-cmd --add-port=3000/tcp --permanent && firewall-cmd --reload" true

# Reinicia e habilita serviços
exec_step "Ativando e iniciando todos os serviços (Zabbix Server, Agent, Apache, Grafana, MariaDB, PHP-FPM)" \
"systemctl restart zabbix-server zabbix-agent httpd grafana-server php-fpm mariadb && systemctl enable zabbix-server zabbix-agent httpd grafana-server php-fpm mariadb" true

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

echo "--- Fim do Log de Instalação do Zabbix ---" >> "$LOG_FILE"
