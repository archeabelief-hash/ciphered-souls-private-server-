$ErrorActionPreference = 'Stop'

$serverRoot = 'recovered/server'
$javaDir = "$serverRoot/src/main/java/com/rs/tools"
New-Item -ItemType Directory -Force $javaDir | Out-Null

$gateway = @'
package com.rs.tools;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

import com.rs.game.World;
import com.rs.game.item.Item;
import com.rs.game.npc.NPC;
import com.rs.game.player.Player;
import com.rs.game.player.Skills;
import com.rs.game.player.actions.PlayerCombat;
import com.rs.net.decoders.handlers.ButtonHandler;

public final class ElderSoulsAgentGateway {

    public static final String HOST = "127.0.0.1";
    public static final int PORT = 7780;

    private static volatile boolean running;
    private static ServerSocket server;

    private ElderSoulsAgentGateway() {
    }

    public static synchronized void start() {
        if (running)
            return;
        try {
            server = new ServerSocket(PORT, 50, InetAddress.getByName(HOST));
            running = true;
            Thread acceptThread = new Thread(() -> acceptLoop(), "elder-souls-agent-gateway");
            acceptThread.setDaemon(true);
            acceptThread.start();
            System.out.println("[Elder Souls Agent] Local gateway listening on http://" + HOST + ":" + PORT);
        } catch (Throwable t) {
            System.err.println("[Elder Souls Agent] Failed to start local gateway: " + t.getMessage());
            t.printStackTrace();
        }
    }

    public static synchronized void stop() {
        running = false;
        try {
            if (server != null)
                server.close();
        } catch (Throwable ignored) {
        }
        server = null;
    }

    private static void acceptLoop() {
        while (running) {
            try {
                final Socket socket = server.accept();
                Thread worker = new Thread(() -> handle(socket), "elder-souls-agent-request");
                worker.setDaemon(true);
                worker.start();
            } catch (Throwable t) {
                if (running)
                    t.printStackTrace();
            }
        }
    }

    private static void handle(Socket socket) {
        try (Socket s = socket;
             BufferedReader in = new BufferedReader(new InputStreamReader(s.getInputStream(), StandardCharsets.UTF_8));
             BufferedWriter out = new BufferedWriter(new OutputStreamWriter(s.getOutputStream(), StandardCharsets.UTF_8))) {

            s.setSoTimeout(5000);
            String first = in.readLine();
            if (first == null || first.length() == 0)
                return;

            String line;
            while ((line = in.readLine()) != null && line.length() != 0) {
            }

            String[] request = first.split(" ");
            if (request.length < 2) {
                write(out, 400, error("bad_request", "Malformed request line."));
                return;
            }

            String method = request[0].toUpperCase();
            String target = request[1];

            if ("OPTIONS".equals(method)) {
                write(out, 200, "{\"ok\":true}");
                return;
            }
            if (!"GET".equals(method) && !"POST".equals(method)) {
                write(out, 405, error("method_not_allowed", "Use GET or POST."));
                return;
            }

            String path = target;
            String query = "";
            int q = target.indexOf('?');
            if (q >= 0) {
                path = target.substring(0, q);
                query = target.substring(q + 1);
            }

            Map<String, String> params = parseQuery(query);

            if ("/health".equals(path) || "/api/v1/health".equals(path)) {
                write(out, 200, "{\"ok\":true,\"service\":\"elder-souls-agent-gateway\",\"version\":\"1.0\",\"host\":\"127.0.0.1\",\"port\":7780}");
                return;
            }

            if ("/players".equals(path) || "/api/v1/players".equals(path)) {
                write(out, 200, playersJson());
                return;
            }

            if ("/state".equals(path) || "/api/v1/state".equals(path)) {
                Player player = requirePlayer(params);
                if (player == null) {
                    write(out, 404, error("player_not_found", "Supply ?player=<username> for an online character."));
                    return;
                }
                write(out, 200, stateJson(player));
                return;
            }

            if ("/action".equals(path) || "/api/v1/action".equals(path)) {
                Player player = requirePlayer(params);
                if (player == null) {
                    write(out, 404, error("player_not_found", "Supply ?player=<username> for an online character."));
                    return;
                }
                write(out, 200, runAction(player, params));
                return;
            }

            if ("/schema".equals(path) || "/api/v1/schema".equals(path)) {
                write(out, 200, schemaJson());
                return;
            }

            write(out, 404, error("not_found", "Unknown Elder Souls agent endpoint."));
        } catch (Throwable t) {
            try {
                t.printStackTrace();
            } catch (Throwable ignored) {
            }
        }
    }

