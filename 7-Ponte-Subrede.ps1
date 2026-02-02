# =============================================================================
# ARQUIVO: 7-Ponte-Subrede.ps1
# OBJETIVO: Resolver mismatch de Subnet (192.168.3.x vs 192.168.1.x)
# VERSAO: 3.0 (DNS Safe - Blindagem Contra Perda de Internet)
# =============================================================================

# Configuracoes do IP Alias Temporario
$AliasIP = "192.168.1.222"
$AliasMask = 24 # 255.255.255.0

function Obter-InterfaceAtiva {
    <#
    .SYNOPSIS
        Tenta identificar a interface de rede principal com logica de prioridade.
        Fallback manual em caso de falha.
    #>
    
    # 1. Prioridade Maxima: Wi-Fi Explicito
    $iface = Get-NetAdapter | Where-Object { $_.Name -eq "Wi-Fi" -and $_.Status -eq "Up" }
    if ($iface) { return $iface }

    # 2. Prioridade Secundaria: Ethernet
    $iface = Get-NetAdapter | Where-Object { $_.Name -like "*Ethernet*" -and $_.Status -eq "Up" } | Select-Object -First 1
    if ($iface) { return $iface }

    # 3. Prioridade Terciaria: Qualquer coisa "Up" (ex: VPN, Bridge, etc)
    # Exclui interfaces virtuais de Loopback se nao forem o unico recurso
    $iface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Loopback*" } | Select-Object -First 1
    if ($iface) { return $iface }

    # 4. Ultimo Recurso: Selecao Manual pelo Usuario
    Write-Warning "AVISO: Auto-deteccao de rede falhou."
    Write-Host "Interfaces Disponiveis:" -ForegroundColor Cyan
    Get-NetAdapter | Select-Object ifIndex, Name, Status, InterfaceDescription | Format-Table -AutoSize
    
    $inputIdx = Read-Host "Digite o numero do 'ifIndex' da sua internet"
    if ($inputIdx) {
        try {
            return Get-NetAdapter -InterfaceIndex $inputIdx -ErrorAction Stop
        }
        catch {
            Write-Error "Indice invalido."
        }
    }

    return $null
}

function Verificar-StatusPonte {
    $iface = Obter-InterfaceAtiva
    if (-not $iface) { return $false }

    # Verifica se o IP Alias ja existe nessa interface
    $exists = Get-NetIPAddress -InterfaceIndex $iface.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $AliasIP }
    return [bool]$exists
}

function Alternar-Ponte {
    $iface = Obter-InterfaceAtiva
    if (-not $iface) {
        Write-Error "Impossivel prosseguir sem uma interface de rede valida."
        return
    }

    $ifIdx = $iface.InterfaceIndex
    $aliasName = $iface.Name

    Write-Host "Interface Selecionada: $aliasName (Index: $ifIdx)" -ForegroundColor Gray

    # Checa estado atual
    if (Verificar-StatusPonte) {
        # --- REMOVER ---
        Write-Host ">>> DESATIVANDO PONTE DE SUB-REDE ($AliasIP) <<<" -ForegroundColor Yellow
        try {
            Remove-NetIPAddress -InterfaceIndex $ifIdx -IPAddress $AliasIP -PrefixLength $AliasMask -Confirm:$false -ErrorAction Stop
            Write-Host "[OK] IP Alias removido. Voce nao acessa mais a rede 192.168.1.x." -ForegroundColor Green
        }
        catch {
            Write-Error "Falha ao remover IP. Tente executar o Menu como ADMINISTRADOR."
            Write-Error $_
        }
    }
    else {
        # --- ADICIONAR ---
        Write-Host ">>> ATIVANDO PONTE DE SUB-REDE ($AliasIP) <<<" -ForegroundColor Cyan
        try {
            New-NetIPAddress -InterfaceIndex $ifIdx -IPAddress $AliasIP -PrefixLength $AliasMask -ErrorAction Stop | Out-Null
            
            # --- BLINDAGEM DE DNS (Versao 3.0) ---
            # Forca DNS confiavel para evitar que o Windows tente usar o da sub-rede vazia
            Write-Host "[DNS] Aplicando servidores globais (8.8.8.8, 1.1.1.1)..." -ForegroundColor Cyan
            Set-DnsClientServerAddress -InterfaceIndex $ifIdx -ServerAddresses ("8.8.8.8", "1.1.1.1")
            
            Write-Host "[OK] Ponte Criada com Sucesso!" -ForegroundColor Green
            Write-Host "Agora sua maquina acessa .3.x e .1.x simultaneamente." -ForegroundColor Gray
            Write-Host "OBS: Antenas de fabrica (192.168.1.20) agora estao visiveis." -ForegroundColor Magenta
        }
        catch {
            Write-Error "FALHA ao adicionar IP. EH NECESSARIO RODAR COMO ADMINISTRADOR."
            Write-Error "Detalhe: $_"
        }
    }
}

# Auto-executa switch se chamado diretamente, mas permite importacao
if ($MyInvocation.InvocationName -notmatch "Menu") {
    Alternar-Ponte
}
