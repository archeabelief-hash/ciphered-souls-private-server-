$ErrorActionPreference = 'Stop'
function DriveGet([string]$id,[string]$out) {
  $u = "https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t"
  curl.exe -L --fail --retry 5 --retry-delay 3 -o $out $u
  if ($LASTEXITCODE -ne 0) { throw "Download failed: $id" }
}
New-Item -ItemType Directory -Force recovered/server/.git/objects/pack,recovered/client/.git/objects/pack | Out-Null
git -C recovered/server init | Out-Null
git -C recovered/client init | Out-Null
DriveGet '1yao606p_04R7yXH9vsdMitsLz1t-LB79' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.pack'
DriveGet '1z_1DeNJMqx70GNjvlnOqL3FQThDmqaC3' 'recovered/server/.git/objects/pack/pack-a0e3d5d13ccfe8addde9e81f30decc1fcb0b493f.idx'
DriveGet '1mwe-bKDWPu5NQzHr3_XDI26F9wCdSZmN' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.pack'
DriveGet '1e1-m-k3Skp43JE25_zz1TOkPPrzM5btb' 'recovered/client/.git/objects/pack/pack-aba9cc70f6092791ec6dbc4d5f3539166095e495.idx'
git -C recovered/server reset --hard 61999df3c7a90e50b8ffb7000433d09d621c2ac7 | Out-Null
git -C recovered/client reset --hard 6fcd5e3f9e2bf360b53832090558fadb5d17ab11 | Out-Null
$patterns=@('getAttackSpeed','SLOT_WEAPON','ItemBonuses','getBonuses','getEquipSlot','getEquipmentSlot','getCombatDefinitions','getRequirements','wearItem','equipItem','ItemDefinitions','ItemConfig','maxHit','HitLook.MELEE_DAMAGE','applyHit','setNextAnimation')
"=== SERVER MATCHES ==="
foreach($p in $patterns) {
  "--- $p ---"
  Get-ChildItem recovered/server/src/main/java -Recurse -Filter *.java | Select-String -Pattern $p | Select-Object -First 30 | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
}
"=== CLIENT MATCHES ==="
foreach($p in @('ItemDefinitions','ItemConfig','inventoryModel','maleEquip','femaleEquip','modelId','equip','wear')) {
  "--- $p ---"
  Get-ChildItem recovered/client/src/main/java -Recurse -Filter *.java | Select-String -Pattern $p | Select-Object -First 30 | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
}

"=== ITEMCONFIG HEAD ==="
Get-Content recovered/client/src/main/java/ItemConfig.java | Select-Object -First 260
"=== CLASS477 HEAD ==="
Get-Content recovered/client/src/main/java/Class477.java | Select-Object -First 220
"=== CLIENT CUSTOMITEMS COPY/EXAMPLES ==="
Get-Content recovered/client/src/main/java/CustomItems.java | Select-Object -First 620
"=== SERVER CUSTOMITEMS HEAD ==="
$sc=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter CustomItems.java | Select-Object -First 1).FullName
if($sc){ Get-Content $sc | Select-Object -First 500 }
"=== PLAYER START AREA ==="
$pp='recovered/server/src/main/java/com/rs/game/player/Player.java'
$pl=Get-Content $pp
$match=Select-String -Path $pp -Pattern 'public void start\(\)' | Select-Object -First 1
if($match){$s=[Math]::Max(0,$match.LineNumber-5);$pl | Select-Object -Skip $s -First 90}
