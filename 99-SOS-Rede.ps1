# =============================================================================
# ARQUIVO: 99-SOS-Rede.ps1
# OBJETIVO: BOTÃO DE PÂNICO - Restaurar Conectividade e DNS
# =============================================================================

Write-Host ">>> INICIANDO PROTOCOLO SOS DE REDE <<<" -ForegroundColor Red
Write-Host "Tentando restaurar a conexao com a internet..." -ForegroundColor Yellow

# 1. Identificar Interface Wi-Fi
$iface = Get-NetAdapter | Where-Object { $_.Name -match "Wi-Fi" } | Select-Object -First 1

if (-not $iface) {
    Write-Error "Nenhuma interface Wi-Fi encontrada!"
    return
}

$ifIdx = $iface.InterfaceIndex
Write-Host "Interface Alvo: $($iface.Name) (Index: $ifIdx)" -ForegroundColor Gray

# 2. Remover IP Alias Travado (192.168.1.222)
Write-Host "[-] Removendo IP Alias 192.168.1.222 (se existir)..."
try {
    Remove-NetIPAddress -InterfaceIndex $ifIdx -IPAddress "192.168.1.222" -Confirm:$false -ErrorAction SilentlyContinue
}
catch {
    # Ignora erro se nao existir
}

# 3. Limpar Cache DNS
Write-Host "[*] Limpando Cache DNS..."
Clear-DnsClientCache

# 4. Blindar DNS (Google + Cloudflare)
Write-Host "[+] Definindo DNS Blindado (8.8.8.8, 1.1.1.1)..." -ForegroundColor Cyan
try {
    Set-DnsClientServerAddress -InterfaceIndex $ifIdx -ServerAddresses ("8.8.8.8", "1.1.1.1") -ErrorAction Stop
}
catch {
    Write-Error "Falha ao definir DNS. Execute como ADMINISTRADOR."
    exit
}

# 5. Reiniciar Adaptador (Opcional, mas recomendado para 'flush' total)
Write-Host "[*] Reiniciando Adaptador Wi-Fi (Isso vai desconectar brevemente)..." -ForegroundColor Magenta
Restart-NetAdapter -Name $iface.Name

# 6. Validacao Final
Start-Sleep -Seconds 5
Write-Host "Validando conexao..."
try {
    $test = Test-NetConnection -ComputerName 8.8.8.8 -InformationLevel Quiet
    if ($test) {
        Write-Host ">>> SUCESSO: Internet Restaurada e DNS Blindado. <<<" -ForegroundColor Green
    }
    else {
        Write-Host ">>> FALHA: Ainda sem ping para 8.8.8.8. Verifique seu roteador. <<<" -ForegroundColor Red
    }
}
catch {
    Write-Error "Erro ao testar conexao."
}
