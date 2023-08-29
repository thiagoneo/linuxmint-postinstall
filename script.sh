#!/usr/bin/env bash

# Verificar se o usuário é o root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."
   exit 1
fi

#--------------------------------- VARIÁVEIS ----------------------------------#
SCR_DIRECTORY=`pwd`

#------------------- ATUALIZAR BASE DE DADOS DO REPOSITÓRIO -------------------#
apt update -y

#------------------------- INSTALAR O PACOTE "dialog" -------------------------#
apt install -y dialog

#--------------------------- ALTERAR SENHA DO ROOT ----------------------------#
bash $SCR_DIRECTORY/senha-root.sh

#--------------------------- DEFINIR NOVO HOSTNAME ----------------------------#
OLD_HOSTNAME=`hostname`
NEW_HOSTNAME=$(\
    dialog --no-cancel --title "Definir hostname"\
        --inputbox "Insira o nome do computador:" 8 40\
    3>&1 1>&2 2>&3 3>&- \
)
echo ""
sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
hostnamectl set-hostname $NEW_HOSTNAME
echo "Novo HOSTNAME definido como $NEW_HOSTNAME"

# #--------------------------- DRIVERS DE IMPRESSORA ----------------------------#
# dialog --erase-on-exit --yesno "Deseja instalar os drivers para impressora Brother?" 8 60
# INSTALL_DRIVERS=$?
# case $INSTALL_DRIVERS in
#     0) echo "Os drivers serão instalados";;
#     1) echo "Você escolheu não instalar os drivers" ; rm $SCR_DIRECTORY/packages/hll*.deb $SCR_DIRECTORY/packages/dcp*.deb;;
#     255) echo "[ESC] key pressed.";;
# esac

# #---------------------------- SUPORTE A BLUETOOTH -----------------------------#
# dialog --erase-on-exit --yesno "Deseja mater o suporte a bluetooth?" 8 60
# BLUETOOTH=$?
# case $BLUETOOTH in
#     0) echo "O suporte a bluetooth será mantido";;
#     1) echo "Você escolheu remover o suporte a bluetooth" ; echo "bluetooth" >> $SCR_DIRECTORY/lista-remocao.txt ; echo "bluez" >> $SCR_DIRECTORY/lista-remocao.txt;;
#     255) echo "[ESC] key pressed.";;
# esac
# echo "bluetooth" >> $SCR_DIRECTORY/lista-remocao.txt
# echo "bluez" >> $SCR_DIRECTORY/lista-remocao.txt


#---------------------------- OCS-INVENTORY AGENT -----------------------------#
dialog --erase-on-exit --yesno "Deseja instalar o OCS Inventory Agent?" 8 60
INSTALL_OCS=$?
case $INSTALL_OCS in
    0) apt install -y ocsinventory-agent ; dpkg-reconfigure ocsinventory-agent ; ocsinventory-agent;;
    1) echo "Você escolheu não instalar o OCS Inventory Agent.";;
    255) echo "[ESC] key pressed.";;
esac

#------------------------------ ACTIVE DIRECTORY ------------------------------#
dialog --erase-on-exit --yesno "Deseja ingressar este computador em um domínio Active Directory?" 8 60
JOIN_AD=$?
function DialogInfo() {
dialog --erase-on-exit --title "Aviso" --msgbox 'Na próxima tela você deverá alterar o servidor DNS de modo a conseguir resolver o domínio' 8 60
}
##### Copiar arquivo de config. Network Manager para corrigir erro do DNS
\cp -rf $SCR_DIRECTORY/system-files/etc/NetworkManager/ /etc/
rm /etc/resolv.conf
systemctl restart NetworkManager.service
case $JOIN_AD in
    0) DialogInfo ; nmtui-edit ; systemctl restart NetworkManager.service ; bash $SCR_DIRECTORY/active-directory.sh;;
    1) echo "Você escolheu não ingressar no Active Directory";;
    255) echo "[ESC] key pressed.";;
esac

#--------------------- INSTALAR PACOTE DE FONTES MICROSOFT --------------------#
apt install -y ttf-mscorefonts-installer

