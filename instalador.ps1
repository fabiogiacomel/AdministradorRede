# =============================================================================
# ARQUIVO: instalador.ps1
# OBJETIVO: Setup inicial do ambiente, verificacao de Docker e criacao de atalho
# =============================================================================

Write-Host ">>> INSTALADOR DO SISTEMA ADMINISTRADOR DE REDE <<<" -ForegroundColor Cyan

# 1. Verificacao de Requisitos (Docker)
Write-Host "Verificando estado do Docker..."
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker nao esta rodando." }
    Write-Host "[OK] Docker detectado e ativo." -ForegroundColor Green
}
catch {
    Write-Host "[ERRO] O Docker Desktop nao parece estar rodando." -ForegroundColor Red
    Write-Host "Por favor, inicie o Docker e tente novamente."
    exit 1
}

# 2. Build da Imagem
Write-Host "`n>>> Iniciando construcao do ambiente (rede-master)..."
try {
    .\1-Build-Ambiente.ps1
    if ($LASTEXITCODE -ne 0) { throw "Falha no script de build." }
}
catch {
    Write-Error "Erro critico na instalacao: $_"
    exit 1
}

# 3. Criacao de Atalho na Area de Trabalho
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutName = "Admin Rede - Painel.lnk"
$shortcutPath = Join-Path $desktopPath $shortcutName
$targetScript = (Get-Item ".\0-Menu-Principal.ps1").FullName
$projectDir = (Get-Item ".").FullName
$iconPath = "C:\Windows\System32\shell32.dll" # Icone generico de sistema

Write-Host "`n>>> Criando atalho em: $desktopPath"

try {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    
    # Configura para rodar via PowerShell com Bypass para evitar bloqueios
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$targetScript`""
    
    $shortcut.WorkingDirectory = $projectDir
    $shortcut.WindowStyle = 1 # 1=Normal, 3=Maximized, 7=Minimized
    $shortcut.Description = "Acesso Rapido ao Sistema Admin Rede"
    $shortcut.IconLocation = "$iconPath, 13" # Icone de rede/mundo
    $shortcut.Save()
    
    Write-Host "[OK] Atalho criado com sucesso." -ForegroundColor Green
}
catch {
    Write-Warning "Nao foi possivel criar o atalho automaticamente. Erro: $_"
}

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "   INSTALACAO CONCLUIDA. SISTEMA PRONTO.       " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Voce pode iniciar pelo atalho na Area de Trabalho."
