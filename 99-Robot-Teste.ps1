# =============================================================================
# ARQUIVO: 99-Robot-Teste.ps1
# OBJETIVO: Autoteste de Integridade do Sistema (Quality Assurance)
# =============================================================================

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ErrorActionPreference = "Stop"

function Print-Result {
    param ($Name, $Success, $Message)
    if ($Success) {
        Write-Host " [V] $Name" -ForegroundColor Green
    }
    else {
        Write-Host " [X] $Name - ERRO: $Message" -ForegroundColor Red
    }
}

Write-Host ">>> INICIANDO PROTOCOLO ROBOT DE TESTE <<<`n" -ForegroundColor Cyan

# --- TESTE 1: CORE DE REDE (Wrapper & Gateway) ---
$t1 = $false
$gw = $null
try {
    if (-not (Test-Path "$PSScriptRoot\3-Wrapper-Comandos.ps1")) { throw "Arquivo Wrapper nao encontrado." }
    
    # Importa suprimindo output
    . "$PSScriptRoot\3-Wrapper-Comandos.ps1" | Out-Null
    
    $gw = Obter-GatewayLocal
    
    if ([string]::IsNullOrWhiteSpace($gw)) { throw "Gateway retornou nulo." }
    if ($gw -match ":") { throw "Gateway IPv6 detectado ($gw). Filtro falhou." }
    if ($gw -notmatch "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") { throw "Formato de IP invalido ($gw)." }
    
    $t1 = $true
    Print-Result "Gateway IPv4 Limpo ($gw)" $true
}
catch {
    Print-Result "Core de Rede" $false $_
}

# --- TESTE 2: MUSCULO DOCKER ---
$t2 = $false
try {
    if (-not $gw) { throw "Teste ignorado por falha no Gateway." }
    
    Write-Host "     > Testando ping container..." -NoNewline -ForegroundColor DarkGray
    $res = docker run --rm rede-master ping -c 1 -W 2 $gw 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        $t2 = $true
        Write-Host "OK" -ForegroundColor DarkGray
        Print-Result "Docker Operacional" $true
    }
    else {
        throw "Container nao alcancou o gateway."
    }
}
catch {
    Print-Result "Musculo Docker" $false $_
}

# --- TESTE 3: PONTE DIMENSIONAL (Requer Admin) ---
$t3 = $false
try {
    if (-not (Test-Path "$PSScriptRoot\7-Ponte-Subrede.ps1")) { throw "Arquivo Ponte nao encontrado." }
    . "$PSScriptRoot\7-Ponte-Subrede.ps1" | Out-Null

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-Warning "Pulei Teste da Ponte (Requer Admin)."
        Print-Result "Ponte de Sub-rede" $true "IGNORADO (Sem Admin)"
    }
    else {
        # 1. Ativar
        Write-Host "     > Ativando ponte..." -NoNewline -ForegroundColor DarkGray
        Alternar-Ponte | Out-Null # Se ja estava ativa, ele remove. Se nao, ele ativa.
        
        # Como Alternar-Ponte eh toggle, precisamos garantir o estado conhecido.
        # Vamos forcar o estado para verificar.
        
        # Verifica se ligou ou desligou
        $status = Verificar-StatusPonte
        
        if ($status) {
            # Se ficou ativo, OK. Agora desativa.
            Alternar-Ponte | Out-Null
            if (Verificar-StatusPonte) { throw "Falha ao desativar a ponte." }
        }
        else {
            # Se ficou inativo, eh porque estava ativo antes e desligou. Liga de novo para testar.
            Alternar-Ponte | Out-Null
            if (-not (Verificar-StatusPonte)) { throw "Falha ao ativar a ponte." }
            # Limpa (Desliga)
            Alternar-Ponte | Out-Null
        }
        
        Write-Host "OK" -ForegroundColor DarkGray
        $t3 = $true
        Print-Result "Ponte de Sub-rede Funcional" $true
    }
}
catch {
    Print-Result "Ponte Dimensional" $false $_
}

# --- TESTE 4: INTEGRIDADE DOS SCRIPTS ---
$t4 = $true
$scripts = @("4-Discovery-IA.ps1", "5-Configurador-IoT.ps1")
foreach ($s in $scripts) {
    if (Test-Path "$PSScriptRoot\$s") {
        # Tenta validar sintaxe
        $syntaxError = Get-Command -Syntax "$PSScriptRoot\$s" 2>&1 
        if (-not $?) {
            $t4 = $false
            Print-Result "Arquivo $s" $false "Erro de Sintaxe"
        }
    }
    else {
        $t4 = $false
        Print-Result "Arquivo $s" $false "Nao encontrado"
    }
}

if ($t4) {
    Print-Result "Integridade dos Scripts" $true
}

Write-Host "`n>>> DIAGNOSTICO CONCLUIDO <<<" -ForegroundColor Cyan
