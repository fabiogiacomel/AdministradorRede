# =============================================================================
# ARQUIVO: 3-Wrapper-Comandos.ps1
# OBJETIVO: Abstracao "A Ponte" entre Windows (PowerShell) e Linux (Container)
# VERSAO: 4.0 (Correcão WMI Hardcoded)
# =============================================================================

function Obter-GatewayLocal {
    <#
    .SYNOPSIS
        Detecta automaticamente o Gateway padrao IPv4 (APENAS IPV4).
        Refatorado para priorizar WMI em cenarios de rede Hibrida/IPv6.
    #>
    
    Write-Verbose "Iniciando deteccao de Gateway IPv4..."

    # --- TENTATIVA 1: WMI (Mais consistente para listar Gateways IPv4 em adapters mistos) ---
    try {
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" -ErrorAction SilentlyContinue
        foreach ($nic in $adapters) {
            if ($nic.DefaultIPGateway) {
                foreach ($gw in $nic.DefaultIPGateway) {
                    # O WMI retorna array de strings. Se tiver '.', e IPv4.
                    if ($gw -and $gw -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                        if ($gw -ne "0.0.0.0") {
                            return $gw
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Metodo WMI falhou."
    }

    # --- TENTATIVA 2: NET IP CONFIGURATION (Se WMI falhar) ---
    try {
        $configs = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq "Up" }
        foreach ($cfg in $configs) {
            if ($cfg.IPv4DefaultGateway) {
                $gwObj = $cfg.IPv4DefaultGateway | Select-Object -First 1
                if ($gwObj.NextHop) {
                    return $gwObj.NextHop
                }
            }
        }
    }
    catch {
        Write-Verbose "Metodo NetIP falhou."
    }

    # --- FALLBACK: Verificar Roteamento Direto ---
    try {
        $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Sort-Object Metric | Select-Object -First 1
        if ($route.NextHop -and $route.NextHop -ne "0.0.0.0") {
            return $route.NextHop
        }
    }
    catch {}

    # --- NIVEL 3: FALLBACK HARDCODED (Ultimo Recurso) ---
    Write-Warning "FALHA CRITICA DE REDE: Nenhum Gateway IPv4 puro encontrado."
    Write-Warning "Assumindo padrao de fabrica Ubiquiti: 192.168.1.1"
    return "192.168.1.1"
}

function Invoke-AirOSCommand {
    <#
    .SYNOPSIS
        Executa comando remoto via container, com verificação de imagem.
    #>
    param (
        [Parameter(Mandatory = $true)] [string]$IpAlvo,
        [Parameter(Mandatory = $true)] [string]$ComandoAirOS,
        [string]$Usuario = "ubnt",
        [string]$Senha = "ubnt",
        [int]$TimeoutSeconds = 10
    )

    # SEGURANCA: Verifica disponibilidade da imagem antes de tentar rodar
    if (-not (docker images -q rede-master)) {
        Write-Error "IMAGEM DUVIDOSA: 'rede-master' nao encontrada. Execute '0-Menu-Principal.ps1' para corrigir."
        return $null
    }

    # ADAPTACAO LEGADA: Forca algoritmos antigos (rsa) para Antenas Ubiquiti antigas
    $legacyOps = "-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa"
    $sshCmd = "sshpass -p '$Senha' ssh $legacyOps -o StrictHostKeyChecking=no -o ConnectTimeout=$TimeoutSeconds $Usuario@$IpAlvo '$ComandoAirOS'"

    Write-Verbose "Executando comando remoto em $IpAlvo via Container..."
    
    try {
        # Executa container temporário
        $resultado = docker run --rm rede-master bash -c $sshCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Falha na execucao remota ou timeout: $resultado"
            # O retorno pode ser vazio se for erro de conexao, entao retornamos null
            return $null
        }
        return $resultado
    }
    catch {
        Write-Error "Exception ao invocar Docker: $_"
        return $null
    }
}

# =============================================================================
# FIM DO ARQUIVO
# =============================================================================
