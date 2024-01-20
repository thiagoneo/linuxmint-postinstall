# linuxmint-postinstall

Script de pós-instalação personalizado para o Linux Mint, otimizado para ambientes corporativos.

Este script visa simplificar e aprimorar a integração do Linux Mint em ambientes corporativos, oferecendo uma variedade de configurações e personalizações. Algumas das funcionalidades incluídas são:

- **Integração Facilitada com Active Directory:** Automatiza todas as tarefas manuais envolvidas na integração com o Active Directory, eliminando a necessidade de alterar manualmente as configurações de DNS e inserir comandos no terminal. O script utiliza telas de diálogo intuitivas que solicitam ao usuário apenas as informações essenciais para autenticação, como usuário, senha, domínio e o endereço DNS (IP do servidor de domínio). Isso torna o processo de ingresso no AD tão simples e intuitivo quanto no ambiente Windows.

- **Suporte a Inventário OCS Inventory:** Oferece a opção de integração com o sistema de inventário OCS Inventory, proporcionando uma gestão eficiente de ativos e inventário no ambiente corporativo.

- **Otimização de Performance:** Realiza ajustes para otimizar o desempenho do sistema operacional, visando proporcionar uma experiência mais ágil e responsiva.

- **Segurança Aprimorada:** Os sistemas Linux são, por natureza, mais seguros e resistentes a ameaças. Para aprimorar ainda mais essa segurança, o script ativa e configura o firewall, fortalecendo a proteção do sistema operacional.

- **Atualizações Automáticas e Transparentes:** Ativa as atualizações automáticas do sistema, eliminando a preocupação e a necessidade de aplicar atualizações manualmente. O Linux Mint realiza as atualizações em segundo plano, permitindo que o usuário utilize o computador enquanto o sistema executa essas tarefas. O sistema nunca será reiniciado de forma inesperada, e o usuário tem total controle para reiniciar quando for conveniente. Isso garante um sistema que se auto-mantém seguro e atualizado.

- **Otimização e Foco no Trabalho:** Remove programas desnecessários, visando não apenas otimizar o desempenho do sistema, mas também reduzir distrações e melhorar a produtividade e foco no ambiente de trabalho.

- **Compatibilidade com Documentos do Microsoft Office:** O Linux Mint vem por padrão com o LibreOffice, mas a instalação das fontes Microsoft visa melhorar a compatibilidade de documentos criados no ambiente Windows. Isso permite uma transição suave em ambientes operacionais mistos de Windows e Linux.

- **Automação da Instalação de Aplicativos:** Facilita a instalação de aplicativos cruciais para ambientes corporativos, como o navegador Google Chrome, a ferramenta de acesso remoto RustDesk e drivers de impressoras.

- **Compatibilidade com o Idioma Português-BR:** Automatiza a instalação de pacotes de idioma adicionais para o Português-BR, incluindo a extensão de corretor gramatical para o LibreOffice. Isso contribui para uma experiência de uso mais completa e amigável em ambientes corporativos brasileiros.

Este script não apenas otimiza a experiência do usuário, mas também simplifica a implantação e integração de sistemas Linux em ambientes predominantemente Windows. A integração com o Active Directory e outras ferramentas corporativas contribui para a coexistência harmoniosa entre sistemas operacionais, enquanto a interface intuitiva do Linux Mint proporciona uma transição fácil para usuários familiarizados com ambientes Windows.


**Instruções de uso:**

1. Baixe a ISO do Linux Mint 21.2 em (https://linuxmint.com/edition.php?id=305) e execute a instalação do S.O.
2. Acesse a página [Releases](https://github.com/thiagoneo/linuxmint-postinstall/releases) do projeto e baixe a última versão (arquivo tar.gz). Extraia esse arquivo.
3. Faça login na interface de terminal do Linux (pressione as teclas Ctrl + Alt + F2), navegue até a pasta com os arquivos extraídos e execute estes comandos:
   ```
   chmod +x *.sh
   ./script.sh
   ```
   Obs.: Também é possível abrir um terminal dentro do ambiente gráfico e executar o script. No entanto, isso pode apresentar problemas, como interrupções durante a atualização do sistema, que poderiam encerrar inesperadamente o ambiente gráfico e interromper a execução do script (isso implica também que deve-se salvar todos os trabalhos e fechar os programas antes da execução do script). Portanto, o mais seguro e recomendado é executar o script em um console (TTY) separado.
4. Após o término da execução, reinicie o sistema.

