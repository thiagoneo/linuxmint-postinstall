#!/usr/bin/env bash

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

altera_dns() {
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
    
    IFS=$'\n'
    
    for CONN_NAME in $(nmcli --fields NAME --terse connection show)
    do
        sudo nmcli connection modify  "$CONN_NAME" ipv4.ignore-auto-dns true
        sudo nmcli connection modify  "$CONN_NAME" ipv4.dns "${DNS1} ${DNS2}"
        sudo nmcli connection down "$CONN_NAME"
        sudo nmcli connection up "$CONN_NAME"
    done
}

dialog_info() {
    dialog --erase-on-exit --title "Aviso" --msgbox 'A seguir, insira o servidor DNS para resolver o domínio. Normalmente, o IP do servidor DNS é o mesmo do Controlador de Domínio, a menos que sejam servidores distintos.' 8 60
}

dialog_info
altera_dns

OS_NAME=$(lsb_release -d -s)

DOMINIO=$(\
    dialog --no-cancel --title "Ingresso em domínio Active Directory"\
        --inputbox "Insira o domínio:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

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

apt -y update
apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

### Comando original
echo $SENHA | realm join --os-name $OS_NAME -U ${USUARIO} ${DOMINIO} 

STATUS=$?

# Habilitar criacao automatica de pastas de usuarios ao fazer logon
if ! grep -q "session.*required.*pam_mkhomedir.so.*umask.*" /etc/pam.d/common-session; then
    echo 'session required                        pam_mkhomedir.so umask=0027 skel=/etc/skel' >> /etc/pam.d/common-session
fi

# Permitir fazer login sem a necessidade de acrescentar o sufixo "@dominio" ao nome de usuário:
sed -i "s/use_fully_qualified_names = True/use_fully_qualified_names = False/g" /etc/sssd/sssd.conf

systemctl restart sssd

if [[ $STATUS -eq 0 ]]; then
    timeout 10 dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO:-Desconhecido}!" 8 45
else
    dialog --no-cancel --colors --msgbox "ERRO: Não foi possível ingressar no domínio." 8 45
fi

