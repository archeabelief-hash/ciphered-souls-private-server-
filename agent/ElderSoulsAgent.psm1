$ErrorActionPreference = 'Stop'

$script:ElderSoulsBaseUrl = 'http://127.0.0.1:7780/api/v1'

function Set-ElderSoulsGateway {
    param([Parameter(Mandatory=$true)][string]$BaseUrl)
    $script:ElderSoulsBaseUrl = $BaseUrl.TrimEnd('/')
}

function Get-ESPlayers {
    Invoke-RestMethod -Method Get -Uri "$script:ElderSoulsBaseUrl/players"
}

function Get-ESSchema {
    Invoke-RestMethod -Method Get -Uri "$script:ElderSoulsBaseUrl/schema"
}

function Get-ESState {
    param([Parameter(Mandatory=$true)][string]$Player)
    $p = [uri]::EscapeDataString($Player)
    Invoke-RestMethod -Method Get -Uri "$script:ElderSoulsBaseUrl/state?player=$p"
}

function Invoke-ESAction {
    param(
        [Parameter(Mandatory=$true)][string]$Player,
        [Parameter(Mandatory=$true)][string]$Type,
        [hashtable]$Params = @{}
    )
    $pairs = @(
        'player=' + [uri]::EscapeDataString($Player),
        'type=' + [uri]::EscapeDataString($Type)
    )
    foreach ($key in $Params.Keys) {
        $pairs += ([uri]::EscapeDataString([string]$key) + '=' + [uri]::EscapeDataString([string]$Params[$key]))
    }
    $uri = "$script:ElderSoulsBaseUrl/action?" + ($pairs -join '&')
    Invoke-RestMethod -Method Post -Uri $uri
}

Export-ModuleMember -Function Set-ElderSoulsGateway,Get-ESPlayers,Get-ESSchema,Get-ESState,Invoke-ESAction