#---------------------------- APLICAR ATUALIZAÇÕES ----------------------------#
echo ""
echo "INICIANDO ATUALIZAÇÃO COMPLETA DO SISTEMA..."
echo ""
mintupdate-cli upgrade -r -y
mintupdate-cli upgrade -r -y
apt upgrade -y

#---------------------- INSTALAR PACOTES DO REPOSITÓRIO -----------------------#
echo ""
echo "INSTALANDO PACOTES DO REPOSITÓRIO..."
echo ""
apt install $(cat $SCR_DIRECTORY/pacotes-sem-recommends.txt) --no-install-recommends -y
apt install $(cat $SCR_DIRECTORY/pacotes.txt) -y

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 1 ----------------#
apt purge $(cat $SCR_DIRECTORY/lista-remocao.txt) -y
apt autoremove --purge -y

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
wget -c https://github.com/rustdesk/rustdesk/releases/download/1.2.2/rustdesk-1.2.2-x86_64.deb
if [[ $? == 0 ]]; then
    mv rustdesk_latest_amd64.deb $SCR_DIRECTORY/packages/
fi
cd $SCR_DIRECTORY
ls $SCR_DIRECTORY/packages/*.deb > pacotes-locais.txt
apt install $(cat $SCR_DIRECTORY/pacotes-locais.txt) --no-install-recommends -y
### Remover impressoras adicionadas automaticamente
# case $INSTALL_DRIVERS in
#     0) lpadmin -x DCPL5652DN ; lpadmin -x HLL6202DW;;
#     1) echo "Nenhuma impressora instalada";;
# esac
lpadmin -x DCPL5652DN
lpadmin -x HLL6202DW

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 2 ----------------#
apt purge $(cat $SCR_DIRECTORY/lista-remocao.txt) -y
apt autoremove --purge -y

#-------------------- AJUSTES EM CONFIGURAÇÕES DO SISTEMA ---------------------#
cd $HOME
chown -R root:root $SCR_DIRECTORY/system-files/
cd $SCR_DIRECTORY/

sed -i "s/NoDisplay=true/NoDisplay=false/g" /etc/xdg/autostart/*.desktop
\cp -rf $SCR_DIRECTORY/system-files/etc/lightdm/ /etc/
\cp -rf $SCR_DIRECTORY/system-files/etc/skel/ /etc/
\cp -rf $SCR_DIRECTORY/system-files/usr/share/ukui-greeter/ /usr/share/
\cp $SCR_DIRECTORY/system-files/etc/default/grub /etc/default/grub
echo "vm.swappiness=25" | tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | tee -a /etc/sysctl.conf
echo "vm.dirty_background_ratio=5" | tee -a /etc/sysctl.conf
echo "vm.dirty_ratio=10" | tee -a /etc/sysctl.conf
echo lz4hc | tee -a /etc/initramfs-tools/modules
echo lz4hc_compress | tee -a /etc/initramfs-tools/modules
echo z3fold | tee -a /etc/initramfs-tools/modules
update-initramfs -u
update-grub
#### Configuração Firewall
systemctl enable ufw
ufw enable
#### Ativar atualizações automáticas
mintupdate-automation upgrade enable
mintupdate-automation autoremove enable
#### Desativar serviço de detecção/instalação automática de impressora
systemctl disable cups-browsed.service
#### Desativar driver problemático do CUPS
mkdir -p /usr/lib/cups/driver/disabled
mv /usr/lib/cups/driver/driverless /usr/lib/cups/driver/disabled/
chown -R 1000:1000 $SCR_DIRECTORY/
chmod -R 777 $SCR_DIRECTORY/

#------------------------------------ FIM -------------------------------------#

dialog --erase-on-exit --yesno "Chegamos ao fim. É necessário reiniciar o computador para aplicar as alterações. Deseja reiniciar agora?" 8 60
REBOOT=$?
case $REBOOT in
    0) systemctl reboot;;
    1) echo "Por favor reinicie o sistema assim que possível.";;
    255) echo "[ESC] key pressed.";;
esac
