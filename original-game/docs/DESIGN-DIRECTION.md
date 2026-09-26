# Elder Souls Gameplay & Visual Direction

## Target feel

Elder Souls is intended to feel immediately familiar to players of classic point-and-click fantasy MMORPGs while remaining a clean-room original game.

The target is:
- fixed-tick simulation with a 600 ms world tick
- tile-based point-and-click movement
- click NPC / object / ground interactions
- old-school readable third-person/isometric camera
- deliberate low-poly character and environment art
- readable combat animations and hit feedback
- long-form skill progression
- equipment-driven combat
- banks, shops, drops, quests, gathering, crafting, PvE, PvP regions, trading, clans, chat, and an economy

## What we may emulate

We may independently implement common gameplay ideas and genre conventions:
- 600 ms tick cadence
- tile movement and pathfinding
- combat turn cadence
- attack styles
- melee / ranged / magic-style combat triangle
- XP-based skills and levels
- inventory / equipment / bank loops
- resource nodes
- drops and loot tables
- shops and trading
- quests and dialogue
- safe and dangerous regions
- minimap-style navigation
- click-to-interact controls
- low-poly fantasy presentation

## What must remain original

Do not import, extract, trace, or reproduce proprietary RuneScape / OSRS content.

Elder Souls must use its own:
- source code
- networking protocol
- maps and world geometry
- towns and landmarks
- NPCs and monsters
- character models
- animation clips and keyframe data
- item models and icons
- textures and materials
- UI art and exact layout
- music and sound effects
- quest text and dialogue
- lore and names
- skill names
- item names
- spell names
- logos and branding

Animations may express the same generic actions (walk, run, chop, mine, swing, cast, eat, fish, etc.) but are authored from scratch.

## Visual standard

The art target is not photorealism. It is a polished old-school 3D MMORPG look:
- clean low-poly silhouettes
- slightly exaggerated readable proportions
- compact geometry
- hand-authored materials
- strong equipment silhouettes
- visible weapons and armor
- clear animation poses
- consistent world scale
- higher fidelity than placeholder primitives
- original color language and iconography

## Core engine roadmap

1. Grid world and collision
2. A* tile pathfinding
3. walk / run queues
4. animation state machine
5. object interaction system
6. NPC interaction and aggro
7. combat queue tied to ticks
8. equipment and appearance overrides
9. hitsplats / overhead indicators
10. ground items and loot
11. banks
12. shops
13. crafting pipelines
14. quest/dialogue engine
15. persistent accounts
16. authoritative multiplayer server
17. chat / friends / clans
18. dangerous PvP regions
19. player trading and economy
20. agent API as a native game feature
