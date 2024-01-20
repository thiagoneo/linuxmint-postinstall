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

# Testa se o pacote dialog está instalado, e instala-o caso não esteja
if ! dpkg -s dialog >/dev/null 2>&1; then
    echo "O pacote 'dialog' não está instalado. Instalando o pacote..."
    apt update
    apt install -y dialog
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
echo $SENHA | realm join -U ${USUARIO} ${DOMINIO}

STATUS=$?

# Habilitar criacao automatica de pastas de usuarios ao fazer logon
if ! grep -q "session.*required.*pam_mkhomedir.so.*umask.*" /etc/pam.d/common-session; then
    echo 'session required                        pam_mkhomedir.so umask=0027 skel=/etc/skel' >> /etc/pam.d/common-session
fi

# Permitir fazer login sem a necessidade de acrescentar o sufixo "@dominio" ao nome de usuário:
sed -i "s/use_fully_qualified_names = True/use_fully_qualified_names = False/g" /etc/sssd/sssd.conf

systemctl restart sssd

if [[ $STATUS == 0 ]]; then
    dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO}!" 8 45
fi
