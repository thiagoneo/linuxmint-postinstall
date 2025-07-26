#!/usr/bin/env bash

##########################################
# Script de Pós-instalação do Linux Mint #
# Autor: Thiago de S. Ferreira           #
# E-mail: sousathiago@protonmail.com     #
##########################################

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
# Instalar o pacote dialog, se não for encontrado no sistema
if ! command -v dialog &> /dev/null; then
    sudo apt -y install dialog
fi

#--------------------------- ALTERAR SENHA DO ROOT ----------------------------#
bash "${SCR_DIRECTORY}"/senha_root.sh

#--------------------------- DEFINIR NOVO HOSTNAME ----------------------------#
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
##### Copiar arquivo de config. Network Manager para corrigir erro do DNS
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/NetworkManager/ /etc/
rm /etc/resolv.conf
systemctl restart NetworkManager.service
case $JOIN_AD in
    0) bash "${SCR_DIRECTORY}"/active_directory.sh ; clear ;;
    1) echo "Você escolheu não ingressar no Active Directory";;
    255) echo "[ESC] key pressed.";;
esac

#--------------------- INSTALAR PACOTE DE FONTES MICROSOFT --------------------#
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections
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
apt install $(cat "${SCR_DIRECTORY}"/pacotes_sem_recommends.txt) --no-install-recommends -y
apt install $(cat "${SCR_DIRECTORY}"/pacotes.txt) -y

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 1 ----------------#
apt purge $(cat "${SCR_DIRECTORY}"/pacotes_remover.txt) -y
apt autoremove --purge -y

#------------------------- INSTALAR PACOTES DO LOCAIS -------------------------#
echo ""
echo "INSTALANDO PACOTES DO LOCAIS..."
cd "${SCR_DIRECTORY}"
grep -v '^#' pacotes_baixar.txt | wget -i - -P pacotes
apt install "${SCR_DIRECTORY}"/pacotes/*.deb --no-install-recommends -y

#---------------------- BLOQUEAR ATUALIZAÇÕES DE PACOTES -----------------------#
apt-mark hold lightdm ukui-greeter language-pack-pt language-pack-pt-base liblightdm-gobject-1-0 liblightdm-qt5-3-0

# Remover impressoras adicionadas automaticamente
lpadmin -x DCPL5652DN
lpadmin -x HLL6202DW
lpadmin -x HLL6402DW

#---------------- DESINSTALAR PACOTES DESNECESSÁRIOS - PARTE 2 ----------------#
apt purge $(cat "${SCR_DIRECTORY}"/pacotes_remover.txt) -y
apt autoremove --purge -y

#-------------------- AJUSTES EM CONFIGURAÇÕES DO SISTEMA ---------------------#
# Copia de arquivos de configuração diversos para o sistema

cd $HOME
chown -R root:root "${SCR_DIRECTORY}"/system-files/
cd "${SCR_DIRECTORY}"/

# Configuração para exibir todos os aplicativos de inicialização
sed -i "s/NoDisplay=true/NoDisplay=false/g" /etc/xdg/autostart/*.desktop

# Configuração do gerenciador de telas LightDM (tela de login)
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/lightdm/ /etc/

# Configuração de políticas de navegadores Firefox e Google Chrome
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/firefox/ /etc/
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/opt/ /etc/
chmod -R 755 /etc/firefox/
chmod 644 /etc/firefox/policies/policies.json
chmod -R 755 /etc/opt/
chmod 644 /etc/opt/chrome/policies/*/*.json

# Configurações padrão dos usuários
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/skel/ /etc/
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/dconf/ /etc/
chmod 755 /etc/dconf/profile/
chmod 755 /etc/dconf/db/local.d/
dconf update

