#!/usr/bin/env bash

sudo echo ""
while :; do sudo -v; sleep 59; done &
infiloop=$!

#--------------------------------- VARIÁVEIS ----------------------------------#
SCR_DIRECTORY=`pwd`
USER_ID=$(echo $UID)

#------------------- ATUALIZAR BASE DE DADOS DO REPOSITÓRIO -------------------#
sudo apt update

#------------------------- INSTALAR O PACOTE "dialog" -------------------------#
sudo apt install -y dialog

#--------------------------- DEFINIR NOVO HOSTNAME ----------------------------#
OLD_HOSTNAME=`hostname`
NEW_HOSTNAME=$(\
    dialog --no-cancel --title "Definir hostname"\
        --inputbox "Insira o nome do computador:" 8 40\
    3>&1 1>&2 2>&3 3>&- \
)
echo ""
sudo sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
sudo hostnamectl set-hostname $NEW_HOSTNAME
echo "Novo HOSTNAME definido como $NEW_HOSTNAME"

#--------------------------- DRIVERS DE IMPRESSORA ----------------------------#
dialog --erase-on-exit --yesno "Deseja instalar os drivers para impressora Brother?" 8 60
INSTALL_DRIVERS=$?
case $INSTALL_DRIVERS in
    0) echo "Os drivers serão instalados";;
    1) echo "Você escolheu não instalar os drivers" ; rm $SCR_DIRECTORY/packages/hll*.deb $SCR_DIRECTORY/packages/dcp*.deb;;
    255) echo "[ESC] key pressed.";;
esac

# #---------------------------- SUPORTE A BLUETOOTH -----------------------------#
# dialog --erase-on-exit --yesno "Deseja mater o suporte a bluetooth?" 8 60
# BLUETOOTH=$?
# case $BLUETOOTH in
#     0) echo "O suporte a bluetooth será mantido";;
#     1) echo "Você escolheu remover o suporte a bluetooth" ; echo "bluetooth" >> $SCR_DIRECTORY/lista-remocao.txt ; echo "bluez" >> $SCR_DIRECTORY/lista-remocao.txt;;
#     255) echo "[ESC] key pressed.";;
# esac

#------------------------------ ACTIVE DIRECTORY ------------------------------#
dialog --erase-on-exit --yesno "Deseja ingressar este computador no Active Directory Domain?" 8 60
JOIN_AD=$?
function DialogInfo() {
dialog --erase-on-exit --title "Aviso" --msgbox 'Na próxima tela você deverá alterar o servidor DNS de modo a conseguir resolver o domínio' 6 50
}
case $JOIN_AD in
    0) DialogInfo ; nmtui-edit ; sudo systemctl restart NetworkManager.service ; bash $SCR_DIRECTORY/active-directory.sh;;
    1) echo "Você escolheu não ingressar no Active Directory";;
    255) echo "[ESC] key pressed.";;
esac

#---------------------------- APLICAR ATUALIZAÇÕES ----------------------------#
echo ""
echo "INICIANDO ATUALIZAÇÃO COMPLETA DO SISTEMA..."
echo ""
sudo mintupdate-cli upgrade -r -y
sudo mintupdate-cli upgrade -r -y
sudo apt upgrade -y

#---------------------- INSTALAR PACOTES DO REPOSITÓRIO -----------------------#
echo ""
echo "INSTALANDO PACOTES DO REPOSITÓRIO..."
echo ""
sudo apt install $(cat $SCR_DIRECTORY/pacotes-sem-recommends.txt) --no-install-recommends -y
sudo apt install $(cat $SCR_DIRECTORY/pacotes.txt) -y

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 1 ----------------#
sudo apt purge $(cat $SCR_DIRECTORY/lista-remocao.txt) -y
sudo apt autoremove --purge -y

#------------------------- INSTALAR PACOTES DO LOCAIS -------------------------#
echo ""
echo "INSTALANDO PACOTES DO LOCAIS..."
cd /tmp
### Google Chrome
wget -c https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
if [[ $? == 0 ]]; then
    mv google-chrome-stable_current_amd64.deb $SCR_DIRECTORY/packages/
fi
### RustDesk
wget -c https://github.com/rustdesk/rustdesk/releases/download/1.1.9/rustdesk-1.1.9.deb
if [[ $? == 0 ]]; then
    mv rustdesk-1.1.9.deb $SCR_DIRECTORY/packages/
fi
cd $SCR_DIRECTORY
ls $SCR_DIRECTORY/packages/*.deb > pacotes-locais.txt
sudo apt install $(cat $SCR_DIRECTORY/pacotes-locais.txt) --no-install-recommends -y
### Remover impressoras adicionadas automaticamente
case $INSTALL_DRIVERS in
    0) sudo lpadmin -x DCPL5652DN ; sudo lpadmin -x HLL6202DW;;
    1) echo "Nenhuma impressora instalada";;
esac

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 2 ----------------#
sudo apt purge $(cat $SCR_DIRECTORY/lista-remocao.txt) -y
sudo apt autoremove --purge -y

#-------------------- AJUSTES EM CONFIGURAÇÕES DO SISTEMA ---------------------#
cd $HOME
sudo chown -R root:root $SCR_DIRECTORY/system-files/
cd $SCR_DIRECTORY/
sudo \cp -rf $SCR_DIRECTORY/system-files/etc/lightdm/ /etc/
sudo \cp $SCR_DIRECTORY/system-files/etc/default/grub /etc/default/grub
sudo \cp $SCR_DIRECTORY/system-files/etc/grub.d/10_linux /etc/grub.d/10_linux
echo "vm.swappiness=25" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_background_ratio=5" | sudo tee -a /etc/sysctl.conf
echo "vm.dirty_ratio=10" | sudo tee -a /etc/sysctl.conf
echo lz4hc | sudo tee -a /etc/initramfs-tools/modules
echo lz4hc_compress | sudo tee -a /etc/initramfs-tools/modules
echo z3fold | sudo tee -a /etc/initramfs-tools/modules
sudo update-initramfs -u
sudo update-grub
#### Configuração Firewall
sudo systemctl enable ufw
sudo ufw enable
#### Ativar atualizações automáticas
sudo mintupdate-automation upgrade enable
sudo mintupdate-automation autoremove enable
#### Desativar driver problemático do CUPS
sudo mkdir -p /usr/lib/cups/driver/disabled
sudo mv /usr/lib/cups/driver/driverless /usr/lib/cups/driver/disabled/
sudo chown -R $USER_ID:$USER_ID $SCR_DIRECTORY/

#------------------------------------ FIM -------------------------------------#
kill "$infiloop"
clear
echo "Chegamos ao fim."
echo "Você pode reiniciar agora com o comando '/sbin/reboot'."
