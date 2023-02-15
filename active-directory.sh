#!/usr/bin/env bash


sudo apt -y update
sudo apt -y install dialog realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

DOMINIO=$(\
    dialog --erase-on-exit --no-cancel --title "Configurar domínio Active Directory"\
        --inputbox "Insira o domínio:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

USUARIO=$(\
    dialog --erase-on-exit --no-cancel --title "Configurar domínio Active Directory"\
        --inputbox "Insira o usuário:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

SENHA=$(\
    dialog --erase-on-exit --no-cancel --title "Configurar domínio Active Directory"\
        --insecure --clear --passwordbox "Senha para $USUARIO:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

### Comando original
echo $SENHA | sudo realm join -U $USUARIO $DOMINIO

STATUS=$?

sudo bash -c "cat > /usr/share/pam-configs/mkhomedir" <<EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required                        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF

sudo pam-auth-update

sudo systemctl restart sssd

dialog --erase-on-exit --yesno "Deseja adicionar um grupo deste domínio ao arquivo sudoers?" 8 60
CONFIGURAR_SUDO=$?
case $CONFIGURAR_SUDO in
    0) GRUPO=$(dialog --erase-on-exit --no-cancel --title "Configurar domínio Active Directory" --inputbox "Insira o grupo:" 8 45 3>&1 1>&2 2>&3 3>&-) ; sudo sed -i "/^%sudo.*ALL*/a %${GRUPO}@${DOMINIO}   ALL=(ALL:ALL) ALL" /etc/sudoers ; echo "Grupo $GRUPO adicionado ao arquivo sudoers.";;
    1) echo "Você escolheu não adicionar grupo algum ao arquivo sudoers";;
    255) echo "[ESC] key pressed.";;
esac

if [[ $STATUS == 0 ]]; then
    dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO}!" 8 45
fi
