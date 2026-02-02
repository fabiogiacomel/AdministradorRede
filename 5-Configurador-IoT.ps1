# =============================================================================
# ARQUIVO: 5-Configurador-IoT.ps1
# OBJETIVO: "A Expansao" - Padronizacao de Antenas (MASTER-BLASTER v3.0 - POWER-PIPE)
# METODO: Download -> Powershell Processing -> Upload via Pipe -> Apply
# =============================================================================

# ImportaWrapper
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$PSScriptRoot\3-Wrapper-Comandos.ps1"

function Obter-MAC-Remoto {
    param($Ip, $Usuario, $Senha)
    $cmd = "cat /sys/class/net/ath0/address"
    $mac = Invoke-AirOSCommand -IpAlvo $Ip -ComandoAirOS $cmd -Usuario $Usuario -Senha $Senha -TimeoutSeconds 5
    if ($mac -and $mac -notmatch "Error" -and [string]$mac -match "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$") {
        return ([string]$mac).Trim()
    }
    return "00:00:00:00:00:00"
}

function Aplicar-PadraoIoT {
    param (
        [Parameter(Mandatory = $true)] [string]$IpAlvo,
        [string]$SenhaAtual = "ubnt"
    )

    Write-Host ">>> CONFIGURADOR AVANCADO v3.0 (POWER-PIPE) <<<" -ForegroundColor Cyan

    # --- 1. SELETOR DE MODO ---
    Write-Host "`n[PASSO 1] MODELO OPERACIONAL:"
    Write-Host " [M] MESTRE (AP/Casa/Cabo) -> 5180MHz (Ch 36)"
    Write-Host " [C] CLIENTE (Station/Pasto)"
    $papel = Read-Host "Opcao (M/C)"
    
    $modoOp = "sta"
    $modoDesc = "CLIENTE (Station)"
    $freq = "0" 
    $ipSufix = "CLI"

    if ($papel -match "^[Mm]") {
        $modoOp = "ap"
        $modoDesc = "MESTRE (Access Point)"
        $freq = "5180" 
        $ipSufix = "MST"
    }

    # --- 2. SELETOR DE IP ---
    Write-Host "`n[PASSO 2] REDE:"
    $novoIp = Read-Host " NOVO IP (Enter p/ manter $IpAlvo)"
    $alterarIp = ($novoIp -match "^\d+\.\d+\.\d+\.\d+$")

    # 3. Identificacao
    Write-Host "   > Lendo MAC..."
    $macFull = Obter-MAC-Remoto -Ip $IpAlvo -Usuario "ubnt" -Senha $SenhaAtual
    $macSuffix = $macFull.Split(":")[-2..-1] -join "" 
    $novoNome = "Node-$ipSufix-$macSuffix"
    Write-Host "   > Hostname Proposto: $novoNome" -ForegroundColor Yellow

    # --- 4. ENGINE DE PROCESSAMENTO (POWER-PIPE) ---
    Write-Host "   > [1/4] Baixando Configuração (SSH)..."
    
    # Baixa system.cfg raw via Wrapper/Docker
    # Executa cat no remoto e captura o output
    $rawConfig = Invoke-AirOSCommand -IpAlvo $IpAlvo -ComandoAirOS "cat /tmp/system.cfg" -Senha $SenhaAtual
    
    if (-not $rawConfig -or $rawConfig.Length -lt 100) {
        Write-Error "Falha critica ao baixar config ou arquivo corrompido."
        return
    }

    Write-Host "   > [2/4] Processando em Memoria (Powershell)..."
    
    $lines = $rawConfig -split "`n"
    
    # Filtro Negativo: Remove tudo que vamos substituir
    $cleanLines = $lines | Where-Object { 
        $_ -notmatch "wireless.1.ssid" -and 
        $_ -notmatch "wireless.1.security" -and 
        $_ -notmatch "wireless.1.wpa" -and
        $_ -notmatch "wireless.1.wds" -and
        $_ -notmatch "radio.1.chwidth" -and
        $_ -notmatch "radio.1.freq" -and
        $_ -notmatch "wireless.1.mode" -and
        $_ -notmatch "system.name" -and
        $_ -notmatch "resolv.host.1.name" -and
        $_ -notmatch "netconf.3.ip" -and
        $_ -notmatch "netconf.3.netmask" -and
        $_ -notmatch "dhcpc.1.status" -and
        $_ -notmatch "route.1.gateway"
    }

    # Injeta Novos Valores (Lista Limpa)
    # Parametros Radio/System
    $cleanLines += "wireless.1.ssid=Internet"
    $cleanLines += "wireless.1.security.type=wpa2-aes"
    $cleanLines += "wireless.1.wpa.psk=unicornio"
    $cleanLines += "radio.1.chwidth=10"
    $cleanLines += "radio.1.freq=$freq"
    $cleanLines += "wireless.1.mode=$modoOp"
    $cleanLines += "wireless.1.wds.status=enabled"
    $cleanLines += "system.name=$novoNome"
    $cleanLines += "resolv.host.1.name=$novoNome"

    # Parametros IP
    if ($alterarIp) {
        $targetIp = $novoIp
        $dhcpStatus = "disabled"
    }
    else {
        # Se nao mudou IP, mantem o antigo? Precisamos saber qual era.
        # Melhor: Se nao mudou, REINSERE o que estava no $IpAlvo (que eh o atual).
        $targetIp = $IpAlvo
        $dhcpStatus = "disabled" # Forcamos estatico for safety
    }
    
    $cleanLines += "netconf.3.ip=$targetIp"
    $cleanLines += "netconf.3.netmask=255.255.255.0"
    $cleanLines += "dhcpc.1.status=$dhcpStatus"
    $cleanLines += "route.1.gateway=192.168.1.1"

    # Salva Temp Local
    $tempFile = "$env:TEMP\sys_upload_$macSuffix.cfg"
    $cleanLines -join "`n" | Out-File -Encoding ASCII $tempFile

    Write-Host "   > [3/4] Upload da Nova Config (Stream Docker volume)..."
    
    # Usa um container worker para fazer o upload via volume mount
    # O arquivo está em $tempFile (Windows Path)
    # Montamos $env:TEMP em /mule
    $tempDir = $env:TEMP
    $fName = "sys_upload_$macSuffix.cfg"
    
    $sshOpts = "-o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
    
    # Upload via cat pipe (Robustez contra SFTP missing)
    docker run --rm -v "${tempDir}:/mule" rede-master bash -c "cat /mule/$fName | sshpass -p '$SenhaAtual' ssh $sshOpts $Usuario@$IpAlvo 'cat > /tmp/system.cfg'" 2>&1 | Out-Null
    
    Write-Host "   > [4/4] Gravacao e Reboot..."
    Invoke-AirOSCommand -IpAlvo $IpAlvo -ComandoAirOS "cfgmtd -f /tmp/system.cfg -w -p /etc/; reboot" -Senha $SenhaAtual -TimeoutSeconds 10
    
    Write-Host "   > [SUCESSO] Operacao Concluida." -ForegroundColor Green
    if ($alterarIp) { Write-Host "   > Alvo migrado para: $targetIp" -ForegroundColor Magenta }
}
