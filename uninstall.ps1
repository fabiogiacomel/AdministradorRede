# =============================================================================
# ARQUIVO: uninstall.ps1
# OBJETIVO: Protocolo de Limpeza - Remove artefatos do Docker e atalhos
# =============================================================================

Write-Host ">>> PROTOCOLO DE DESINSTALACAO E LIMPEZA <<<" -ForegroundColor Red
Write-Host "Atencao: Isso removera containers e imagem 'rede-master' do sistema."
Write-Host "O codigo-fonte (scripts) SERA PRESERVADO."

$confirm = Read-Host "`nTem certeza que deseja continuar? (S/N)"
if ($confirm -notmatch "^[SsYy]") {
    Write-Host "Operacao cancelada." -ForegroundColor Yellow
    exit
}

# 1. Parar e Remover Containers
Write-Host "`n[1/4] Buscando containers ativos..."
$containers = docker ps -a -q --filter "ancestor=rede-master"
if ($containers) {
    Write-Host "Parando e removendo containers ($containers)..." -ForegroundColor Yellow
    docker stop $containers 2>$null
    docker rm $containers -f 2>$null
}
else {
    Write-Host "Nenhum container ativo encontrado." -ForegroundColor Gray
}

# 2. Remover Imagem
Write-Host "`n[2/4] Removendo imagem 'rede-master'..."
if (docker images -q rede-master) {
    docker rmi rede-master -f
    if ($?) {
        Write-Host "Imagem removida com sucesso." -ForegroundColor Green
    }
    else {
        Write-Host "Aviso: Falha ao remover imagem (pode estar em uso ou ja removida)." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Imagem 'rede-master' nao encontrada." -ForegroundColor Gray
}

# 3. Remover Atalho
Write-Host "`n[3/4] Removendo atalho da Area de Trabalho..."
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutInfo = Join-Path $desktopPath "Admin Rede - Painel.lnk"
if (Test-Path $shortcutInfo) {
    Remove-Item $shortcutInfo -Force
    Write-Host "Atalho removido." -ForegroundColor Green
}
else {
    Write-Host "Atalho nao encontrado." -ForegroundColor Gray
}

# 4. Limpeza Final (Opcional - Prune especifico se necessario, aqui evitamos global prune por seguranca)

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "   LIMPEZA CONCLUIDA. O DOCKER ESTA LIMPO.     " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Os scripts de codigo fonte permanecem na pasta atual."
