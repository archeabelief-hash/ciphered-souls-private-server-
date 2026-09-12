# Ciphered Souls Mobile RSPS Integration

## Goal

Use a mobile RuneLite-derived Android client to connect to the Ciphered Souls OSRS private server while keeping development centered in GitHub.

## Repository separation

```text
apps/
  android-client/       # RuneLite-derived Android client source / decompiled project
  desktop-client/       # Desktop client source
server/
  game-server/          # Authoritative OSRS/RSPS server source
shared/
  protocol/             # Shared packet/opcode/config documentation
infra/
  codespaces/           # Development-only GitHub Codespaces setup
  build/                # GitHub Actions build workflows
docs/
  mobile-rsps-plan.md
```

## Hosting model

GitHub itself is not a production game-server host.

For development, GitHub Codespaces can run the server and forward its TCP port for testing. Codespaces may stop after inactivity and forwarded URLs/visibility can change, so it must not be treated as permanent production hosting.

For production later, keep source/builds in GitHub and deploy the server runtime to a persistent host.

## Mobile client migration

1. Inspect the APK and determine whether source is available.
2. If source exists, import it under `apps/android-client/`.
3. If only an APK exists, decompile only for compatibility analysis, then rebuild a maintainable Android project.
4. Locate game host/port configuration, cache endpoints, revision/protocol assumptions, RSA/ISAAC login handling, and websocket/TCP transport.
5. Point a development build at the Ciphered Souls test server.
6. Keep production and development endpoints in separate build flavors/config files.

## Development server

Codespaces should be used for coding-on-the-go and temporary testing only.

Required tasks once the actual server source is located:

- identify server runtime and Java version
- identify game/login port(s)
- create `.devcontainer/devcontainer.json`
- automatically install dependencies
- expose the test port(s)
- add one command to start the server
- document how to make the port public for a temporary test

## Large files

Do not commit caches, APK binaries, Gradle build outputs, or large game assets directly into normal Git history. Keep source/configuration in GitHub and fetch large runtime assets during setup/build when required.
