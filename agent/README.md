# Elder Souls Agent SDK v1

This folder controls the local Elder Souls Scape server through a structured localhost API.

Gateway: http://127.0.0.1:7780

Endpoints:
- GET /api/v1/health
- GET /api/v1/players
- GET /api/v1/schema
- GET /api/v1/state?player=USERNAME
- POST /api/v1/action?player=USERNAME&type=ACTION&...

Initial actions:
- walk
- attack_npc
- equip
- bank_open
- bank_deposit_all
- bank_deposit
- bank_withdraw
- state

State includes coordinates, HP, run energy, skills, inventory, equipment, and nearby NPCs.

## Quick autonomous test

Start Elder Souls Scape and log your character in. Then open PowerShell in this folder and run:

    .\demo-combat-agent.ps1 -Player "YOUR_USERNAME"

The demo equips the Duat Khopesh when present, attacks the nearest visible NPC, and wanders when no NPC is available.

## Connect an AI model

llm-agent.ps1 works with an OpenAI-compatible chat-completions endpoint, including compatible local model servers.

Set these PowerShell environment variables:

    $env:ELDER_SOULS_LLM_URL="http://127.0.0.1:YOUR_PORT/v1/chat/completions"
    $env:ELDER_SOULS_LLM_MODEL="YOUR_MODEL"

If the endpoint requires a key:

    $env:ELDER_SOULS_LLM_API_KEY="YOUR_KEY"

Then run:

    .\llm-agent.ps1 -Player "YOUR_USERNAME"

The model receives structured game state and returns one structured action at a time. No screen scraping, image recognition, or mouse automation is required.

## Security

The gateway is hard-bound to 127.0.0.1 and is intended only for this local private game build.
