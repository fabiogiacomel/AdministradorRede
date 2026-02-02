Write-Host ">>> CICLO DE BUILD: REDE-MASTER <<<" -ForegroundColor Cyan

# 1. Limpeza Prévia da Imagem Específica
Write-Host "Verificando existência de imagem anterior..."
$imgId = docker images -q rede-master
if ($imgId) {
    Write-Host "Detectada imagem antiga ($imgId). Removendo..."
    docker rmi rede-master -f | Out-Null
    Write-Host "Imagem antiga removida." -ForegroundColor Gray
}

# 2. Execução do Build
Write-Host "Iniciando construção da nova imagem..."
docker build -t rede-master .

if ($?) {
    Write-Host "Build CONCLUÍDO com sucesso." -ForegroundColor Green
    
    # 3. Limpeza de Imagens 'Dangling' (Lixo de build)
    # Remove apenas imagens sem tag (dangling) para economizar espaço
    # O filtro dangling=true garante que não apagamos imagens válidas de outros projetos
    Write-Host "Limpando camadas intermediárias (dangling images)..."
    docker image prune -f | Out-Null
}
else {
    Write-Host "ERRO CRÍTICO: Falha no build." -ForegroundColor Red
    exit 1
}