# Instalação de certificados CA local
rm -f "${SCR_DIRECTORY}"/system-files/usr/local/share/ca-certificates/empty
\cp -rf "${SCR_DIRECTORY}"/system-files/usr/local/share/ca-certificates/* /usr/local/share/ca-certificates/
update-ca-certificates

# Configurar navegadores para utilizar repositório de certificados CA do sistema
\cp -rf "${SCR_DIRECTORY}"/system-files/usr/local/bin/fix-browsers-ca-trust.sh /usr/local/bin
chmod +x /usr/local/bin/fix-browsers-ca-trust.sh
/usr/local/bin/fix-browsers-ca-trust.sh

# Ativar ZSWAP e configurar parâmetros de swap e cache
\cp "${SCR_DIRECTORY}"/system-files/etc/default/grub /etc/default/grub
echo "vm.swappiness=25" | tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | tee -a /etc/sysctl.conf
echo "vm.dirty_background_ratio=5" | tee -a /etc/sysctl.conf
echo "vm.dirty_ratio=10" | tee -a /etc/sysctl.conf
echo lz4hc | tee -a /etc/initramfs-tools/modules
echo lz4hc_compress | tee -a /etc/initramfs-tools/modules
echo z3fold | tee -a /etc/initramfs-tools/modules
update-initramfs -u
update-grub

# Habilitar firewall
systemctl enable ufw
ufw enable

# Ativar atualizações automáticas
mintupdate-automation upgrade enable
mintupdate-automation autoremove enable

# Desativar serviço de detecção/instalação automática de impressora
systemctl disable cups-browsed.service

# Desativar driver problemático do CUPS
mkdir -p /usr/lib/cups/driver/disabled
mv /usr/lib/cups/driver/driverless /usr/lib/cups/driver/disabled/

#------------------------------ CLAMAV ANTIVIRUS ------------------------------#
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/clamav/ /etc/
\cp -rf "${SCR_DIRECTORY}"/system-files/etc/systemd/ /etc/
chmod +x /etc/clamav/virus-event.bash
systemctl daemon-reload
systemctl stop clamav-freshclam
freshclam
systemctl enable --now clamav-freshclam
# Habilitar serviço
dialog --title "ClamAV Antivirus" --erase-on-exit --defaultno --yesno "Deseja habilitar a proteção em tempo real do ClamAV Antivirus?\n\n(Nota: Pode causar lentidão em hardware antigo e/ou menos potente)" 10 60
ENABLE_CLAMAV=$?
case $ENABLE_CLAMAV in
    0) systemctl enable clamav-daemon ; systemctl restart clamav-daemon ; systemctl enable clamav-clamonacc.service ; systemctl restart clamav-clamonacc.service ;;
    1) systemctl disable clamav-daemon ; systemctl stop clamav-daemon ; systemctl disable clamav-clamonacc.service ; systemctl stop clamav-clamonacc.service ; echo "Você escolheu não habilitar o serviço do ClamAV.";;
    255) echo "[ESC] key pressed.";;
esac
chown -R 1000:1000 "${SCR_DIRECTORY}"/
chmod -R 777 "${SCR_DIRECTORY}"/

#---------------- BLOQUEIO DE DISPOSITIVOS ARMAZENAMENTO USB -----------------#
cat <<EOF > "/etc/udev/rules.d/99-usb-block.rules"
# Bloquear todos os outros dispositivos de armazenamento USB
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", ATTRS{bInterfaceSubClass}=="06", ATTRS{bInterfaceProtocol}=="50", RUN+="/bin/sh -c 'echo 0 > /sys%p/authorized'"

# Fim da regra
LABEL="usb_storage_end"
EOF
udevadm control --reload-rules && udevadm trigger

#------------------------------------ FIM -------------------------------------#

dialog --erase-on-exit --yesno "Chegamos ao fim. É necessário reiniciar o computador para aplicar as alterações. Deseja reiniciar agora?" 8 60
REBOOT=$?
case $REBOOT in
    0) systemctl reboot;;
    1) echo "Por favor reinicie o sistema assim que possível.";;
    255) echo "[ESC] key pressed.";;
esac
