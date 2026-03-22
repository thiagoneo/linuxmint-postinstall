#!/usr/bin/env bash

set -e

##################################################################
# Script para automatizar o processo de ingressar um computador  #
# rodando Linux (Debian, Ubuntu e derivados) no Active Directory #
# Autor: Thiago de S. Ferreira                                   #
# E-mail: sousathiago@protonmail.com                             #
##################################################################

# Verificar se o usuário é o root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."
   exit 1
fi

# Instalar o pacote dialog, se não for encontrado no sistema
if ! command -v dialog &> /dev/null; then
    sudo apt -y install dialog
fi

# Instalar o pacote lsb-release, necessário para obter nome do SO
if ! command -v lsb_release &> /dev/null; then
    sudo apt -y install lsb-release
fi

#--------------------------- DEFINIR NOVO HOSTNAME ----------------------------#
ALTERA_HOSTNAME=true

for arg in "$@"; do
    case "$arg" in
        --no-change-hostname)
        ALTERA_HOSTNAME=false
        ;;
    esac
done

if $ALTERA_HOSTNAME; then
    OLD_HOSTNAME=`hostname`
    NEW_HOSTNAME=$(\
        dialog --no-cancel --title "Definir hostname"\
            --inputbox "Insira o nome do computador:" 8 40\
        3>&1 1>&2 2>&3 3>&- \
    )
    echo ""
    sed -i "s/${OLD_HOSTNAME}/${NEW_HOSTNAME}/g" /etc/hosts
    hostnamectl set-hostname ${NEW_HOSTNAME}
    echo "Novo HOSTNAME definido como ${NEW_HOSTNAME}"
else
    echo "Alteração de hostname ignorada (--no-change-hostname)"
fi

#----------------------- CONFIGURAÇÃO NETWORK-MANAGER ------------------------#
# Necessário para evitar problemas de resolução de nomes ao ingressar no AD

# Desinstalar systemd-resolved, se estiver presente, para evitar conflitos com o NetworkManager
if dpkg -l | grep -q systemd-resolved; then
    apt -y purge systemd-resolved
    apt-mark hold systemd-resolved
fi
cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.bkp
cat <<EOF > "/etc/NetworkManager/NetworkManager.conf"
[main]
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=false

[device]
wifi.scan-rand-mac-address=no
EOF

# Remover resolv.conf existente e reiniciar o NetworkManager
rm /etc/resolv.conf
systemctl restart NetworkManager.service

#------------------ SOLICITAR INFORMACOES DE DNS E DOMINIO -------------------#
dialog --erase-on-exit --title "Aviso" --msgbox 'A seguir, insira o servidor DNS para resolver o domínio. Normalmente, o IP do servidor DNS é o mesmo do Controlador de Domínio, a menos que sejam servidores distintos.' 8 60

DNS1=$(\
        dialog --no-cancel --title "DNS primário"\
            --inputbox "Insira o servidor DNS primário:" 8 40\
        3>&1 1>&2 2>&3 3>&- \
    )

DNS2=$(\
        dialog --no-cancel --title "DNS secundário"\
            --inputbox "Insira o servidor DNS secundário (opcional):" 8 40\
        3>&1 1>&2 2>&3 3>&- \
    )

