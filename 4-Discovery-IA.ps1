# =============================================================================
# ARQUIVO: 4-Discovery-IA.ps1
# OBJETIVO: "O Olho de Deus" - Discovery Layer 2/3 e Analise de Sinal
# =============================================================================

# Importa as ferramentas de ponte (Gateway, Invoke-AirOSCommand)
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$PSScriptRoot\3-Wrapper-Comandos.ps1"

function Analisar-Candidato {
    <#
    .SYNOPSIS
        Conecta em uma antena candidata e avalia o espectro RF.
    #>
    param (
        [string]$Ip
    )

    Write-Host "   > Conectando via SSH no Agente ($Ip)..." -ForegroundColor DarkGray
    
    # Executa o comando de scan no rádio wifi (ath0)
    # Tenta 2 vezes caso o rádio esteja ocupado
    $rawOutput = Invoke-AirOSCommand -IpAlvo $Ip -ComandoAirOS "iwlist ath0 scan" -TimeoutSeconds 15

    if ([string]::IsNullOrWhiteSpace($rawOutput)) {
        return @{ Status = "ERRO de LEITURA"; Signal = "N/A"; SSID = "N/A" }
    }

    # Analise Regex (Busca o melhor sinal)
    # Padrao tipico AirOS: Signal level=-75 dBm
    $bestSignal = -999
    $bestSSID = "Nenhum"
    
    # Quebra por células para analisar cada AP visível
    $cells = $rawOutput -split "Cell \d+"
    
    foreach ($cell in $cells) {
        if ($cell -match "Signal level=(-\d+)") {
            $sigLevel = [int]$matches[1]
            
            # Extrai SSID
            $ssid = "Oculto"
            if ($cell -match 'ESSID:"([^"]+)"') { $ssid = $matches[1] }
            
            # Logica "Winner takes all": Guarda o melhor sinal encontrado
            if ($sigLevel -gt $bestSignal) {
                $bestSignal = $sigLevel
                $bestSSID = $ssid
            }
        }
    }

    # Veredito do Arquiteto
    # Regra: Signal > -75dBm (Ex: -60 eh Maior que -75)
    $status = "REJEITADO (Sinal Fraco)"
    if ($bestSignal -gt -75 -and $bestSignal -ne -999) {
        $status = "APROVADO"
    }
    elseif ($bestSignal -eq -999) {
        $status = "SEM SINAL / RADIO OFF"
    }

    return @{ 
        Status = $status; 
        Signal = "$bestSignal dBm"; 
        SSID   = $bestSSID 
    }
}

function Varredura-Inicial {
    Write-Host ">>> INICIANDO VARREDURA DE ESPECTRO (MODO: DISCOVERY) <<<`n" -ForegroundColor Cyan

    # 1. Detectar Rede Base
    $gw = Obter-GatewayLocal
    if (-not $gw) { 
        Write-Error "Impossivel rastrear rede sem Gateway."
        return 
    }
    
    # Assume mascara /24 padrao para teste (troca o ultimo octeto)
    $baseIP = $gw.Substring(0, $gw.LastIndexOf('.'))
    Write-Host "Alvo da Varredura: Sub-rede $baseIP.1 até $baseIP.20" -ForegroundColor Gray
    
    $foundCount = 0
    $approvedCount = 0

    # 2. Loop de Varredura (Ping Sweep rápido)
    1..20 | ForEach-Object {
        $target = "$baseIP.$_"
        
        # Feedback visual minimalista (pontos)
        Write-Host "." -NoNewline -ForegroundColor DarkGray
        
        if (Test-Connection -ComputerName $target -Count 1 -Quiet -BufferSize 16 -Delay 1) {
            Write-Host "`n[!] ALVO DETECTADO: $target" -ForegroundColor Yellow
            
            # Caso Especial: Antena de Fabrica
            if ($target -match "\.20$") {
                Write-Host "    >>> ALERTA: ANTENA VIRGEM (FACTORY DEFAULT) ENCONTRADA <<<" -ForegroundColor Magenta -BackgroundColor White
            }

            # 3. Analise Profunda (Inteligencia)
            Write-Host "    Solicitando telemetria..."
            $relatorio = Analisar-Candidato -Ip $target
            
            # Exibir Resultado
            if ($relatorio.Status -eq "APROVADO") {
                Write-Host "    VEREDITO: $($relatorio.Status)" -ForegroundColor Green
                Write-Host "    Melhor Torre: $($relatorio.SSID) ($($relatorio.Signal))" -ForegroundColor Green
                $approvedCount++
            }
            else {
                Write-Host "    VEREDITO: $($relatorio.Status)" -ForegroundColor Red
                Write-Host "    Dados: $($relatorio.SSID) ($($relatorio.Signal))" -ForegroundColor Gray
            }
            
            $foundCount++
        }
    }
    
    Write-Host "`n`n>>> RELATORIO FINAL <<<" -ForegroundColor Cyan
    Write-Host "Dispositivos Vivos: $foundCount"
    Write-Host "Candidatos Viaveis: $approvedCount"
    return @{ Found = $foundCount; Approved = $approvedCount }
}

# Auto-executa se chamado diretamente
if ($MyInvocation.InvocationName -notmatch "Menu") {
    Varredura-Inicial
}
