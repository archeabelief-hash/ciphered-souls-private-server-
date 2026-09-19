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
# - dedicated custom item IDs 29990-29997
# - level-1 equipment (requirements stripped)
# - donor 718 geometry used only as temporary prototype visuals
# - Duat Khopesh has an explicit lethal test hit
# - every account receives one set in inventory and one backup set in bank once
# -----------------------------------------------------------------------------

# The recovered server sizes its item-definition array from cache contents.
# Reserve the complete 0-29999 range so our custom prototype IDs are valid.
$utilsPath = "$serverRoot/src/main/java/com/rs/utils/Utils.java"
$utilsText = Get-Content $utilsPath -Raw
$utilsPattern = 'public static final int getItemDefinitionsSize\(\)\s*\{.*?\r?\n\s*\}'
$utilsReplacement = @'
public static final int getItemDefinitionsSize() {
		return 30000;
	}
'@
$utilsNew = [regex]::Replace($utilsText, $utilsPattern, $utilsReplacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($utilsNew -eq $utilsText) { throw 'Could not reserve Elder Souls custom item ID range in Utils.java' }
Set-Content $utilsPath $utilsNew -NoNewline

# Server-side definitions: clone proven 718 donor equipment so the custom IDs are
# genuinely wearable/equippable now, while keeping names/requirements independent.
$serverItemDefs = "$serverRoot/src/main/java/com/rs/cache/loaders/ItemDefinitions.java"
$sid = Get-Content $serverItemDefs -Raw
$loaderNeedle = 'private final void loadItemDefinitions() {'
$loaderReplacement = @'
private final void loadItemDefinitions() {
		if (applyElderSoulsPrototype()) {
			loaded = true;
			return;
		}
'@
if (-not $sid.Contains($loaderNeedle)) { throw 'Could not find ItemDefinitions.loadItemDefinitions()' }
$sid = $sid.Replace($loaderNeedle, $loaderReplacement)

$helperNeedle = 'private void toNote() {'
$serverHelper = @'
private boolean applyElderSoulsPrototype() {
		int donorId;
		String customName;
		switch (id) {
		case 29990:
			donorId = 20671;
			customName = "Duat Khopesh";
			break;
		case 29991:
			donorId = 20125;
			customName = "Duat Guardian Mask";
			break;
		case 29992:
			donorId = 20127;
			customName = "Duat Guardian Cuirass";
			break;
		case 29993:
			donorId = 20129;
			customName = "Duat Guardian Greaves";
			break;
		case 29994:
			donorId = 20131;
			customName = "Duat Guardian Grips";
			break;
		case 29995:
			donorId = 20133;
			customName = "Duat Guardian Boots";
			break;
		case 29996:
			donorId = 19372;
			customName = "Duat Guardian Mantle";
			break;
		case 29997:
			donorId = 19617;
			customName = "Book of the Duat";
			break;
		default:
			return false;
		}

		ItemDefinitions donor = getItemDefinitions(donorId);
		modelId = donor.modelId;
		modelZoom = donor.modelZoom;
		modelRotation1 = donor.modelRotation1;
		modelRotation2 = donor.modelRotation2;
		modelOffset1 = donor.modelOffset1;
		modelOffset2 = donor.modelOffset2;
		stackable = 0;
		value = 1;
		membersOnly = false;
		maleEquip1 = donor.maleEquip1;
		femaleEquip1 = donor.femaleEquip1;
		maleEquip2 = donor.maleEquip2;
		femaleEquip2 = donor.femaleEquip2;
		maleEquipModelId3 = donor.maleEquipModelId3;
		femaleEquipModelId3 = donor.femaleEquipModelId3;
		groundOptions = donor.groundOptions == null ? null : donor.groundOptions.clone();
		inventoryOptions = donor.inventoryOptions == null ? null : donor.inventoryOptions.clone();
		originalModelColors = donor.originalModelColors == null ? null : donor.originalModelColors.clone();
		modifiedModelColors = donor.modifiedModelColors == null ? null : donor.modifiedModelColors.clone();
		originalTextureColors = donor.originalTextureColors == null ? null : donor.originalTextureColors.clone();
		modifiedTextureColors = donor.modifiedTextureColors == null ? null : donor.modifiedTextureColors.clone();
		unknownArray1 = donor.unknownArray1 == null ? null : donor.unknownArray1.clone();
		unknownArray2 = donor.unknownArray2 == null ? null : donor.unknownArray2.clone();
		unknownInt1 = donor.unknownInt1;
		unknownInt2 = donor.unknownInt2;
		unknownInt3 = donor.unknownInt3;
		unknownInt4 = donor.unknownInt4;
		unknownInt5 = donor.unknownInt5;
		unknownInt6 = donor.unknownInt6;
		unknownInt7 = donor.unknownInt7;
		unknownInt8 = donor.unknownInt8;
		unknownInt9 = donor.unknownInt9;
		unknownInt10 = donor.unknownInt10;
		unknownInt11 = donor.unknownInt11;
		unknownInt12 = donor.unknownInt12;
		unknownInt13 = donor.unknownInt13;
		unknownInt14 = donor.unknownInt14;
		unknownInt15 = donor.unknownInt15;
		unknownInt16 = donor.unknownInt16;
		unknownInt17 = donor.unknownInt17;
		unknownInt18 = donor.unknownInt18;
		unknownInt19 = donor.unknownInt19;
		unknownInt20 = donor.unknownInt20;
		unknownInt21 = donor.unknownInt21;
		unknownInt22 = donor.unknownInt22;
		unknownInt23 = donor.unknownInt23;
		teamId = donor.teamId;
		equipSlot = donor.equipSlot;
		equipType = donor.equipType;
		clientScriptData = donor.clientScriptData == null ? null : new HashMap<Integer, Object>(donor.clientScriptData);
		if (clientScriptData != null) {
			for (int key = 749; key <= 797; key++)
				clientScriptData.remove(key);
			clientScriptData.remove(277);
		}
		itemRequiriments = new HashMap<Integer, Integer>();
		certId = -1;
		certTemplateId = -1;
		lendId = -1;
		lendTemplateId = -1;
		unknownValue1 = -1;
		unknownValue2 = -1;
		noted = false;
		lended = false;
		name = customName;
		return true;
	}

	private void toNote() {
'@
if (-not $sid.Contains($helperNeedle)) { throw 'Could not insert Elder Souls server item-definition helper' }
$sid = $sid.Replace($helperNeedle, $serverHelper)
Set-Content $serverItemDefs $sid -NoNewline

# Client-side definitions: mirror the same custom IDs and clone the donor
# inventory/worn models. This makes the prototype visible in inventory and on-body
# without corrupting or renaming the original donor items.
$clientClass477 = "$clientRoot/src/main/java/com/jagex/Class477.java"
$c477 = Get-Content $clientClass477 -Raw
$clientCallNeedle = 'itemdefinition.method6025(16711935);'
$clientCallReplacement = @'
itemdefinition.method6025(16711935);
			applyElderSoulsPrototype(itemId, itemdefinition, forceNew);
'@
if (-not $c477.Contains($clientCallNeedle)) { throw 'Could not find client item-definition post-decode hook' }
$c477 = $c477.Replace($clientCallNeedle, $clientCallReplacement)

$clientHelperNeedle = 'public Class57 method6085('
$clientHelper = @'
private void applyElderSoulsPrototype(int itemId, ItemDefinitions dst, boolean forceNew) {
		int donorId;
		String customName;
		switch (itemId) {
		case 29990: donorId = 20671; customName = "Duat Khopesh"; break;
		case 29991: donorId = 20125; customName = "Duat Guardian Mask"; break;
		case 29992: donorId = 20127; customName = "Duat Guardian Cuirass"; break;
		case 29993: donorId = 20129; customName = "Duat Guardian Greaves"; break;
		case 29994: donorId = 20131; customName = "Duat Guardian Grips"; break;
		case 29995: donorId = 20133; customName = "Duat Guardian Boots"; break;
		case 29996: donorId = 19372; customName = "Duat Guardian Mantle"; break;
		case 29997: donorId = 19617; customName = "Book of the Duat"; break;
		default: return;
		}
		ItemDefinitions src = getItemDefinitions(donorId, forceNew);
		dst.anInt5700 = src.anInt5700;
		dst.anInt5702 = src.anInt5702;
		dst.anInt5703 = src.anInt5703;
		dst.anInt5704 = src.anInt5704;
		dst.aShortArray5706 = src.aShortArray5706 == null ? null : src.aShortArray5706.clone();
		dst.aByteArray5708 = src.aByteArray5708 == null ? null : src.aByteArray5708.clone();
		dst.anInt5709 = src.anInt5709;
		dst.anInt5710 = src.anInt5710;
		dst.aShortArray5711 = src.aShortArray5711 == null ? null : src.aShortArray5711.clone();
		dst.aShortArray5712 = src.aShortArray5712 == null ? null : src.aShortArray5712.clone();
		dst.anInt5713 = src.anInt5713;
		dst.anInt5714 = src.anInt5714;
		dst.anInt5715 = src.anInt5715;
		dst.anInt5716 = src.anInt5716;
		dst.anInt5717 = src.anInt5717;
		dst.anInt5718 = src.anInt5718;
		dst.anInt5719 = src.anInt5719;
		dst.anInt5720 = src.anInt5720;
		dst.anInt5721 = src.anInt5721;
		dst.anInt5722 = src.anInt5722;
		dst.aStringArray5723 = src.aStringArray5723 == null ? null : src.aStringArray5723.clone();
		dst.anInt5724 = src.anInt5724;
		dst.anInt5725 = src.anInt5725;
		dst.anInt5727 = src.anInt5727;
		dst.anInt5728 = src.anInt5728;
		dst.anInt5729 = src.anInt5729;
		dst.anInt5730 = src.anInt5730;
		dst.aBoolean5731 = false;
		dst.aStringArray5732 = src.aStringArray5732 == null ? null : src.aStringArray5732.clone();
		dst.anInt5733 = src.anInt5733;
		dst.aBoolean5734 = src.aBoolean5734;
		dst.anInt5735 = src.anInt5735;
		dst.anInt5736 = src.anInt5736;
		dst.anInt5737 = src.anInt5737;
		dst.anInt5738 = src.anInt5738;
		dst.anInt5739 = src.anInt5739;
		dst.anInt5741 = src.anInt5741;
		dst.anInt5742 = src.anInt5742;
		dst.anInt5743 = src.anInt5743;
		dst.anInt5744 = src.anInt5744;
		dst.anInt5745 = src.anInt5745;
		dst.anInt5746 = src.anInt5746;
		dst.anInt5747 = src.anInt5747;
		dst.anInt5748 = src.anInt5748;
		dst.anInt5749 = src.anInt5749;
		dst.anInt5750 = src.anInt5750;
		dst.anIntArray5752 = src.anIntArray5752 == null ? null : src.anIntArray5752.clone();
		dst.anIntArray5753 = src.anIntArray5753 == null ? null : src.anIntArray5753.clone();
		dst.aShortArray5754 = src.aShortArray5754 == null ? null : src.aShortArray5754.clone();
		dst.anInt5755 = src.anInt5755;
		dst.anInt5756 = src.anInt5756;
		dst.anInt5758 = src.anInt5758;
		dst.anInt5759 = src.anInt5759;
		dst.anInt5760 = src.anInt5760;
		dst.anInt5761 = src.anInt5761;
		dst.anInt5762 = src.anInt5762;
		dst.anInt5763 = src.anInt5763;
		dst.anInt5764 = src.anInt5764;
		dst.anInt5765 = src.anInt5765;
		dst.aClass437_5766 = src.aClass437_5766;
		dst.anIntArray5767 = src.anIntArray5767 == null ? null : src.anIntArray5767.clone();
		dst.anInt5768 = src.anInt5768;
		dst.anInt5769 = src.anInt5769;
		dst.anInt5770 = src.anInt5770;
		dst.aBoolean5771 = src.aBoolean5771;
		dst.anInt5772 = src.anInt5772;
		dst.aString5707 = customName;
	}

	public Class57 method6085(
'@
if (-not $c477.Contains($clientHelperNeedle)) { throw 'Could not insert Elder Souls client item-definition helper' }
$c477 = $c477.Replace($clientHelperNeedle, $clientHelper)
Set-Content $clientClass477 $c477 -NoNewline

# Explicit prototype bonuses. The Khopesh is intentionally absurd for this
# engineering test; balance comes only after the complete item pipeline works.
$itemBonuses = "$serverRoot/src/main/java/com/rs/utils/ItemBonuses.java"
$ib = Get-Content $itemBonuses -Raw
$bonusNeedle = @'
	public static final int[] getItemBonuses(int itemId) {
		return itemBonuses.get(itemId);
	}
'@
$bonusReplacement = @'
	public static final int[] getItemBonuses(int itemId) {
		switch (itemId) {
		case 29990: return new int[] { 5000, 5000, 5000, 0, 0, 100, 100, 100, 100, 100, 0, 0, 0, 0, 5000, 0, 0, 0 };
		case 29991: return new int[] { 25, 25, 25, 40, 25, 200, 200, 200, 225, 200, 100, 10, 10, 10, 35, 25, 10, 10 };
		case 29992: return new int[] { 40, 40, 40, 60, 40, 500, 500, 500, 550, 500, 200, 20, 20, 20, 60, 35, 15, 15 };
		case 29993: return new int[] { 35, 35, 35, 50, 35, 400, 400, 400, 450, 400, 175, 15, 15, 15, 50, 30, 12, 12 };
		case 29994: return new int[] { 50, 50, 50, 65, 50, 150, 150, 150, 175, 150, 75, 5, 5, 5, 75, 40, 8, 10 };
		case 29995: return new int[] { 35, 35, 35, 45, 35, 150, 150, 150, 175, 150, 75, 5, 5, 5, 50, 30, 6, 8 };
		case 29996: return new int[] { 100, 100, 100, 125, 100, 250, 250, 250, 300, 250, 125, 10, 10, 10, 100, 75, 20, 20 };
		case 29997: return new int[] { 25, 25, 25, 250, 25, 100, 100, 100, 300, 125, 100, 10, 15, 10, 25, 25, 25, 35 };
		default: return itemBonuses.get(itemId);
		}
	}
'@
if (-not $ib.Contains($bonusNeedle)) { throw 'Could not patch ItemBonuses.getItemBonuses()' }
$ib = $ib.Replace($bonusNeedle, $bonusReplacement)
Set-Content $itemBonuses $ib -NoNewline

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

# Give every existing or new account the prototype once. A second copy is stored
# in the bank so the user can recover the set even if the inventory was crowded.
$playerPath = "$serverRoot/src/main/java/com/rs/game/player/Player.java"
$pl = Get-Content $playerPath -Raw
$ctorNeedle = '	public Player(String password) {'
$ctorReplacement = @'
	private boolean duatPrototypeKitClaimed;

	public Player(String password) {
'@
if (-not $pl.Contains($ctorNeedle)) { throw 'Could not add Duat kit flag to Player.java' }
$pl = $pl.Replace($ctorNeedle, $ctorReplacement)

$startPattern = '(public void start\(\) \{.*?)(\r?\n\t\trun\(\);)'
$startReplacement = @'
$1
		if (!duatPrototypeKitClaimed) {
			giveDuatPrototypeKit();
			duatPrototypeKitClaimed = true;
		}
$2
'@
$plNew = [regex]::Replace($pl, $startPattern, $startReplacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($plNew -eq $pl) { throw 'Could not install Duat one-time login grant in Player.start()' }
$pl = $plNew

$kitNeedle = '	public SquealOfFortune getSquealOfFortune() {'
$kitMethod = @'
	private void giveDuatPrototypeKit() {
		int[] kit = { 29990, 29991, 29992, 29993, 29994, 29995, 29996, 29997 };
		for (int itemId : kit) {
			getInventory().addItem(new Item(itemId, 1));
			getBank().addItem(itemId, 1, false);
		}
		getInventory().addItem(new Item(995, 100000000));
		getPackets().sendGameMessage("<col=D6A84B>Duat Guardian prototype kit added. Backup copies are in your bank.</col>");
		getPackets().sendGameMessage("<col=FF4040>TEST MODE: Duat Khopesh is level 1 and intentionally one-hit lethal.</col>");
	}

	public SquealOfFortune getSquealOfFortune() {
'@
if (-not $pl.Contains($kitNeedle)) { throw 'Could not add giveDuatPrototypeKit() to Player.java' }
$pl = $pl.Replace($kitNeedle, $kitMethod)
Set-Content $playerPath $pl -NoNewline

Write-Host 'Applied Elder Souls Duat Guardian prototype: custom IDs 29990-29997, level-1 gear, lethal Khopesh, login kit.'

Write-Host 'Applied Elder Souls Scape PK Training patches.'
