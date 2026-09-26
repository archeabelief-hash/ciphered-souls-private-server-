param(
    [Parameter(Mandatory=$true)]
    [string]$Player,
    [int]$TickMs = 1200
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\ElderSoulsAgent.psm1" -Force

Write-Host "Elder Souls autonomous combat demo"
Write-Host "Player: $Player"
Write-Host "Gateway: http://127.0.0.1:7780"
Write-Host "Ctrl+C stops the agent."
Write-Host ""

$khopeshId = 29990
$equipped = $false

while ($true) {
    try {
        $s = Get-ESState -Player $Player
        $p = $s.player

        if (-not $equipped) {
            $already = $p.equipment | Where-Object { $_.id -eq $khopeshId } | Select-Object -First 1
            if ($already) {
                $equipped = $true
            } else {
                $khopesh = $p.inventory | Where-Object { $_.id -eq $khopeshId } | Select-Object -First 1
                if ($khopesh) {
                    Write-Host "Equipping Duat Khopesh from inventory slot $($khopesh.slot)"
                    Invoke-ESAction -Player $Player -Type equip -Params @{ slot = $khopesh.slot } | Out-Null
                    $equipped = $true
                    Start-Sleep -Milliseconds 800
                    continue
                }
            }
        }

        $target = $p.nearbyNpcs |
            Where-Object { $_.hp -gt 0 -and $_.combatLevel -ge 0 } |
            Sort-Object distance |
            Select-Object -First 1

        if ($target) {
            Write-Host ("Attack {0} [id={1}] distance={2} hp={3}/{4}" -f $target.name,$target.id,$target.distance,$target.hp,$target.maxHp)
            Invoke-ESAction -Player $Player -Type attack_npc -Params @{ npcId = $target.id } | Out-Null
        } else {
            $dx = Get-Random -Minimum -5 -Maximum 6
            $dy = Get-Random -Minimum -5 -Maximum 6
            $x = [int]$p.x + $dx
            $y = [int]$p.y + $dy
            Write-Host "No nearby NPC target. Walking toward $x,$y"
            Invoke-ESAction -Player $Player -Type walk -Params @{ x = $x; y = $y; maxSteps = 10 } | Out-Null
        }
    } catch {
        Write-Warning $_.Exception.Message
    }

    Start-Sleep -Milliseconds $TickMs
}
