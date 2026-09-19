$ErrorActionPreference = 'Stop'

$serverRoot = 'recovered/server'
$clientRoot = 'recovered/client'

function Replace-RegexRequired([string]$path, [string]$pattern, [string]$replacement) {
    $text = Get-Content $path -Raw
    $newText = [regex]::Replace($text, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($newText -eq $text) { throw "Required pattern not found in $path" }
    Set-Content $path $newText -NoNewline
}

# -----------------------------------------------------------------------------
# Branding + PK Training Arena starting location
# -----------------------------------------------------------------------------
$settings = "$serverRoot/src/main/java/com/rs/Settings.java"
$s = Get-Content $settings -Raw
$s = $s.Replace('public static final String SERVER_NAME = "Matrix";', 'public static final String SERVER_NAME = "Elder Souls Scape PK Training";')
$s = $s.Replace('public static final String SERVER_NAME = "Ciphered Souls";', 'public static final String SERVER_NAME = "Elder Souls Scape PK Training";')
$s = [regex]::Replace($s, 'public static final WorldTile START_PLAYER_LOCATION = new WorldTile\([^;]+;', 'public static final WorldTile START_PLAYER_LOCATION = new WorldTile(2539, 4712, 0); // PK Training Arena')
$s = $s.Replace('Matrix!', 'Elder Souls Scape PK Training!')
Set-Content $settings $s -NoNewline

$loader = "$clientRoot/src/main/java/Loader.java"
if (Test-Path $loader) {
    $x = Get-Content $loader -Raw
    $x = $x.Replace('Matrix RSPS', 'Elder Souls Scape PK Training')
    $x = $x.Replace('Ciphered Souls - Local 718', 'Elder Souls Scape PK Training')
    $x = $x.Replace('Ciphered Souls — Local 718', 'Elder Souls Scape PK Training')
    Set-Content $loader $x -NoNewline
}

$clientSettings = "$clientRoot/src/main/java/Settings.java"
if (Test-Path $clientSettings) {
    $x = Get-Content $clientSettings -Raw
    $x = $x.Replace('CIPHERED_SOULS', 'ELDER_SOULS_SCAPE_PK_TRAINING')
    $x = $x.Replace('MATRIX', 'ELDER_SOULS_SCAPE_PK_TRAINING')
    Set-Content $clientSettings $x -NoNewline
}

$runeLite = "$clientRoot/src/main/java/net/runelite/client/RuneLite.java"
if (Test-Path $runeLite) {
    $x = Get-Content $runeLite -Raw
    $x = $x.Replace('CipheredSouls718', 'ElderSoulsScapePKTraining')
    $x = $x.Replace('MATRIX', 'ElderSoulsScapePKTraining')
    Set-Content $runeLite $x -NoNewline
}

# -----------------------------------------------------------------------------
# Grand Exchange = instant infinite training exchange at High Alchemy value.
# No player offer matching or stock dependency.
# -----------------------------------------------------------------------------
$ge = "$serverRoot/src/main/java/com/rs/game/player/GrandExchangeManager.java"
$g = Get-Content $ge -Raw

# Training build: GE is always available locally, including fresh accounts.
$g = [regex]::Replace(
    $g,
    'public void openGrandExchange\(\) \{.*?player\.getInterfaceManager\(\)\.sendInterface\(105\);',
    "public void openGrandExchange() {`r`n`t`tplayer.getInterfaceManager().sendInterface(105);",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

# High-alch value is the only displayed/set price.
$g = $g.Replace('int price = GrandExchange.getPrice(id);', "int price = ItemConstants.getHighAlchValue(new Item(id));`r`n`t`tif (price < 1) price = 1;")
$g = $g.Replace('int price = GrandExchange.getPrice(item.getId());', "int price = ItemConstants.getHighAlchValue(new Item(item.getId()));`r`n`t`tif (price < 1) price = 1;")

$g = [regex]::Replace(
    $g,
    'public void editPrice\(\) \{.*?\n\t\}',
    @'
public void editPrice() {
		if (getItemId() == -1) return;
		int price = ItemConstants.getHighAlchValue(new Item(getItemId()));
		if (price < 1) price = 1;
		setPricePerItem(price);
		player.getPackets().sendGameMessage("PK Training Arena prices are fixed at High Alchemy value.");
	}
'@,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

$g = [regex]::Replace(
    $g,
    'public void modifyPricePerItem\(int value\) \{.*?\n\t\}',
    @'
public void modifyPricePerItem(int value) {
		if (getType() == -1 || getItemId() == -1) return;
		int price = ItemConstants.getHighAlchValue(new Item(getItemId()));
		if (price < 1) price = 1;
		setPricePerItem(price);
	}
'@,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

$confirmPattern = 'public void confirmOffer\(\) \{.*?\n\t\}\r?\n\r?\n\tpublic void makeOffer\('
$confirmReplacement = @'
public void confirmOffer() {
		int type = getType();
		if (type == -1) return;
		int slot = getCurrentSlot();
		if (slot == -1 || !isSlotFree(slot)) return;
		boolean buy = type == 0;
		int itemId = getItemId();
		if (itemId == -1) {
			player.getPackets().sendGameMessage("You must choose an item first.");
			return;
		}
		int amount = getAmount();
		if (amount <= 0) {
			player.getPackets().sendGameMessage("Choose a quantity first.");
			return;
		}
		int pricePerItem = ItemConstants.getHighAlchValue(new Item(itemId));
		if (pricePerItem < 1) {
			player.getPackets().sendGameMessage("That item has no valid training exchange value.");
			return;
		}
		long totalLong = (long) pricePerItem * (long) amount;
		if (totalLong > Integer.MAX_VALUE) {
			player.getPackets().sendGameMessage("That transaction is too large. Use a smaller quantity.");
			return;
		}
		int total = (int) totalLong;

		if (buy) {
			Item purchase = new Item(itemId, amount);
			boolean stackable = purchase.getDefinitions().isStackable();
			if ((!stackable && amount > player.getInventory().getFreeSlots())
					|| (stackable && player.getInventory().getAmountOf(itemId) == 0 && player.getInventory().getFreeSlots() == 0)) {
				player.getPackets().sendGameMessage("Not enough inventory space for that purchase.");
				return;
			}
			if (player.getInventory().getCoinsAmount() < total) {
				player.getPackets().sendGameMessage("You do not have enough coins.");
				return;
			}
			if (!player.getInventory().removeItemMoneyPouch(new Item(995, total))) {
				player.getPackets().sendGameMessage("Unable to take payment.");
				return;
			}
			Item remainder = player.getInventory().add(purchase);
			if (remainder != null) {
				if (remainder.getAmount() < amount)
					player.getInventory().deleteItem(itemId, amount - remainder.getAmount());
				player.getInventory().addItemMoneyPouch(new Item(995, total));
				player.getPackets().sendGameMessage("Purchase cancelled because the inventory changed.");
				return;
			}
			player.getPackets().sendGameMessage("Purchased " + amount + " x " + ItemConfig.forID(itemId).getName() + " for " + Utils.getFormattedNumber(total) + " gp.");
		} else {
			int inventoryAmount = getItemAmount(new Item(itemId));
			if (amount > inventoryAmount) {
				player.getPackets().sendGameMessage("You do not have enough of that item to sell.");
				return;
			}
			int notedId = ItemConfig.forID(itemId).cert;
			int notedAmount = notedId == -1 ? 0 : player.getInventory().getAmountOf(notedId);
			int fromNoted = Math.min(amount, notedAmount);
			if (fromNoted > 0) player.getInventory().deleteItem(notedId, fromNoted);
			int fromNormal = amount - fromNoted;
			if (fromNormal > 0) player.getInventory().deleteItem(itemId, fromNormal);
			player.getInventory().addItemMoneyPouch(new Item(995, total));
			player.getPackets().sendGameMessage("Sold " + amount + " x " + ItemConfig.forID(itemId).getName() + " for " + Utils.getFormattedNumber(total) + " gp.");
		}
		cancelOffer();
	}

	public void makeOffer(
'@
$newG = [regex]::Replace($g, $confirmPattern, $confirmReplacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($newG -eq $g) { throw 'Could not replace GrandExchangeManager.confirmOffer()' }
Set-Content $ge $newG -NoNewline

# -----------------------------------------------------------------------------
# PK Training Arena shop hub.
# Reuse the already-working Edgeville shop NPC IDs and their existing handlers.
# We only add new spawns here; no duplicate Mage Arena NPCs and no new shop code.
# -----------------------------------------------------------------------------
$spawns = "$serverRoot/data/npc/customSpawnsList.txt"
if (-not (Test-Path $spawns)) { New-Item -ItemType File -Force $spawns | Out-Null }
$spawnText = Get-Content $spawns -Raw
$marker = '// ELDER SOULS PK TRAINING ARENA V2'
if (-not $spawnText.Contains($marker)) {
    Add-Content $spawns @'
// ELDER SOULS PK TRAINING ARENA V2
// Core services
2241 - 2542 4712 0 // Grand Exchange clerk
494 - 2538 4711 0 // Banker
// Existing Edgeville shop NPC lineup, reused with their existing shop handlers
2253 - 2534 4712 0 // Onyx Guide
3705 - 2534 4713 0 // Max
6537 - 2534 4714 0 // Mandrith
13727 - 2534 4715 0 // Xuan
954 - 2534 4716 0 // Loyal Dan
945 - 2534 4717 0 // Pure Guide
944 - 2534 4718 0 // Gear Guide
949 - 2535 4719 0 // Skilling Guide
947 - 2536 4719 0 // Skilling Secondaries Guide
16006 - 2537 4719 0 // Fremennik Guide
1694 - 2538 4719 0 // Voting Guide
2024 - 2539 4719 0 // Strange Old Man
2620 - 2540 4719 0 // TzHaar-Hur-Tel
1040 - 2541 4719 0 // Fidelio
1918 - 2542 4719 0 // Wise Old Man
'@
}



# -----------------------------------------------------------------------------
# ELDER SOULS DUAT GUARDIAN PROTOTYPE
# First original-content vertical slice:
# - custom item IDs 29990-29997
# - all pieces wearable/wieldable at level 1
# - temporary donor geometry for the first playable visual test
# - deliberately lethal Duat Khopesh for combat-pipeline testing
# - one kit in inventory + one backup kit in bank for every account
# -----------------------------------------------------------------------------

# This Matrix branch already has a CustomItems layer specifically for cache-independent
# custom definitions. Use it rather than forcing new records into the cache.
$customItemsPath = (Get-ChildItem "$serverRoot/src/main/java" -Recurse -Filter 'CustomItems.java' | Select-Object -First 1).FullName
if (-not $customItemsPath) { throw 'Could not locate CustomItems.java in recovered server source' }
$ci = Get-Content $customItemsPath -Raw
$customSwitchNeedle = 'switch (config.getId()) {'
$customCases = @'
switch (config.getId()) {
		case 29990:
			copy(20671, config); // temporary Brackish blade geometry
			config.name = "Duat Khopesh";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(5000);
			config.setSlashAttack(5000);
			config.setCrushAttack(5000);
			config.setStabDef(100);
			config.setSlashDef(100);
			config.setCrushDef(100);
			config.setMagicDef(100);
			config.setRangeDef(100);
			config.setStrengthBonus(5000);
			config.setAttackSpeed(2);
			config.setPrayerBonus(10);
			break;
		case 29991:
			copy(20125, config); // Ancient ceremonial mask geometry
			config.name = "Duat Guardian Mask";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(25); config.setSlashAttack(25); config.setCrushAttack(25);
			config.setMagicAttack(40); config.setRangeAttack(25);
			config.setStabDef(200); config.setSlashDef(200); config.setCrushDef(200);
			config.setMagicDef(225); config.setRangeDef(200);
			config.setStrengthBonus(35); config.setRangedStrBonus(25);
			config.setMagicDamage(10); config.setPrayerBonus(10);
			break;
		case 29992:
			copy(20127, config); // Ancient ceremonial top geometry
			config.name = "Duat Guardian Cuirass";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(40); config.setSlashAttack(40); config.setCrushAttack(40);
			config.setMagicAttack(60); config.setRangeAttack(40);
			config.setStabDef(500); config.setSlashDef(500); config.setCrushDef(500);
			config.setMagicDef(550); config.setRangeDef(500);
			config.setStrengthBonus(60); config.setRangedStrBonus(35);
			config.setMagicDamage(15); config.setPrayerBonus(15);
			break;
		case 29993:
			copy(20129, config); // Ancient ceremonial legs geometry
			config.name = "Duat Guardian Greaves";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(35); config.setSlashAttack(35); config.setCrushAttack(35);
			config.setMagicAttack(50); config.setRangeAttack(35);
			config.setStabDef(400); config.setSlashDef(400); config.setCrushDef(400);
			config.setMagicDef(450); config.setRangeDef(400);
			config.setStrengthBonus(50); config.setRangedStrBonus(30);
			config.setMagicDamage(12); config.setPrayerBonus(12);
			break;
		case 29994:
			copy(20131, config); // Ancient ceremonial gloves geometry
			config.name = "Duat Guardian Grips";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(50); config.setSlashAttack(50); config.setCrushAttack(50);
			config.setMagicAttack(65); config.setRangeAttack(50);
			config.setStabDef(150); config.setSlashDef(150); config.setCrushDef(150);
			config.setMagicDef(175); config.setRangeDef(150);
			config.setStrengthBonus(75); config.setRangedStrBonus(40);
			config.setMagicDamage(10); config.setPrayerBonus(8);
			break;
		case 29995:
			copy(20133, config); // Ancient ceremonial boots geometry
			config.name = "Duat Guardian Boots";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(35); config.setSlashAttack(35); config.setCrushAttack(35);
			config.setMagicAttack(45); config.setRangeAttack(35);
			config.setStabDef(150); config.setSlashDef(150); config.setCrushDef(150);
			config.setMagicDef(175); config.setRangeDef(150);
			config.setStrengthBonus(50); config.setRangedStrBonus(30);
			config.setMagicDamage(8); config.setPrayerBonus(6);
			break;
		case 29996:
			copy(19372, config); // Ancient cloak geometry
			config.name = "Duat Guardian Mantle";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(100); config.setSlashAttack(100); config.setCrushAttack(100);
			config.setMagicAttack(125); config.setRangeAttack(100);
			config.setStabDef(250); config.setSlashDef(250); config.setCrushDef(250);
			config.setMagicDef(300); config.setRangeDef(250);
			config.setStrengthBonus(100); config.setRangedStrBonus(75);
			config.setMagicDamage(20); config.setPrayerBonus(20);
			break;
		case 29997:
			copy(19617, config); // Ancient book geometry
			config.name = "Book of the Duat";
			config.value = 1;
			config.tradeable = true;
			config.itemRequiriments = new HashMap<Integer, Integer>();
			config.setStabAttack(25); config.setSlashAttack(25); config.setCrushAttack(25);
			config.setMagicAttack(250); config.setRangeAttack(25);
			config.setStabDef(100); config.setSlashDef(100); config.setCrushDef(100);
			config.setMagicDef(300); config.setRangeDef(125);
			config.setStrengthBonus(25); config.setRangedStrBonus(25);
			config.setMagicDamage(35); config.setPrayerBonus(25);
			break;
'@
if (-not $ci.Contains($customSwitchNeedle)) { throw 'Could not find CustomItems.modify switch for Duat definitions' }
$ci = $ci.Replace($customSwitchNeedle, $customCases)
Set-Content $customItemsPath $ci -NoNewline

# Client-side definitions: use the client's existing CustomItems layer.
# The first playable build deliberately clones compatible 718 donor geometry.
# This proves the item/equipment/combat pipeline before original Duat meshes are packed.
$clientCustomItems = "$clientRoot/src/main/java/CustomItems.java"
if (-not (Test-Path $clientCustomItems)) { throw "Could not locate client CustomItems.java" }
$cci = Get-Content $clientCustomItems -Raw
$clientSwitchNeedle = 'switch (config.getId()) {'
$clientCases = @'
switch (config.getId()) {
        case 29990:
            copy(20671, config);
            config.name = "Duat Khopesh";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wield", null, null, "Drop"};
            break;
        case 29991:
            copy(20125, config);
            config.name = "Duat Guardian Mask";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29992:
            copy(20127, config);
            config.name = "Duat Guardian Cuirass";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29993:
            copy(20129, config);
            config.name = "Duat Guardian Greaves";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29994:
            copy(20131, config);
            config.name = "Duat Guardian Grips";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29995:
            copy(20133, config);
            config.name = "Duat Guardian Boots";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29996:
            copy(19372, config);
            config.name = "Duat Guardian Mantle";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wear", null, null, "Drop"};
            break;
        case 29997:
            copy(19617, config);
            config.name = "Book of the Duat";
            config.tradeable = true;
            config.inventoryOptions = new String[]{null, "Wield", null, null, "Drop"};
            break;
'@
$cciNew = [regex]::Replace($cci, 'switch\s*\(\s*config\.getId\(\)\s*\)\s*\{', $clientCases, 1)
if ($cciNew -eq $cci) { throw 'Could not find client CustomItems.modify switch' }
$cci = $cciNew
Set-Content $clientCustomItems $cci -NoNewline

# One-hit engineering mode for the prototype Khopesh.
$playerCombat = "$serverRoot/src/main/java/com/rs/game/player/actions/PlayerCombat.java"
$pc = Get-Content $playerCombat -Raw
$meleeNeedle = @'
	private int meleeAttack(final Player player) {
		int weaponId = player.getEquipment().getWeaponId();
'@
$meleeReplacement = @'
	private int meleeAttack(final Player player) {
		int weaponId = player.getEquipment().getWeaponId();
		if (weaponId == 29990) {
			int attackStyle = player.getCombatDefinitions().getAttackStyle();
			player.setNextAnimation(new Animation(getWeaponAttackEmote(4587, attackStyle)));
			long lethal = Math.max(100000L, ((long) target.getHitpoints()) * 20L);
			int damage = (int) Math.min(500000000L, lethal);
			delayNormalHit(weaponId, attackStyle, getMeleeHit(player, damage));
			player.getPackets().sendGameMessage("<col=D6A84B>The Duat Khopesh severs the target's soul.</col>");
			return 2;
		}
'@
if (-not $pc.Contains($meleeNeedle)) { throw 'Could not patch PlayerCombat.meleeAttack() for Duat Khopesh' }
$pc = $pc.Replace($meleeNeedle, $meleeReplacement)
Set-Content $playerCombat $pc -NoNewline

# Give every account the prototype automatically when it does not already own
# a Duat Khopesh. No password or special owner account is required for this local test.
$playerPath = "$serverRoot/src/main/java/com/rs/game/player/Player.java"
$pl = Get-Content $playerPath -Raw
$startPattern = '(public void start\(\) \{.*?)(\r?\n\t\trun\(\);)'
$startReplacement = @'
$1
		if (!containsItem(29990)) {
			int[] duatKit = { 29990, 29991, 29992, 29993, 29994, 29995, 29996, 29997 };
			for (int itemId : duatKit) {
				getInventory().addItem(new Item(itemId, 1));
				getBank().addItem(itemId, 1, false);
			}
			getInventory().addItem(new Item(995, 100000000));
			getPackets().sendGameMessage("<col=D6A84B>Duat Guardian prototype kit added. Backup copies are in your bank.</col>");
			getPackets().sendGameMessage("<col=FF4040>TEST MODE: Duat Khopesh is level 1 and intentionally one-hit lethal.</col>");
		}
$2
'@
$plNew = [regex]::Replace($pl, $startPattern, $startReplacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($plNew -eq $pl) { throw 'Could not install Duat automatic login grant in Player.start()' }
Set-Content $playerPath $plNew -NoNewline

Write-Host 'Applied Elder Souls Duat Guardian prototype: custom IDs 29990-29997, level-1 gear, lethal Khopesh, login kit.'

Write-Host 'Applied Elder Souls Scape PK Training patches.'
