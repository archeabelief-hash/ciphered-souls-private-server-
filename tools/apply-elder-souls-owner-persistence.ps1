$ErrorActionPreference = 'Stop'

Write-Host '=== Elder Souls persistent accounts + master owner account ==='

$serverRoot = 'recovered/server'

# ---------------------------------------------------------------------------
# Persist world/account data outside the install directory so launcher updates
# cannot replace player saves. The launcher migrates the bundled/current data
# into this location on first use.
# ---------------------------------------------------------------------------
$settingsPath = "$serverRoot/src/main/java/com/rs/Settings.java"
$settings = Get-Content $settingsPath -Raw

$oldLoginPath = 'public static final String LOGIN_DATA_PATH = "data/login/";'
$newLoginPath = 'public static final String LOGIN_DATA_PATH = System.getenv("LOCALAPPDATA") == null ? "data/login/" : System.getenv("LOCALAPPDATA") + "/ElderSoulsRPGAlphaData/login/";'
if ($settings.Contains($oldLoginPath)) {
    $settings = $settings.Replace($oldLoginPath, $newLoginPath)
} elseif (-not $settings.Contains('ElderSoulsRPGAlphaData/login/')) {
    throw 'Could not patch Settings.LOGIN_DATA_PATH for persistent Elder Souls login saves.'
}

$oldDataPath = 'public static final String DATA_PATH = "data/world/";'
$newDataPath = 'public static final String DATA_PATH = System.getenv("LOCALAPPDATA") == null ? "data/world/" : System.getenv("LOCALAPPDATA") + "/ElderSoulsRPGAlphaData/world/";'
if ($settings.Contains($oldDataPath)) {
    $settings = $settings.Replace($oldDataPath, $newDataPath)
} elseif (-not $settings.Contains('ElderSoulsRPGAlphaData/world/')) {
    throw 'Could not patch Settings.DATA_PATH for persistent Elder Souls character saves.'
}
Set-Content $settingsPath $settings -NoNewline

# ---------------------------------------------------------------------------
# A single local account may claim permanent master ownership. Ownership lives
# beside persistent world data and survives re-installs/auto-updates.
# ---------------------------------------------------------------------------
$ownerPath = "$serverRoot/src/main/java/com/rs/utils/ElderSoulsOwner.java"
$ownerSource = @'
package com.rs.utils;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

import com.rs.Settings;
import com.rs.game.player.Player;

public final class ElderSoulsOwner {

    private static String cachedOwner;

    private ElderSoulsOwner() {
    }

    private static File ownerFile() {
        return new File(Settings.DATA_PATH, "owner-account.txt");
    }

    private static synchronized String loadOwner() {
        if (cachedOwner != null)
            return cachedOwner;

        File file = ownerFile();
        if (!file.exists()) {
            cachedOwner = "";
            return cachedOwner;
        }

        try {
            cachedOwner = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8).trim();
        } catch (Throwable t) {
            Logger.handle(t);
            cachedOwner = "";
        }
        return cachedOwner;
    }

    public static synchronized boolean isOwner(String username) {
        if (username == null || username.trim().isEmpty())
            return false;
        String owner = loadOwner();
        return !owner.isEmpty() && owner.equalsIgnoreCase(username.trim());
    }

    public static synchronized String getOwnerName() {
        return loadOwner();
    }

    public static synchronized boolean claim(Player player) {
        if (player == null || player.getUsername() == null)
            return false;

        String username = player.getUsername().trim();
        String existing = loadOwner();

        if (!existing.isEmpty() && !existing.equalsIgnoreCase(username))
            return false;

        try {
            File file = ownerFile();
            File parent = file.getParentFile();
            if (parent != null)
                parent.mkdirs();

            Files.write(file.toPath(), username.getBytes(StandardCharsets.UTF_8));
            cachedOwner = username;
            player.setRights(2);
            return true;
        } catch (Throwable t) {
            Logger.handle(t);
            return false;
        }
    }
}
'@
New-Item -ItemType Directory -Force (Split-Path $ownerPath) | Out-Null
Set-Content $ownerPath $ownerSource -NoNewline

# ---------------------------------------------------------------------------
# Treat the claimed account as rights=2 everywhere, even if a legacy login
# service or an older serialized Player record tries to provide lower rights.
# ---------------------------------------------------------------------------
$playerPath = "$serverRoot/src/main/java/com/rs/game/player/Player.java"
$player = Get-Content $playerPath -Raw

