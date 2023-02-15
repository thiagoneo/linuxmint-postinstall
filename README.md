# linuxmint-postinstall
Script de pós instalação do Linux Mint, com configurações personalizadas.

Uso:
1. Baixar a ISO do Linux Mint em https://linuxmint.com/download.php e executar a instalação do S.O.
2. No primeiro boot, pressionar as teclas Ctrl + Alt + F2, e fazer login com usuário e senha.
3. Baixar e executar o script inicial com os comandos:
   ```
   wget https://raw.githubusercontent.com/thiagoneo/linuxmint-postinstall/master/start-script.sh
   chmod +x start-script.sh
   ./start-script.sh
   ```
4. Os arquivos necessários serão baixados, juntamente com o script principal (`script.sh`), que será executado em seguida. Após o término da execução, reinicie aproveite o sistema atualizado configurado para uso.