    private static Player requirePlayer(Map<String, String> params) {
        String name = params.get("player");
        if (name == null || name.trim().length() == 0)
            return null;
        for (Player p : World.getPlayers()) {
            if (p == null || p.hasFinished())
                continue;
            if (p.getUsername() != null && p.getUsername().equalsIgnoreCase(name.trim()))
                return p;
        }
        return null;
    }

    private static String playersJson() {
        StringBuilder b = new StringBuilder(256);
        b.append("{\"ok\":true,\"players\":[");
        boolean first = true;
        for (Player p : World.getPlayers()) {
            if (p == null || p.hasFinished())
                continue;
            if (!first)
                b.append(',');
            first = false;
            b.append("{\"username\":\"").append(json(p.getUsername())).append("\",")
             .append("\"x\":").append(p.getX()).append(',')
             .append("\"y\":").append(p.getY()).append(',')
             .append("\"plane\":").append(p.getPlane()).append('}');
        }
        b.append("]}");
        return b.toString();
    }

    private static String stateJson(Player p) {
        StringBuilder b = new StringBuilder(8192);
        b.append("{\"ok\":true,\"player\":{");
        b.append("\"username\":\"").append(json(p.getUsername())).append("\",");
        b.append("\"x\":").append(p.getX()).append(',');
        b.append("\"y\":").append(p.getY()).append(',');
        b.append("\"plane\":").append(p.getPlane()).append(',');
        b.append("\"hp\":").append(p.getHitpoints()).append(',');
        b.append("\"maxHp\":").append(p.getMaxHitpoints()).append(',');
        b.append("\"runEnergy\":").append(p.getRunEnergy() & 0xff).append(',');
        b.append("\"dead\":").append(p.isDead());

        b.append(",\"skills\":[");
        int skillCount = Math.min(Skills.SKILL_NAME.length, p.getSkills().getLevels().length);
        for (int i = 0; i < skillCount; i++) {
            if (i != 0)
                b.append(',');
            b.append("{\"id\":").append(i)
             .append(",\"name\":\"").append(json(Skills.SKILL_NAME[i])).append("\"")
             .append(",\"level\":").append(p.getSkills().getLevel(i))
             .append(",\"baseLevel\":").append(p.getSkills().getLevelForXp(i))
             .append(",\"xp\":").append((long)p.getSkills().getXp(i))
             .append('}');
        }
        b.append(']');

        b.append(",\"inventory\":[");
        Item[] inv = p.getInventory().getItems().getItems();
        boolean first = true;
        for (int i = 0; i < inv.length; i++) {
            Item item = inv[i];
            if (item == null)
                continue;
            if (!first)
                b.append(',');
            first = false;
            b.append(itemJson(item, i));
        }
        b.append(']');

        b.append(",\"equipment\":[");
        Item[] equipment = p.getEquipment().getItems().getItems();
        first = true;
        for (int i = 0; i < equipment.length; i++) {
            Item item = equipment[i];
            if (item == null)
                continue;
            if (!first)
                b.append(',');
            first = false;
            b.append(itemJson(item, i));
        }
        b.append(']');

        b.append(",\"nearbyNpcs\":[");
        first = true;
        for (NPC npc : World.getNPCs()) {
            if (npc == null || npc.hasFinished() || npc.isDead() || npc.getPlane() != p.getPlane())
                continue;
            int dist = distance(p.getX(), p.getY(), npc.getX(), npc.getY());
            if (dist > 20)
                continue;
            if (!first)
                b.append(',');
            first = false;
            String npcName;
            try {
                npcName = npc.getDefinitions().getName();
            } catch (Throwable t) {
                npcName = "npc-" + npc.getId();
            }
            b.append("{\"id\":").append(npc.getId())
             .append(",\"name\":\"").append(json(npcName)).append("\"")
             .append(",\"combatLevel\":").append(npc.getCombatLevel())
             .append(",\"hp\":").append(npc.getHitpoints())
             .append(",\"maxHp\":").append(npc.getMaxHitpoints())
             .append(",\"x\":").append(npc.getX())
             .append(",\"y\":").append(npc.getY())
             .append(",\"plane\":").append(npc.getPlane())
             .append(",\"distance\":").append(dist)
             .append('}');
        }
        b.append("]}}");
        return b.toString();
    }

