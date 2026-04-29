# Ciphered Souls Remote Testing Through GitHub Codespaces

Use this when you want to run Ciphered Souls from GitHub and open it on your phone browser.

## Start the server

1. Open this repository on GitHub.
2. Press the green `Code` button.
3. Open the `Codespaces` tab.
4. Click `Create codespace on main`.
5. When the Codespace opens, run:

```bash
npm install
npm run dev
```

## Open it on your phone

1. In Codespaces, open the `Ports` tab.
2. Find port `8787`.
3. Set the port visibility to the option GitHub allows for external testing.
4. Copy the forwarded URL.
5. Open that URL on your phone browser.

The URL will look similar to:

```text
https://YOUR-CODESPACE-NAME-8787.app.github.dev
```

## Notes

- GitHub Pages cannot run this server because it only hosts static files.
- Codespaces is the GitHub-contained way to run the Node server remotely.
- Keep the server terminal running while testing.
