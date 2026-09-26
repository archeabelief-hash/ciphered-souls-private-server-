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

"=== AGENT GATEWAY HOOKS ==="
$serverFiles = Get-ChildItem recovered/server/src/main/java -Recurse -Filter *.java
foreach($p in @(
  'new PlayerCombat\(',
  'addWalkSteps\(',
  'Equipment\.sendWear',
  'sendWear\(',
  'getInventory\(\)\.getItems',
  'getEquipment\(\)\.getItems',
  'World\.getNPCs\(',
  'getHitpoints\(\)',
  'getSkills\(\)\.getLevel',
  'getX\(\)',
  'getY\(\)',
  'getPlane\(\)',
  'getUsername\(\)',
  'getPlayers\(',
  'getActionManager\(\)\.setAction',
  'InventoryOptionsHandler',
  'PlayerCombat'
)) {
  "--- $p ---"
  $serverFiles | Select-String -Pattern $p | Select-Object -First 80 | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
}
"=== WORLD HEAD ==="
$wf=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter World.java | Select-Object -First 1).FullName
if($wf){Get-Content $wf | Select-Object -First 260}
"=== EQUIPMENT HEAD ==="
$ef=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Equipment.java | Select-Object -First 1).FullName
if($ef){Get-Content $ef | Select-Object -First 360}
"=== PLAYERCOMBAT HEAD ==="
$pc=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter PlayerCombat.java | Select-Object -First 1).FullName
if($pc){Get-Content $pc | Select-Object -First 260}
"=== INVENTORY HEAD ==="
$inv=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Inventory.java | Select-Object -First 1).FullName
if($inv){Get-Content $inv | Select-Object -First 360}
"=== ACTION MANAGER HEAD ==="
$am=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter ActionManager.java | Select-Object -First 1).FullName
if($am){Get-Content $am | Select-Object -First 260}
"=== NPC HEAD ==="
$nf=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter NPC.java | Select-Object -First 1).FullName
if($nf){Get-Content $nf | Select-Object -First 260}

"=== AGENT EXACT SECTIONS ==="
$gl=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter GameLauncher.java | Select-Object -First 1).FullName
if($gl) {
  "--- GameLauncher main/init ---"
  $gll=Get-Content $gl
  $m=Select-String -Path $gl -Pattern 'public static void main' | Select-Object -First 1
  if($m){$gll | Select-Object -Skip ([Math]::Max(0,$m.LineNumber-5)) -First 220}
}
$world=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter World.java | Select-Object -First 1).FullName
if($world){
  "--- World getters ---"
  Select-String -Path $world -Pattern 'getPlayers\(|getNPCs\(' -Context 4,8 | ForEach-Object { $_.Context.PreContext; $_.Line; $_.Context.PostContext }
}
$player=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Player.java | Select-Object -First 1).FullName
if($player){
  "--- Player getters ---"
  Select-String -Path $player -Pattern 'getUsername\(|getInventory\(|getEquipment\(|getSkills\(|getHitpoints\(|getMaxHitpoints\(' -Context 2,5 | Select-Object -First 80 | ForEach-Object { $_.Context.PreContext; $_.Line; $_.Context.PostContext }
}
$button=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter ButtonHandler.java | Select-Object -First 1).FullName
if($button){
  "--- sendWear ---"
  $bl=Get-Content $button
  $m=Select-String -Path $button -Pattern 'public static void sendWear\(Player player, int\[\] slotIds\)' | Select-Object -First 1
  if($m){$bl | Select-Object -Skip ([Math]::Max(0,$m.LineNumber-5)) -First 170}
}
$bank=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Bank.java | Select-Object -First 1).FullName
if($bank){
  "--- Bank public API ---"
  Select-String -Path $bank -Pattern 'public .*deposit|public .*withdraw|public .*getItem|public .*getBank|public .*openBank' -Context 1,4 | Select-Object -First 120 | ForEach-Object { $_.Context.PreContext; $_.Line; $_.Context.PostContext }
}
$item=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Item.java | Select-Object -First 1).FullName
if($item){ "--- Item head ---"; Get-Content $item | Select-Object -First 220 }
$skills=(Get-ChildItem recovered/server/src/main/java -Recurse -Filter Skills.java | Select-Object -First 1).FullName
if($skills){
  "--- Skills API ---"
  Select-String -Path $skills -Pattern 'public .*getLevel|public .*getXp|public static final String\[\]' -Context 1,4 | Select-Object -First 100 | ForEach-Object { $_.Context.PreContext; $_.Line; $_.Context.PostContext }
}