    private static String itemJson(Item item, int slot) {
        String name;
        try {
            name = item.getName();
        } catch (Throwable t) {
            name = "item-" + item.getId();
        }
        return new StringBuilder(128)
                .append("{\"slot\":").append(slot)
                .append(",\"id\":").append(item.getId())
                .append(",\"name\":\"").append(json(name)).append("\"")
                .append(",\"amount\":").append(item.getAmount())
                .append('}')
                .toString();
    }

    private static String runAction(Player player, Map<String, String> p) {
        String type = value(p, "type", "").toLowerCase();
        try {
            synchronized (player) {
                if ("walk".equals(type)) {
                    int x = integer(p, "x", player.getX());
                    int y = integer(p, "y", player.getY());
                    int maxSteps = integer(p, "maxSteps", 25);
                    if (maxSteps < 1)
                        maxSteps = 1;
                    if (maxSteps > 25)
                        maxSteps = 25;
                    boolean accepted = player.addWalkSteps(x, y, maxSteps, true);
                    return actionResult(type, accepted, accepted ? "walking" : "path_rejected",
                            "\"x\":" + x + ",\"y\":" + y);
                }

                if ("attack_npc".equals(type) || "attack".equals(type)) {
                    int npcId = integer(p, "npcId", -1);
                    String name = value(p, "name", "");
                    NPC target = nearestNpc(player, npcId, name);
                    if (target == null)
                        return actionResult(type, false, "npc_not_found", null);
                    boolean accepted = player.getActionManager().setAction(new PlayerCombat(target));
                    return actionResult(type, accepted, accepted ? "combat_started" : "combat_rejected",
                            "\"npcId\":" + target.getId() + ",\"x\":" + target.getX() + ",\"y\":" + target.getY());
                }

                if ("equip".equals(type) || "wear".equals(type) || "wield".equals(type)) {
                    int slot = integer(p, "slot", -1);
                    if (slot < 0 || slot >= player.getInventory().getItems().getItems().length)
                        return actionResult(type, false, "invalid_inventory_slot", null);
                    Item item = player.getInventory().getItems().get(slot);
                    if (item == null)
                        return actionResult(type, false, "empty_inventory_slot", null);
                    int itemId = item.getId();
                    ButtonHandler.sendWear(player, new int[] { slot });
                    return actionResult(type, true, "equip_requested",
                            "\"slot\":" + slot + ",\"itemId\":" + itemId);
                }

                if ("bank_open".equals(type)) {
                    player.getBank().openBank();
                    return actionResult(type, true, "bank_opened", null);
                }

                if ("bank_deposit_all".equals(type)) {
                    player.getBank().depositAllInventory(false);
                    return actionResult(type, true, "inventory_deposited", null);
                }

                if ("bank_deposit".equals(type)) {
                    int slot = integer(p, "slot", -1);
                    int amount = integer(p, "amount", 1);
                    if (slot < 0 || slot > 27 || amount < 1)
                        return actionResult(type, false, "invalid_bank_deposit", null);
                    boolean ok = player.getBank().depositItem(slot, amount, true);
                    return actionResult(type, ok, ok ? "deposited" : "deposit_rejected",
                            "\"slot\":" + slot + ",\"amount\":" + amount);
                }

                if ("bank_withdraw".equals(type)) {
                    int itemId = integer(p, "itemId", -1);
                    int amount = integer(p, "amount", 1);
                    if (itemId < 0 || amount < 1)
                        return actionResult(type, false, "invalid_bank_withdraw", null);
                    int[] bankSlot = player.getBank().getItemSlot(itemId);
                    if (bankSlot == null)
                        return actionResult(type, false, "item_not_in_bank", "\"itemId\":" + itemId);
                    player.getBank().withdrawItem(bankSlot, amount);
                    return actionResult(type, true, "withdraw_requested",
                            "\"itemId\":" + itemId + ",\"amount\":" + amount);
                }

                if ("state".equals(type)) {
                    return stateJson(player);
                }
            }
        } catch (Throwable t) {
            t.printStackTrace();
            return actionResult(type, false, "exception", "\"message\":\"" + json(t.getMessage()) + "\"");
        }

        return actionResult(type, false, "unknown_action", null);
    }