DOMINIO=$(\
    dialog --no-cancel --title "Ingresso em domínio Active Directory"\
        --inputbox "Insira o domínio:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)
DOMINIO=$(echo "$DOMINIO" | tr '[:upper:]' '[:lower:]')

OS_NAME=$(lsb_release -d -s)

USUARIO=$(\
    dialog --no-cancel --title "Ingresso em domínio Active Directory"\
        --inputbox "Insira um nome de usuário com permissão para ingressar em ${DOMINIO}:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

SENHA=$(\
    dialog --no-cancel --title "Ingresso em domínio Active Directory"\
        --insecure --clear --passwordbox "Senha para $USUARIO:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

PASTA_COMPARTILHADA=$(\
    dialog --no-cancel --title "Configuração de pasta compartilhada"\
        --inputbox "Insira o caminho da pasta compartilhada no AD (ex: arquivos):" 8 60\
    3>&1 1>&2 2>&3 3>&- \
)   

#-------------------------------- ALTERAR DNS --------------------------------#
IFS=$'\n'

for CONN_NAME in $(nmcli --fields NAME --terse connection show)
do
    sudo nmcli connection modify "$CONN_NAME" ipv4.ignore-auto-dns true
    sudo nmcli connection modify "$CONN_NAME" ipv4.dns "${DNS1} ${DNS2}"
    sudo nmcli connection modify "$CONN_NAME" ipv4.dns-search "$DOMINIO"
done

for CONN_NAME in $(nmcli --fields NAME --terse connection show --active)
do
    sudo nmcli connection down "$CONN_NAME"
    sudo nmcli connection up "$CONN_NAME"
done

#------------------------------ INGRESSAR NO AD ------------------------------#
apt -y update
# Pré-configura o reino do Kerberos para evitar o diálogo interativo
echo "krb5-config krb5-config/default_realm string ${DOMINIO^^}" | debconf-set-selections
# Instalar os pacotes necessários para ingressar no domínio e autenticação
apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit adsys krb5-user smbclient

### Comando original
echo $SENHA | realm join --os-name $OS_NAME -U ${USUARIO} ${DOMINIO} >> /dev/null

STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    dialog --no-cancel --colors --msgbox "\Z1ERRO: Não foi possível ingressar no domínio." 8 45
    exit 1
fi

#------------------------------ PÓS-CONFIGURAÇÃO -----------------------------#
# Habilitar criacao automatica de pastas de usuarios ao fazer logon
if ! grep -q "session.*required.*pam_mkhomedir.so.*umask.*" /etc/pam.d/common-session; then
    echo 'session required                        pam_mkhomedir.so umask=0077 skel=/etc/skel' >> /etc/pam.d/common-session
fi

# Permitir fazer login sem a necessidade de acrescentar o sufixo "@dominio" ao nome de usuário:
# 1. Se a linha já existir (com qualquer valor), substitui pelo domínio correto
if grep -q "default_domain_suffix" /etc/sssd/sssd.conf; then
    sed -i "s/^default_domain_suffix =.*/default_domain_suffix = ${DOMINIO}/" /etc/sssd/sssd.conf
    echo "Sufixo de domínio atualizado para ${DOMINIO}."
else
# 2. Se não existir, insere logo abaixo de [sssd]
    sed -i "/^\[sssd\]/a default_domain_suffix = ${DOMINIO}" /etc/sssd/sssd.conf
    echo "Sufixo de domínio configurado."
fi

# 3. Garante que o use_fully_qualified_names esteja como True para o ADSys
sed -i "s/use_fully_qualified_names =.*/use_fully_qualified_names = True/g" /etc/sssd/sssd.conf

systemctl restart sssd

# Configuração do systemd-timesyncd
# Necessário para sincronizar relógio com o AD
DC_LIST=$(host -t SRV "_ldap._tcp.dc._msdcs.${DOMINIO}" 2>/dev/null | \
        grep "SRV record" | \
        awk '{print $NF}' | \
        sed 's/\.$//' | \
        sort -u | \
        tr "\n" " ")
cp /etc/systemd/timesyncd.conf  /etc/systemd/timesyncd.conf.bkp
cat <<EOF > "/etc/systemd/timesyncd.conf"
[Time]
NTP=${DC_LIST}
FallbackNTP=ntp.ubuntu.com
#RootDistanceMaxSec=5
#PollIntervalMinSec=32
#PollIntervalMaxSec=2048
EOF
# Reiniciar serviço
systemctl restart systemd-timesyncd.service
timedatectl set-ntp false
timedatectl set-ntp true

cat <<EOF > "/usr/local/bin/sync_ad_files"
#!/bin/bash

#------------------------- CONFIGURAÇÕES -------------------------#
DOMINIO="${DOMINIO}"
SHARE="sysvol"
PASTA_REMOTA="${PASTA_COMPARTILHADA}"
MOUNTPOINT="/var/lib/samba/ad_temp_mount" 
LOCAL_DIR="/usr/share/ad_files/\${PASTA_REMOTA}"

# 1. Busca dinâmica de DCs ativos
DC_LIST=\$(host -t SRV _ldap._tcp.dc._msdcs.\${DOMINIO} | awk '{print \$NF}' | sed 's/\.\$//' | sort -u)

# 2. Garante que as pastas existem
mkdir -p "\$LOCAL_DIR"
mkdir -p "\$MOUNTPOINT"

# 3. Renova o ticket Kerberos da conta de máquina
kinit -k \$(hostname)\\$

# 4. Tenta montar e sincronizar percorrendo a lista de DCs
SUCESSO=false

for DC in \$DC_LIST; do
    echo "Tentando conectar com: \$DC"
    
    # Tenta montar o SYSVOL via Kerberos (somente leitura - ro)
    # Se a montagem falhar, o script pula para o próximo DC
    if mount -t cifs //\${DC}/\${SHARE} \${MOUNTPOINT} -o sec=krb5,multiuser,ro,vers=3.0 2>/dev/null; then
        echo "Montagem bem-sucedida via \$DC. Iniciando rsync..."
        
        # O rsync com --delete remove localmente apenas o que foi apagado no servidor
        # A barra no final de SOURCE/ garante que sincronize o CONTEÚDO da pasta
        SOURCE_PATH="\${MOUNTPOINT}/\${DOMINIO}/\${PASTA_REMOTA}/"
        
        if [ -d "\$SOURCE_PATH" ]; then
            rsync -av --delete "\$SOURCE_PATH" "\$LOCAL_DIR/"
            SUCESSO=true
        else
            echo "ERRO: Pasta \${PASTA_REMOTA} não encontrada no SYSVOL de \$DC"
        fi
        
        # Desmonta imediatamente após o uso
        umount -l \${MOUNTPOINT}
        
        [ "\$SUCESSO" = true ] && break
    fi
done

if [ "\$SUCESSO" = false ]; then
    echo "AVISO: Não foi possível sincronizar com nenhum DC. Mantendo arquivos locais atuais."
    exit 1
fi

# 5. Ajusta permissões finais
chmod -R 644 "\$LOCAL_DIR"
find "\$LOCAL_DIR" -type d -exec chmod 755 {} +
echo "Sincronização concluída com sucesso."
EOF

# Tornar o script executável
chmod +x /usr/local/bin/sync_ad_files

cat <<EOF > "/etc/systemd/system/sync_ad_files.service"
[Unit]
Description=Sincronizacao de arquivos do AD Sysvol
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/local/bin/sync_ad_files

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > "/etc/systemd/system/sync_ad_files.timer"
[Unit]
Description=Agenda a sincronizacao de arquivos a cada 15 minutos

[Timer]
OnBootSec=20s
OnCalendar=*:0,15,30,45
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now sync_ad_files.timer

rm -rf /var/cache/adsys/*
adsysctl policy update --all -v

# Executar a sincronização inicial imediatamente
sync_ad_files

# Mensagem de sucesso
dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO}!" 8 45