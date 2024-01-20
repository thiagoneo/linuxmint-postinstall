#!/usr/bin/env bash

##################################################
# Script para alteração de senha do usuário root #
# Autor: Thiago de S. Ferreira                   #
# E-mail: sousathiago@protonmail.com             #
##################################################

# Verificar se o usuário é o root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."
   exit 1
fi

ALT=1
while [ $ALT = 1 ]
do
    SENHA_ROOT=$(\
        dialog --no-cancel --title "Definir senha do root"\
            --insecure --clear --passwordbox "Insira uma senha para o usuário root:" 8 45\
        3>&1 1>&2 2>&3 3>&- \
    )
    CONFIRMA_SENHA_ROOT=$(\
        dialog --no-cancel --title "Definir senha do root"\
            --insecure --clear --passwordbox "Confirme a senha, digitando-a mais uma vez:" 8 45\
        3>&1 1>&2 2>&3 3>&- \
    )
    if [ $SENHA_ROOT = $CONFIRMA_SENHA_ROOT ]; then
        ALT=0
    else
        dialog --no-cancel --title "Definir senha do root"\
            --msgbox "As senhas não são iguais. Tente novamente." 6 45
    fi
done
echo "root:$SENHA_ROOT" | chpasswd
if [ $? = 0 ]; then
    dialog --no-cancel --title "Definir senha do root"\
            --msgbox "Senha alterada com sucesso!" 6 40
fi
