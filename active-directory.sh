#!/usr/bin/env bash

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

DOMINIO=$(\
    dialog --no-cancel --title "Configurar domínio Active Directory"\
        --inputbox "Insira o domínio:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

USUARIO=$(\
    dialog --no-cancel --title "Configurar domínio Active Directory"\
        --inputbox "Insira o usuário:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

SENHA=$(\
    dialog --no-cancel --title "Configurar domínio Active Directory"\
        --insecure --clear --passwordbox "Senha para $USUARIO:" 8 45\
    3>&1 1>&2 2>&3 3>&- \
)

apt -y update
apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

### Comando original
echo $SENHA | realm join -U $USUARIO $DOMINIO

STATUS=$?

bash -c "cat > /usr/share/pam-configs/mkhomedir" <<EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required                        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF

dialog --title "Aviso" --msgbox "Na próxima tela você deverá marcar a opção 'activate mkhomedir', para que as pastas dos usuários sejam criadas automaticamente. Caso contrário, não será possível fazer login no ambiente gráfico!" 9 60

pam-auth-update

# Permitir fazer login sem a necessidade de acrescentar o "@dominio" ao nome de usuário:
sed -i "s/use_fully_qualified_names = True/use_fully_qualified_names = False/g" /etc/sssd/sssd.conf

systemctl restart sssd

# dialog --yesno "Deseja adicionar um grupo deste domínio ao arquivo sudoers?" 8 60
# CONFIGURAR_SUDO=$?
# case $CONFIGURAR_SUDO in
#     0) GRUPO=$(dialog --erase-on-exit --no-cancel --title "Configurar domínio Active Directory" --inputbox "Insira o grupo:" 8 45 3>&1 1>&2 2>&3 3>&-) ; sed -i "/^%sudo.*ALL*/a %${GRUPO}@${DOMINIO}   ALL=(ALL:ALL) ALL" /etc/sudoers ; echo "Grupo $GRUPO adicionado ao arquivo sudoers.";;
#     1) echo "Você escolheu não adicionar grupo algum ao arquivo sudoers";;
#     255) echo "[ESC] key pressed.";;
# esac

if [[ $STATUS == 0 ]]; then
    dialog --no-cancel --msgbox "Bem-vindo ao domínio ${DOMINIO}!" 8 45
fi
