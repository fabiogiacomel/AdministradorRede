# CONTRATO_PROJETO_ADMINISTRADOR_REDE.md

**Data:** 01/02/2026
**Autor:** Arquiteto de Software (Gemini)
**Aprovador:** CEO
**Executor:** Engenheiro de Software (Antigravity)

---

## 1. Visão Geral do Projeto

O **AdministradorRede** é um agente de IA e automação projetado para rodar em Windows 11, com o objetivo de gerenciar, expandir e otimizar uma rede de rádio outdoor baseada em equipamentos **Ubiquiti LiteBeam M5 (LBE-M5-23)** rodando AirOS 5.x.

**Objetivo Primário:** Criar uma rede de "Expansão Infinita" (Daisy Chain) para cobrir grandes áreas (fazendas) para fins de IoT e Telemetria (baixa banda, alto alcance).

## 2. Arquitetura do Sistema

O sistema opera em um modelo **Híbrido Host/Container**:

* **Cérebro (Host):** Windows 11 rodando **PowerShell Core**. É responsável pela lógica de decisão, topologia e comandos de alto nível.
* **Músculo (Proxy):** Container **Docker (Alpine Linux)**.
* **Flag Obrigatória:** `--network host` (para acesso L2 direto).
* **Ferramentas:** `sshpass`, `openssh-client`, `iputils`, `arp-scan`.
* **Função:** Executar comandos SSH nos rádios e retornar o STDOUT para o Windows.



> **Regra de Ouro da Arquitetura:** O Windows NUNCA conecta via SSH direto na antena. Ele SEMPRE invoca o Docker para fazer o "trabalho sujo".

## 3. Parâmetros de Rede (Hardcoded)

O agente deve impor estritamente os seguintes parâmetros:

* **SSID (Nome da Rede):** `Internet`
* **WPA2-AES Key:** `unicornio`
* **Modo de Operação:** WDS Transparent Bridge / WDS Repeater.
* **Largura de Canal:** **10 MHz** (Para ganho de penetração e estabilidade).
* **Algoritmo de Rate:** MCS0 ou MCS1 (Fixo para estabilidade em longas distâncias).
* **Credenciais do Rádio:** Usuário `ubnt` / Senha `ubnt` (Default) ou `unicornio` (Após adoção).

## 4. Lógica de Negócio e Decisão (IA)

### 4.1. Critério de Aceitação de Sinal

O agente só autorizará a conexão ou repetição de um nó se:

* **RSSI (Signal Strength):** Melhor que **-75 dBm** (ex: -50, -60, -74).
* **Ação em caso de Falha:** Se o sinal for < -75dBm, o nó é marcado como "Instável" e ignorado, a menos que seja a única rota possível (override manual).

### 4.2. Topologia de Expansão

* O sistema deve suportar topologia linear (A -> B -> C -> D).
* O agente deve gerenciar a tabela de **WDS Peers** (Mac Address) dentro do arquivo `/tmp/system.cfg`.

## 5. Protocolos de Segurança e Recuperação

### 5.1. O Watchdog (Paraquedas)

Antes de aplicar qualquer alteração de rede crítica (IP, Canal, Wireless Mode), o agente OBRIGATORIAMENTE deve injetar um script de segurança na memória da antena:

> *Lógica:* "Se eu não conseguir pingar o Gateway em 600 segundos após o reboot, restauro o backup da configuração anterior."

### 5.2. O Dominó Reverso (Migração de Canal)

Para alterações globais (ex: mudar de 5800MHz para 5745MHz):

1. O Agente mapeia a topologia.
2. Envia comando de mudança para a antena **mais distante** (folha).
3. Vem recuando nó por nó até chegar na **Sede** (raiz).

## 6. Comandos e Manipulação (AirOS)

O Engenheiro de Software deve utilizar apenas comandos nativos do BusyBox/AirOS:

* **Leitura:** `iwlist ath0 scan`, `wlanconfig ath0 list`, `cat /tmp/system.cfg`.
* **Escrita:** `sed -i`, `echo`, `cp`.
* **Persistência:** `cfgmtd -w -p /etc/` (Salvar na flash), `reboot`.

## 7. Roadmap de Desenvolvimento (Prompts)

1. **A Fundação:** Setup do Docker, Dockerfile e script de comunicação PowerShell <-> Docker.
2. **A Ponte:** Wrapper PowerShell para execução de comandos remotos e parsing de retorno.
3. **O Olho de Deus:** Lógica de Discovery e Filtro de Sinal (-75dBm).
4. **A Expansão:** Script de configuração de WDS, SSID e Perfil IoT (10MHz).
5. **A Segurança:** Implementação do Watchdog e lógica de Dominó Reverso.

## 8. Cláusulas Anti-Alucinação

* **PROIBIDO:** Inventar APIs REST para o AirOS 5 (elas não existem, é tudo arquivo texto e SSH).
* **PROIBIDO:** Assumir que o Windows tem ferramentas nativas de Linux (`sed`, `grep`). O processamento de texto deve ser feito no PowerShell ou dentro do container.
* **PROIBIDO:** Usar interfaces gráficas (Web Browser automation). Apenas CLI.

---

**Status:** Aprovado para Execução.
**Assinatura CEO:** CEO
