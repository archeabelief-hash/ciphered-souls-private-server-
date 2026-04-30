# How to Run the Ciphered Souls Windows Client

GitHub.com cannot run `.bat` files from the browser. Clicking a `.bat` file inside the GitHub website only opens the text file. It does not launch the game.

## Option A: Run from Codespaces terminal

Use this if you are still inside GitHub Codespaces.

```bash
npm install
npm run dev
```

Then open the forwarded port `8787` from the Codespaces `Ports` panel.

## Option B: Run on your Windows PC

1. Download or clone the repository to your PC.
2. Open the folder on your computer, not on GitHub.com.
3. Run this once in PowerShell or Command Prompt from the project root:

```bash
npm install
```

4. Open this file from Windows File Explorer:

```text
client\windows\CipheredSoulsClient.bat
```

5. Double-click it.

It will start the Ciphered Souls server and open the local browser client.

## Manual fallback

From the project root, run:

```bash
npm run dev
```

Then open:

```text
http://localhost:8787?v=desktop
```

## Important

- Do not double-click the `.bat` file inside GitHub.com.
- Download/clone the repo first if you want a real Windows launcher.
- Keep the server terminal open while testing.
