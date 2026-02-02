# 📡 AdministradorRede v6.0 (ROBOT)

![Version](https://img.shields.io/badge/version-6.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Docker-lightgrey)
![Status](https://img.shields.io/badge/status-production-success)

O **AdministradorRede** é um agente de I.A. e orquestrador de automação projetado para gerenciar e expandir redes de rádio **Ubiquiti LiteBeam M5** (AirOS 5.x) em larga escala.

Focado em **IoT e Telemetria** para ambientes rurais (Smart Farming), o sistema utiliza uma arquitetura híbrida para garantir conectividade robusta, segurança operacional e expansão simplificada ("Daisy Chain").

---

## 🏗 Arquitetura do Sistema

O projeto opera no modelo **Híbrido Host/Container**, separando a lógica de decisão da execução de baixo nível:

| Componente | Função | Tecnologia |
| :--- | :--- | :--- |
| **Cérebro (Host)** | Decisão, Topologia e UI | **Windows 11 + PowerShell Core** |
| **Músculo (Proxy)** | Execução SSH e Comandos | **Docker (Alpine Linux)** |

> **Nota:** O Windows gerencia a estratégia, enquanto o container Docker executa a "trabalho sujo" de comunicação com os rádios (SSH Legacy, tratamento de texto), garantindo compatibilidade e segurança.

## 🚀 Funcionalidades Principais

### 🧠 Discovery IA & Filtro de Sinal
O sistema realiza varreduras inteligentes na rede, identificando nós vizinhos e permitindo conexão apenas com **RSSI melhor que -75dBm**, garantindo a estabilidade do link.

### ⚙️ Configuração "Zero-Touch" (Padrão IoT)
Aplica automaticamente o perfil de comunicação otimizado para longas distâncias:
*   **Mode:** WDS Transparent Bridge.
*   **Channel Width:** 10 MHz (Maior penetração de sinal).
*   **Rate:** MCS0 / MCS1 (Fixo).
*   **Security:** WPA2-AES (Key: `unicornio`).

### 🛡️ Protocolos de Segurança Ativa (Fail-Safe)
*   **Watchdog (Paraquedas):** Injeta um script na memória RAM da antena antes de qualquer alteração crítica. Se a antena perder comunicação com o Gateway por 600s, a configuração anterior é restaurada automaticamente.
*   **Dominó Reverso:** Algoritmo de migração de canais que atualiza a rede da ponta (folha) para a raiz (base), prevenindo o isolamento de nós remotos durante mudanças de frequência.

### 🌉 Ponte de Sub-rede Integrada
Gerenciamento automático de interfaces de rede no Windows para criar túneis de acesso direto aos rádios (Ex: `192.168.1.222`), permitindo configuração sem alterar o IP da máquina host.

---

## 📋 Pré-requisitos

*   **Sistema Operacional:** Windows 10 ou 11 (x64).
*   **Docker Desktop:** Instalado e configurado para *Linux Containers*.
*   **PowerShell:** Versão 7 (Core) recomendada, executado com privilégios de **Administrador**.

## 🛠 Instalação e Uso

1.  **Clone o repositório:**
    ```bash
    git clone https://github.com/fabiogiacomel/AdministradorRede.git
    cd AdministradorRede
    ```

2.  **Inicie o Agente:**
    Execute o script principal no PowerShell (como Admin):
    ```powershell
    .\0-Menu-Principal.ps1
    ```
    *O sistema verificará automaticamente a existência da imagem Docker `rede-master` e iniciará o build se necessário.*

## 📂 Estrutura de Arquivos

*   `0-Menu-Principal.ps1`: **Dashboard Central.** Ponto de partida para todas as operações.
*   `4-Discovery-IA.ps1`: Módulo de escaneamento e análise de vizinhança.
*   `5-Configurador-IoT.ps1`: Módulo de aplicação de configurações e *enforcement* de parâmetros.
*   `6-Seguranca-Rede.ps1`: Implementação dos algortimos *Watchdog* e *Dominó Reverso*.
*   `7-Ponte-Subrede.ps1`: Manipulação de adaptadores de rede Windows (`New-NetIPAddress`).
*   `instalador.ps1`: Script de setup inicial e build do Dockerfile.
*   `99-SOS-Rede.ps1`: Ferramenta de recuperação de emergência (DNS/Gateway).
*   `99-Robot-Teste.ps1`: Script de autoteste do sistema.

## ⚠️ Aviso Legal

Este software realiza alterações profundas na configuração de firmwares AirOS. Embora conte com mecanismos de segurança (`Watchdog`), o uso indevido pode resultar na perda de acesso remoto aos equipamentos. Recomenda-se testar em bancada antes da implantação em produção.

---
*Desenvolvido para fins de pesquisa e automação de infraestrutura crítica.*
