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
apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

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
    echo 'session required                        pam_mkhomedir.so umask=0027 skel=/etc/skel' >> /etc/pam.d/common-session
fi

# Permitir fazer login sem a necessidade de acrescentar o sufixo "@dominio" ao nome de usuário:
sed -i "s/use_fully_qualified_names = True/use_fully_qualified_names = False/g" /etc/sssd/sssd.conf

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
# Mensagem de sucesso
dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO}!" 8 45