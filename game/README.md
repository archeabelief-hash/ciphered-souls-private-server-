# Ciphered Souls — auto-updating game

This folder is the home of the playable Ciphered Souls game. The Windows
launcher (`Play-Elder-Souls.bat`) checks this folder every time the game
starts and installs any newer version automatically — no manual downloads.

## How the updater works

1. The player opens `Play-Elder-Souls.bat`.
2. The launcher reads the local `version.txt` and fetches
   `game/version.txt` from this repo.
3. If the repo version is higher, it reads
   `game/patches/v<VERSION>/parts.txt`, downloads every file listed
   there, extracts them over the install, writes the new `version.txt`,
   and restarts itself.
4. If the download fails or there is no internet, the game starts as-is.

## Shipping a new version

1. Build the changed files.
2. Zip them with paths relative to the install root.
   - `client-*.zip` → `client/classes/**`
   - `server.zip` → `server/classes/**`
   - `misc.zip` → launcher scripts, `version.txt`, extra jars, etc.
3. Upload the zips somewhere with a stable direct-download URL (Google
   Drive works: share "anyone with the link", use the
   `uc?export=download&id=` link).
4. Put a `parts.txt` in `game/patches/v<N>/` listing one
   `filename|download-url` per line, in download order. (A bare filename
   with no URL falls back to this repo's
   `game/patches/v<N>/filename`.)
5. Bump the number in `game/version.txt`.
6. Commit. Every player gets the update next time they open the game.

## First-time install

New players download the full package (client + server + cache + portable
Java) from the Google Drive link, extract it, and double-click
`Play-Elder-Souls.bat`. Everything after that is automatic.
