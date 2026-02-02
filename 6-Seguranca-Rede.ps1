# =============================================================================
# ARQUIVO: 6-Seguranca-Rede.ps1
# OBJETIVO: "A Seguranca" - Watchdog Timer e Migracao em Domino (Fire & Forget)
# =============================================================================

# Importa Wrapper
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$PSScriptRoot\3-Wrapper-Comandos.ps1"

function Injetar-Watchdog {
    <#
    .SYNOPSIS
        Instala um 'Seguro de Vida' na antena. 
        Se apos o reboot a antena nao pingar o Gateway em 10 min, ela restaura o backup.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$IpAlvo,
        [string]$Usuario = "ubnt",
        [string]$Senha = "ubnt"
    )

    Write-Host "   > [SEGURANCA] Injetando Watchdog em $IpAlvo..." -ForegroundColor Yellow

    # Script de Recuperação (Shell Script Linux)
    # 1. Faz backup da config ATUAL (que sabemos que funciona) para Persistent
    # 2. Cria o script que roda no boot
    
    $scriptWatchdog = @"
#!/bin/sh
# --- REDE MASTER WATCHDOG ---
sleep 600
GW=\$(route -n | grep ^0.0.0.0 | awk '{print \$2}')
if ! ping -c 3 \$GW; then
    cp /etc/persistent/system.cfg.safe /tmp/system.cfg
    cfgmtd -f /tmp/system.cfg -w -p /etc/
    reboot
fi
"@

    # Comandos para aplicar na antena
    $cmds = @(
        # 1. Salvar estado seguro atual
        "cp /tmp/system.cfg /etc/persistent/system.cfg.safe",
        
        # 2. Criar script de watchdog
        "echo '$scriptWatchdog' > /etc/persistent/watchdog_master.sh",
        "chmod +x /etc/persistent/watchdog_master.sh",
        
        # 3. Adicionar ao boot (rc.poststart) se não estiver lá
        "grep -q 'watchdog_master.sh' /etc/persistent/rc.poststart || echo '/etc/persistent/watchdog_master.sh &' >> /etc/persistent/rc.poststart",
        "chmod +x /etc/persistent/rc.poststart",
        
        # 4. Gravar na Flash (Persistencia)
        "cfgmtd -w -p /etc/"
    )

    $fullCmd = $cmds -join "; "
    
    $res = Invoke-AirOSCommand -IpAlvo $IpAlvo -ComandoAirOS $fullCmd -Usuario $Usuario -Senha $Senha -TimeoutSeconds 20
    
    if ($res -ne $null) {
        Write-Host "   > [OK] Watchdog Armado e Configuração Segura salva." -ForegroundColor Green
    }
    else {
        Write-Host "   > [FALHA] Não foi possível armar o Watchdog." -ForegroundColor Red
    }
}

function Executar-DominoReverso {
    <#
    .SYNOPSIS
        Itera sobre uma lista de IPs (Longe -> Perto) aplicando comandos e rebootando.
    #>
    param (
        [Parameter(Mandatory = $true)] [string[]]$ListaIPs,
        [Parameter(Mandatory = $true)] [string]$NovoComando,
        [string]$Senha = "ubnt"
    )

    Write-Host ">>> INICIANDO OPERACAO DOMINO REVERSO <<<" -ForegroundColor User
    Write-Host "ATENCAO: Operacao 'Fire and Forget'. A conexao caira a cada passo." -ForegroundColor Red
    
    foreach ($ip in $ListaIPs) {
        Write-Host "`nTarget Atual: $ip" -ForegroundColor Cyan
        
        # 1. Armar Watchdog (Seguranca Primeiro)
        Injetar-Watchdog -IpAlvo $ip -Senha $Senha
        
        # 2. Executar Comando Critico + Reboot
        Write-Host "   > Enviando Payload..."
        
        # Adiciona reboot ao final do comando se não houver
        $payload = "$NovoComando"
        if ($payload -notmatch "reboot") { $payload += "; reboot" }

        # Executa sem esperar retorno confiavel (timeout baixo pois vai desconectar)
        Invoke-AirOSCommand -IpAlvo $ip -ComandoAirOS $payload -Senha $Senha -TimeoutSeconds 5
        
        Write-Host "   > Payload enviado. dispositivo deve estar reiniciando." -ForegroundColor Gray
        
        # 3. Delay Tatico para propagacao (evita cortar a propria perna)
        Write-Host "   > Aguardando 30s antes de derrubar o proximo no..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 30
    }
    
    Write-Host "`n>>> OPERACAO DOMINO FINALIZADA <<<" -ForegroundColor Green
}
