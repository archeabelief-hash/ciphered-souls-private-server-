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