$oldGetRights = @'
	public int getRights() {
		return rights;
	}
'@
$newGetRights = @'
	public int getRights() {
		return com.rs.utils.ElderSoulsOwner.isOwner(username) ? 2 : rights;
	}
'@
if ($player.Contains($oldGetRights)) {
    $player = $player.Replace($oldGetRights, $newGetRights)
} elseif (-not $player.Contains('ElderSoulsOwner.isOwner(username) ? 2 : rights')) {
    throw 'Could not patch Player.getRights() for Elder Souls owner.'
}

$oldIsAdmin = @'
	public boolean isAdmin() {
		return rights == 2;
	}
'@
$newIsAdmin = @'
	public boolean isAdmin() {
		return rights == 2 || com.rs.utils.ElderSoulsOwner.isOwner(username);
	}
'@
if ($player.Contains($oldIsAdmin)) {
    $player = $player.Replace($oldIsAdmin, $newIsAdmin)
} elseif (-not $player.Contains('rights == 2 || com.rs.utils.ElderSoulsOwner.isOwner(username)')) {
    throw 'Could not patch Player.isAdmin() for Elder Souls owner.'
}
Set-Content $playerPath $player -NoNewline

# ---------------------------------------------------------------------------
# One-time local command: log into the existing account and type ::claimowner.
# It is intentionally placed before bank-PIN/VPN/new-player command gates.
# ---------------------------------------------------------------------------
$commandsPath = "$serverRoot/src/main/java/com/rs/game/player/content/commands/Commands.java"
$commands = Get-Content $commandsPath -Raw

$commandAnchor = @'
        if (command.length() == 0 || player.isLobby() || player.isLocked()) // if they used ::(nothing) theres no command
            return false;

        if (!player.checkBankPin()) {
'@

$claimBlock = @'
        if (command.length() == 0 || player.isLobby() || player.isLocked()) // if they used ::(nothing) theres no command
            return false;

        if (command.trim().equalsIgnoreCase("claimowner") && !Settings.HOSTED) {
            if (ElderSoulsOwner.claim(player)) {
                player.setRights(2);
                GameLauncher.savePlayers();
                player.getPackets().sendGameMessage("<col=D4AF37>This account is now the Elder Souls master owner account.</col>");
                player.getPackets().sendGameMessage("Owner rights are permanent on this local installation and persist through updates.");
            } else {
                String owner = ElderSoulsOwner.getOwnerName();
                player.getPackets().sendGameMessage(owner == null || owner.isEmpty()
                        ? "Owner claim failed. Check server logs."
                        : "Master ownership is already claimed by another local account.");
            }
            return true;
        }

        if (command.trim().equalsIgnoreCase("ownerstatus") && !Settings.HOSTED) {
            String owner = ElderSoulsOwner.getOwnerName();
            player.getPackets().sendGameMessage(owner == null || owner.isEmpty()
                    ? "No Elder Souls master owner has been claimed yet. Use ::claimowner."
                    : "Elder Souls master owner: " + owner);
            return true;
        }

        if (!player.checkBankPin()) {
'@

if ($commands.Contains($commandAnchor)) {
    $commands = $commands.Replace($commandAnchor, $claimBlock)
} elseif (-not $commands.Contains('command.trim().equalsIgnoreCase("claimowner")')) {
    throw 'Could not add ::claimowner command.'
}

# Remove legacy hard-coded owner usernames from the inherited server command layer.
$commands = $commands.Replace('player.getUsername().equalsIgnoreCase("nick")', 'ElderSoulsOwner.isOwner(player.getUsername())')
$commands = $commands.Replace('player.getUsername().equalsIgnoreCase("dragonkk")', 'ElderSoulsOwner.isOwner(player.getUsername())')
$commands = $commands.Replace('!player.getUsername().equalsIgnoreCase("dragonkk")', '!ElderSoulsOwner.isOwner(player.getUsername())')
$commands = $commands.Replace('(player.getUsername().equalsIgnoreCase("dragonkk") ? "Owner" : "Admin")', '(ElderSoulsOwner.isOwner(player.getUsername()) ? "Owner" : "Admin")')

Set-Content $commandsPath $commands -NoNewline

Write-Host 'Persistent login + character data paths configured.'
Write-Host 'Master owner claim command installed: ::claimowner'
Write-Host 'Owner status command installed: ::ownerstatus'
