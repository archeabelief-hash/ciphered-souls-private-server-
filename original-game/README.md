# Elder Souls — Original Clean-Room Game

This branch is the beginning of a completely original game codebase inspired by the feel and pacing of classic point-and-click fantasy MMORPGs.

**No Matrix server code, RuneScape client code, Jagex cache files, RuneScape models, textures, maps, sounds, NPCs, quest text, item names, or other proprietary game content are used by this prototype.**

## Current playable prototype

- original low-poly procedural visuals made from primitive geometry
- angled old-school 3D camera
- click-to-move
- 600 ms simulation tick
- original skill names and independent XP curve
- combat
- gathering
- inventory
- equipment
- resource depletion/respawn
- NPC death/respawn
- original world objects and creature names
- local character state in memory

## Run

Requires Node.js 20+.

```bash
npm install
npm run dev
```

Then open the Vite URL shown in the terminal.

## Build

```bash
npm run build
```

The production game is emitted to `dist/`.

## Direction

The clean-room roadmap is to grow this into the actual Elder Souls game rather than a private-server derivative:

1. tile/pathfinding engine
2. original world regions
3. persistent accounts and saves
4. authoritative multiplayer server
5. banks, shops and trade
6. full combat triangle: Bladework/Marksmanship/Heka
7. gathering and artisan professions
8. quests and dialogue
9. original models, animation rigs, music and sound
10. autonomous-agent API as a first-class feature


## Windows installer and automatic updates

Elder Souls now has a normal one-click Windows installer built with Electron + NSIS.

Installed builds run the Elder Souls updater before opening the game. On every launch it:

1. checks the public GitHub Releases feed,
2. compares the installed semantic version,
3. downloads a newer release automatically when one exists,
4. installs it,
5. restarts into the updated game.

The updater is fail-open: if GitHub is unavailable, the currently installed game still starts.

Release builds include Electron differential-update metadata (`latest.yml` and blockmap files), so future releases can update without requiring the player to manually download the installer again.

A manual reinstall is only expected if the updater/bootstrap layer itself is broken or deliberately replaced.
