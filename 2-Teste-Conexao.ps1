$gateway = "192.168.1.1"

Write-Host "=== TESTE 1: Conectividade Externa (Google DNS) ==="
docker run --rm rede-master ping -c 4 8.8.8.8

Write-Host "`n=== TESTE 2: Conectividade Local (Gateway: $gateway) ==="
Write-Host "Nota: Se falhar, pode exigir configuracao de rede adicional no Docker/WSL."
docker run --rm rede-master ping -c 4 $gateway
