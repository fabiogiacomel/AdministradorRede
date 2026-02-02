# =============================================================================
# ARQUIVO: 0-Menu-Principal.ps1
# OBJETIVO: Orquestrador Central Completo - Administrador de Rede v6.0 (ROBOT)
# =============================================================================

# Carrega função de verificação de ponte
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$PSScriptRoot\7-Ponte-Subrede.ps1"

function Verificar-Imagem {
    $img = docker images -q rede-master
    return [bool]$img
}

# --- VERIFICAÇÃO DE PERMISSÃO (Admin Necessário para Ponte) ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# --- VERIFICAÇÃO INICIAL ---
if (-not (Verificar-Imagem)) {
    Clear-Host
    Write-Host "SISTEMA: Imagem 'rede-master' nao detectada." -ForegroundColor Yellow
    $resp = Read-Host "Deseja executar a INSTALACAO agora? (S/N)"
    if ($resp -match "^[SsYy]") {
        try { 
            .\instalador.ps1 
        }
        catch { 
            Write-Error $_ 
        }
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    else { 
        exit 
    }
}

# --- LOOP DO MENU ---
while ($true) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   PAINEL DE CONTROLE - REDE MASTER v6.0  " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # Status container
    if (Verificar-Imagem) { 
        Write-Host "Docker Img: " -NoNewline
        Write-Host "ONLINE" -ForegroundColor Green 
    }
    else { 
        Write-Host "Docker Img: " -NoNewline
        Write-Host "OFFLINE" -ForegroundColor Red 
    }

    # Status Ponte
    $ponteAtiva = Verificar-StatusPonte
    Write-Host "Ponte IP:   " -NoNewline
    if ($ponteAtiva) { 
        Write-Host "ATIVADA (192.168.1.222)" -ForegroundColor Green 
    }
    else { 
        Write-Host "DESATIVADA" -ForegroundColor DarkGray 
    }

    if (-not $isAdmin) { 
        Write-Host "`n[!] AVISO: Execute como ADMIN para controlar a Ponte." -ForegroundColor Red 
    }

    Write-Host ""
    Write-Host "[1] INICIAR VARREDURA (Discovery IA)"
    Write-Host "[2] Ferramentas de Rede (Testar Conexao)"
    Write-Host "[3] CONFIGURAR ANTENA (Padrao Unicornio)"
    Write-Host "[4] OPERACOES DE SEGURANCA (Watchdog & Domino)"
    Write-Host "[5] ATIVAR/DESATIVAR PONTE DE SUB-REDE"
    Write-Host ""
    Write-Host "[0] EXECUTAR AUTOTESTE DO SISTEMA (ROBOT)"
    Write-Host "[8] Reinstalar / Atualizar Ambiente"
    Write-Host "[9] SOS REDE (Restaurar Internet/DNS) - USE EM EMERGENCIA" -ForegroundColor Red
    Write-Host "[U] Desinstalar e Limpar"
    Write-Host "[Q] Sair"
    Write-Host ""
    
    $selection = Read-Host "Selecione uma opcao"

    switch ($selection) {
        "1" {
            Clear-Host
            try { .\4-Discovery-IA.ps1 } catch { Write-Error $_ }
            Write-Host "`nPressione qualquer tecla para voltar..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            Clear-Host
            .\2-Teste-Conexao.ps1
            Write-Host "`nPressione qualquer tecla para voltar..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "3" {
            Clear-Host
            Write-Host ">>> CONFIGURACAO REMOTA (PADRAO UNICORNIO) <<<" -ForegroundColor Yellow
            
            # Alerta Proativo
            if (-not $ponteAtiva) {
                Write-Host "[DICA] Se o alvo for 192.168.1.20, ative a Opcao 5 primeiro." -ForegroundColor Magenta
            }

            $ipAlvo = Read-Host "Digite o IP da Antena (ex: 192.168.1.20)"
            if ($ipAlvo -match "^\d+\.\d+\.\d+\.\d+$") {
                # Importa script para carregar a funcao no escopo atual
                . .\5-Configurador-IoT.ps1
                Aplicar-PadraoIoT -IpAlvo $ipAlvo
            }
            else { 
                Write-Host "IP Invalido." -ForegroundColor Red 
            }
            Write-Host "`nPressione qualquer tecla para voltar..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "4" {
            Clear-Host
            Write-Host ">>> OPERACOES DE SEGURANCA <<<"
            Write-Host " [A] Injetar Watchdog"
            Write-Host " [B] Migracao Domino"
            $subSel = Read-Host "Opcao"

            if ($subSel -eq "A") { 
                $ip = Read-Host "IP Alvo"
                .\6-Seguranca-Rede.ps1
                Injetar-Watchdog -IpAlvo $ip 
            }
            elseif ($subSel -eq "B") { 
                Write-Host "`nATENCAO: Digite os IPs do MAIS DISTANTE para o MAIS PROXIMO." -ForegroundColor Yellow
                $ipsRaw = Read-Host "Lista de IPs (separados por virgula)"
                $comando = Read-Host "Novo Comando (Ex: iwconfig ath0 channel 149)"
                
                if ($ipsRaw -and $comando) {
                    $lista = $ipsRaw -split "," | ForEach-Object { $_.Trim() }
                    .\6-Seguranca-Rede.ps1
                    Executar-DominoReverso -ListaIPs $lista -NovoComando $comando
                }
            }
            Write-Host "`nPressione qualquer tecla para voltar..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "5" {
            Clear-Host
            Alternar-Ponte
            Write-Host "`nPressione qualquer tecla..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "0" {
            Clear-Host
            .\99-Robot-Teste.ps1
            Write-Host "`nPressione qualquer tecla..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "8" { 
            Clear-Host
            .\instalador.ps1
            Write-Host "`nPressione qualquer tecla..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "9" { 
            Clear-Host
            .\99-SOS-Rede.ps1
            Write-Host "`nPressione qualquer tecla..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "U" { 
            Clear-Host
            .\uninstall.ps1
            if (-not (Verificar-Imagem)) { exit }
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "Q" { 
            # Limpeza segura
            docker container prune -f --filter "label=maintainer=rede-master" | Out-Null
            Write-Host "Sessao encerrada." -ForegroundColor Green
            exit 
        }
        "q" { 
            docker container prune -f --filter "label=maintainer=rede-master" | Out-Null
            Write-Host "Sessao encerrada." -ForegroundColor Green
            exit 
        }
        Default {
            Write-Host "Opcao invalida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
