param(
    [Parameter(Mandatory=$true)]
    [string]$Player,
    [string]$Model = $env:ELDER_SOULS_LLM_MODEL,
    [string]$ApiUrl = $env:ELDER_SOULS_LLM_URL,
    [string]$ApiKey = $env:ELDER_SOULS_LLM_API_KEY,
    [int]$TickMs = 1500
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\ElderSoulsAgent.psm1" -Force

if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
    throw 'Set ELDER_SOULS_LLM_URL to an OpenAI-compatible chat-completions endpoint.'
}
if ([string]::IsNullOrWhiteSpace($Model)) {
    throw 'Set ELDER_SOULS_LLM_MODEL to the model name exposed by your endpoint.'
}

$system = @"
You are the autonomous controller for a character in the local Elder Souls Scape test game.
You receive authoritative structured game state. Choose exactly ONE action each turn.
Return ONLY one compact JSON object, no markdown and no prose.

Allowed action shapes:
{"type":"walk","x":2539,"y":4712,"maxSteps":10}
{"type":"attack_npc","npcId":123}
{"type":"equip","slot":0}
{"type":"bank_open"}
{"type":"bank_deposit_all"}
{"type":"bank_deposit","slot":0,"amount":1}
{"type":"bank_withdraw","itemId":29990,"amount":1}
{"type":"state"}

Priorities:
1. Stay alive.
2. Equip useful gear when available.
3. Fight reasonable nearby targets.
4. Explore when no target is available.
5. Never invent coordinates, item IDs, NPC IDs or inventory slots that are not supported by the supplied state.
This is a local private test world, not the public RuneScape service.
"@

Write-Host "Elder Souls LLM Agent"
Write-Host "Player: $Player"
Write-Host "Model: $Model"
Write-Host "Endpoint: $ApiUrl"
Write-Host "Ctrl+C stops the agent."
Write-Host ""

while ($true) {
    try {
        $state = Get-ESState -Player $Player
        $stateJson = $state | ConvertTo-Json -Depth 12 -Compress

        $body = @{
            model = $Model
            temperature = 0.2
            messages = @(
                @{ role = 'system'; content = $system },
                @{ role = 'user'; content = "CURRENT_GAME_STATE=$stateJson" }
            )
        } | ConvertTo-Json -Depth 8

        $headers = @{}
        if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
            $headers.Authorization = "Bearer $ApiKey"
        }

        $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -Headers $headers -ContentType 'application/json' -Body $body
        $raw = [string]$response.choices[0].message.content
        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw 'Model returned no action.'
        }

        $action = $raw.Trim() | ConvertFrom-Json
        $type = [string]$action.type
        if ([string]::IsNullOrWhiteSpace($type)) {
            throw "Model action has no type: $raw"
        }

        $params = @{}
        foreach ($prop in $action.PSObject.Properties) {
            if ($prop.Name -ne 'type') {
                $params[$prop.Name] = $prop.Value
            }
        }

        Write-Host ("AI -> {0} {1}" -f $type, (($params | ConvertTo-Json -Compress)))
        $result = Invoke-ESAction -Player $Player -Type $type -Params $params
        Write-Host ("GAME <- " + ($result | ConvertTo-Json -Compress))
    } catch {
        Write-Warning $_.Exception.Message
    }

    Start-Sleep -Milliseconds $TickMs
}