    private static NPC nearestNpc(Player player, int npcId, String name) {
        NPC best = null;
        int bestDistance = Integer.MAX_VALUE;
        for (NPC npc : World.getNPCs()) {
            if (npc == null || npc.hasFinished() || npc.isDead() || npc.getPlane() != player.getPlane())
                continue;
            if (npcId >= 0 && npc.getId() != npcId)
                continue;
            if (name != null && name.trim().length() > 0) {
                String npcName;
                try {
                    npcName = npc.getDefinitions().getName();
                } catch (Throwable t) {
                    continue;
                }
                if (npcName == null || !npcName.toLowerCase().contains(name.trim().toLowerCase()))
                    continue;
            }
            int dist = distance(player.getX(), player.getY(), npc.getX(), npc.getY());
            if (dist <= 32 && dist < bestDistance) {
                best = npc;
                bestDistance = dist;
            }
        }
        return best;
    }

    private static int distance(int x1, int y1, int x2, int y2) {
        return Math.max(Math.abs(x1 - x2), Math.abs(y1 - y2));
    }

    private static String schemaJson() {
        return "{"
                + "\"ok\":true,"
                + "\"version\":\"1.0\","
                + "\"endpoints\":["
                + "{\"method\":\"GET\",\"path\":\"/api/v1/health\"},"
                + "{\"method\":\"GET\",\"path\":\"/api/v1/players\"},"
                + "{\"method\":\"GET\",\"path\":\"/api/v1/state\",\"params\":[\"player\"]},"
                + "{\"method\":\"POST\",\"path\":\"/api/v1/action\",\"params\":[\"player\",\"type\"]}"
                + "],"
                + "\"actions\":{"
                + "\"walk\":{\"params\":[\"x\",\"y\",\"maxSteps\"]},"
                + "\"attack_npc\":{\"params\":[\"npcId|name\"]},"
                + "\"equip\":{\"params\":[\"slot\"]},"
                + "\"bank_open\":{\"params\":[]},"
                + "\"bank_deposit_all\":{\"params\":[]},"
                + "\"bank_deposit\":{\"params\":[\"slot\",\"amount\"]},"
                + "\"bank_withdraw\":{\"params\":[\"itemId\",\"amount\"]},"
                + "\"state\":{\"params\":[]}"
                + "}"
                + "}";
    }

    private static String actionResult(String action, boolean ok, String result, String extraFields) {
        StringBuilder b = new StringBuilder(192);
        b.append("{\"ok\":").append(ok)
         .append(",\"action\":\"").append(json(action)).append("\"")
         .append(",\"result\":\"").append(json(result)).append("\"");
        if (extraFields != null && extraFields.length() > 0)
            b.append(',').append(extraFields);
        b.append('}');
        return b.toString();
    }

