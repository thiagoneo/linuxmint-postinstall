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


#---------------------- VERIFICAR CONEXÃO COM A INTERNET ---------------------#
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    echo "Sem conexão com a internet. Por favor, conecte-se à internet e tente novamente."
    exit 1
fi

#------------------- ATUALIZAR BASE DE DADOS DO REPOSITÓRIO -------------------#
if ! apt update -y; then
    echo "Falha ao atualizar a base de dados dos repositórios. Verifique sua conexão ou os repositórios configurados."
    exit 1
fi

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
case $JOIN_AD in
    0) bash "${SCR_DIRECTORY}"/active_directory.sh --no-change-hostname ; clear ;;
    1) echo "Você escolheu não ingressar no Active Directory";;
    255) echo "[ESC] key pressed.";;
esac

#-------------------------------- ATIVAR SSH ----------------------------------#
dialog --erase-on-exit --defaultno --yesno "Deseja instalar o serviço SSH?" 8 60
INSTALL_SSH=$?
case $INSTALL_SSH in
    0) apt -y install openssh-server ; ufw allow ssh ;;
    1) echo "Você escolheu não instalar o SSH server.";;
    255) echo "[ESC] key pressed.";;
esac

#----------------------------- CLAMAV ANTIVIRUS -------------------------------#
dialog --title "ClamAV Antivirus" --erase-on-exit --yesno "Deseja instalar o antivírus ClamAV e habilitar a proteção em tempo real neste computador?\n\n(Nota: Pode causar lentidão em hardware antigo e/ou menos potente)" 10 70
INSTALL_CLAMAV=$?
case $INSTALL_CLAMAV in
    0) echo "Iniciando instalação do ClamAV..." ; bash "${SCR_DIRECTORY}"/install_clamav_antivirus.sh ; clear ;;
    1) echo "Você escolheu não instalar o antivírus.";;
    255) echo "[ESC] key pressed.";;
esac

#------------------ INSTALAR DRIVERS ADICIONAIS DE IMPRESSORA -----------------#
mkdir -p "${SCR_DIRECTORY}"/pacotes/drivers/brother
mkdir -p "${SCR_DIRECTORY}"/pacotes/drivers/samsung

# Brother:
wget -c https://download.brother.com/welcome/dlf102573/hll6402dwlpr-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
wget -c https://download.brother.com/welcome/dlf102574/hll6402dwcupswrapper-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
wget -c https://download.brother.com/welcome/dlf102561/hll6202dwlpr-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
wget -c https://download.brother.com/welcome/dlf102562/hll6202dwcupswrapper-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
wget -c https://download.brother.com/welcome/dlf102593/dcpl5652dnlpr-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
wget -c https://download.brother.com/welcome/dlf102594/dcpl5652dncupswrapper-3.5.1-1.i386.deb -P "${SCR_DIRECTORY}"/pacotes/drivers/brother
echo ""
echo "Instalando drivers de impressora Brother 🖨️ ..."
apt install "${SCR_DIRECTORY}"/pacotes/drivers/brother/*.deb --no-install-recommends -y
# Remover impressoras adicionadas automaticamente
lpadmin -x DCPL5652DN
lpadmin -x HLL6202DW
lpadmin -x HLL6402DW

# Samsung:
wget -c https://ftp.hp.com/pub/softlib/software13/printers/SS/SL-C4010ND/uld_V1.00.39_01.17.tar.gz -P "${SCR_DIRECTORY}"/pacotes/drivers/samsung
cd "${SCR_DIRECTORY}"/pacotes/drivers/samsung
tar -xvzf uld_V1.00.39_01.17.tar.gz
echo ""
echo "Instalando drivers de impressora Samsung 🖨️ ..."
cd "${SCR_DIRECTORY}"/pacotes/drivers/samsung/uld
export SKIP_EULA_PAGER=1
export AGREE_EULA='y'
export CONTINUE_INSTALL='y'
export CONFIGURE_FIREWALL='n'
export QUIT_INSTALL='0'
chmod +x install.sh
./install.sh

# Voltar para o diretório do script
cd "${SCR_DIRECTORY}"

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
apt-mark hold gnome-keyring lightdm ukui-greeter language-pack-pt language-pack-pt-base liblightdm-gobject-1-0 liblightdm-qt5-3-0

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

#---------------- BLOQUEIO DE DISPOSITIVOS ARMAZENAMENTO USB -----------------#
cat <<EOF > "/etc/udev/rules.d/99-usb-block.rules"
# Bloquear todos os dispositivos de armazenamento USB
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", ATTRS{bInterfaceSubClass}=="06", ATTRS{bInterfaceProtocol}=="50", RUN+="/bin/sh -c 'echo 0 > /sys%p/authorized'"

# Fim da regra
LABEL="usb_storage_end"
EOF
udevadm control --reload-rules && udevadm trigger

#------------------------------------ FIM -------------------------------------#
chown -R 1000:1000 "${SCR_DIRECTORY}"/

dialog --erase-on-exit --yesno "Chegamos ao fim. É necessário reiniciar o computador para aplicar as alterações. Deseja reiniciar agora?" 8 60
REBOOT=$?
case $REBOOT in
    0) systemctl reboot;;
    1) echo "Por favor reinicie o sistema assim que possível.";;
    255) echo "[ESC] key pressed.";;
esac
