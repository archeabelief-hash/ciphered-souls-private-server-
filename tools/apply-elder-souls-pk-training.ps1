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

Write-Host 'Applied Elder Souls Scape PK Training patches.'