    private static Map<String, String> parseQuery(String query) {
        Map<String, String> result = new LinkedHashMap<String, String>();
        if (query == null || query.length() == 0)
            return result;
        for (String part : query.split("&")) {
            if (part.length() == 0)
                continue;
            int eq = part.indexOf('=');
            String k = eq < 0 ? part : part.substring(0, eq);
            String v = eq < 0 ? "" : part.substring(eq + 1);
            result.put(decode(k), decode(v));
        }
        return result;
    }

    private static String decode(String value) {
        try {
            return URLDecoder.decode(value, "UTF-8");
        } catch (Throwable t) {
            return value;
        }
    }

    private static String value(Map<String, String> p, String key, String fallback) {
        String v = p.get(key);
        return v == null ? fallback : v;
    }

    private static int integer(Map<String, String> p, String key, int fallback) {
        try {
            String v = p.get(key);
            return v == null ? fallback : Integer.parseInt(v);
        } catch (Throwable t) {
            return fallback;
        }
    }

    private static String json(String s) {
        if (s == null)
            return "";
        StringBuilder out = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\': out.append("\\\\"); break;
                case '"': out.append("\\\""); break;
                case '\n': out.append("\\n"); break;
                case '\r': out.append("\\r"); break;
                case '\t': out.append("\\t"); break;
                default:
                    if (c < 32)
                        out.append(String.format("\\u%04x", (int)c));
                    else
                        out.append(c);
            }
        }
        return out.toString();
    }

    private static String error(String code, String message) {
        return "{\"ok\":false,\"error\":\"" + json(code) + "\",\"message\":\"" + json(message) + "\"}";
    }

    private static void write(BufferedWriter out, int status, String body) throws Exception {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        String statusText = status == 200 ? "OK"
                : status == 400 ? "Bad Request"
                : status == 404 ? "Not Found"
                : status == 405 ? "Method Not Allowed"
                : "Error";
        out.write("HTTP/1.1 " + status + " " + statusText + "\r\n");
        out.write("Content-Type: application/json; charset=utf-8\r\n");
        out.write("Content-Length: " + bytes.length + "\r\n");
        out.write("Access-Control-Allow-Origin: *\r\n");
        out.write("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
        out.write("Access-Control-Allow-Headers: Content-Type\r\n");
        out.write("Connection: close\r\n");
        out.write("\r\n");
        out.write(body);
        out.flush();
    }
}
'@

Set-Content "$javaDir/ElderSoulsAgentGateway.java" $gateway -NoNewline

$gameLauncher = "$serverRoot/src/main/java/com/rs/GameLauncher.java"
if (-not (Test-Path $gameLauncher)) { throw "GameLauncher.java not found" }
$gl = Get-Content $gameLauncher -Raw
$nl = [Environment]::NewLine

if (-not $gl.Contains('import com.rs.tools.ElderSoulsAgentGateway;')) {
    $packageNeedle = 'package com.rs;'
    if (-not $gl.Contains($packageNeedle)) { throw "GameLauncher package declaration not found" }
    $gl = $gl.Replace($packageNeedle, $packageNeedle + $nl + $nl + 'import com.rs.tools.ElderSoulsAgentGateway;')
}

$startNeedle = 'World.init();'
if (-not $gl.Contains($startNeedle)) { throw "World.init() hook not found in GameLauncher" }
if (-not $gl.Contains('ElderSoulsAgentGateway.start();')) {
    $gl = $gl.Replace($startNeedle, $startNeedle + $nl + '        ElderSoulsAgentGateway.start();')
}

Set-Content $gameLauncher $gl -NoNewline

Write-Host 'Applied Elder Souls local AI agent gateway on 127.0.0.1:7780.'
