const { app, BrowserWindow } = require("electron");
const path = require("path");
const https = require("https");
const { autoUpdater } = require("electron-updater");

const RELEASE_PREFIX = "elder-souls-original-v";
const RELEASE_API = "/repos/archeabelief-hash/ciphered-souls-private-server-/releases?per_page=50";
const RELEASE_DOWNLOAD_ROOT = "https://github.com/archeabelief-hash/ciphered-souls-private-server-/releases/download/";

let splash;
let gameWindow;
let launchResolved = false;

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
}

function createSplash() {
  splash = new BrowserWindow({
    width: 520,
    height: 300,
    resizable: false,
    maximizable: false,
    minimizable: false,
    frame: false,
    show: false,
    backgroundColor: "#0d0b09",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  splash.loadFile(path.join(__dirname, "updater.html"));
  splash.once("ready-to-show", () => splash.show());
}

function createGameWindow() {
  if (gameWindow) return;

  gameWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1000,
    minHeight: 700,
    backgroundColor: "#0b0a08",
    autoHideMenuBar: true,
    title: "Elder Souls",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  gameWindow.loadFile(path.join(__dirname, "..", "dist", "index.html"));
  gameWindow.on("closed", () => {
    gameWindow = null;
  });

  if (splash && !splash.isDestroyed()) {
    splash.close();
    splash = null;
  }
}

function sendUpdateStatus(message, detail = "") {
  if (splash && !splash.isDestroyed()) {
    splash.webContents.send("elder-souls-update-status", { message, detail });
  }
}

function continueToGame(delay = 500) {
  if (launchResolved) return;
  launchResolved = true;
  setTimeout(createGameWindow, delay);
}

function parseVersionFromTag(tag) {
  if (typeof tag !== "string" || !tag.startsWith(RELEASE_PREFIX)) return null;
  const version = tag.slice(RELEASE_PREFIX.length);
  if (!/^\d+\.\d+\.\d+$/.test(version)) return null;
  return version;
}

function compareVersions(a, b) {
  const pa = String(a).split(".").map((n) => Number(n) || 0);
  const pb = String(b).split(".").map((n) => Number(n) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const av = pa[i] || 0;
    const bv = pb[i] || 0;
    if (av > bv) return 1;
    if (av < bv) return -1;
  }
  return 0;
}

function fetchOriginalReleases() {
  return new Promise((resolve, reject) => {
    const req = https.get({
      hostname: "api.github.com",
      path: RELEASE_API,
      headers: {
        "User-Agent": "Elder-Souls-Updater",
        "Accept": "application/vnd.github+json"
      }
    }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => { body += chunk; });
      res.on("end", () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`GitHub release API returned HTTP ${res.statusCode}`));
          return;
        }
        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(error);
        }
      });
    });

    req.setTimeout(8000, () => {
      req.destroy(new Error("GitHub update check timed out."));
    });
    req.on("error", reject);
  });
}

async function findLatestOriginalRelease() {
  const releases = await fetchOriginalReleases();
  const candidates = releases
    .filter((release) => !release.draft && !release.prerelease)
    .map((release) => ({
      tag: release.tag_name,
      version: parseVersionFromTag(release.tag_name)
    }))
    .filter((release) => release.version);

  candidates.sort((a, b) => compareVersions(b.version, a.version));
  return candidates[0] || null;
}

function wireUpdaterEvents() {
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.allowPrerelease = false;

  autoUpdater.on("checking-for-update", () => {
    sendUpdateStatus("Checking Elder Souls files...", "Comparing this installation with the newest game release");
  });

  autoUpdater.on("update-available", (info) => {
    sendUpdateStatus("New Elder Souls build found", `Downloading version ${info.version}...`);
  });

  autoUpdater.on("download-progress", (progress) => {
    const pct = Number(progress.percent || 0).toFixed(1);
    const mb = Number(progress.transferred || 0) / 1024 / 1024;
    const total = Number(progress.total || 0) / 1024 / 1024;
    sendUpdateStatus(`Downloading update... ${pct}%`, `${mb.toFixed(1)} MB / ${total.toFixed(1)} MB`);
  });

  autoUpdater.on("update-not-available", () => {
    sendUpdateStatus("Elder Souls is up to date", `Version ${app.getVersion()}`);
    continueToGame(550);
  });

  autoUpdater.on("update-downloaded", (info) => {
    sendUpdateStatus("Update ready", `Installing Elder Souls ${info.version} and restarting...`);
    launchResolved = true;
    setTimeout(() => {
      autoUpdater.quitAndInstall(false, true);
    }, 900);
  });

  autoUpdater.on("error", (error) => {
    sendUpdateStatus("Update check unavailable", "Starting the installed version.");
    console.error("[Updater]", error);
    continueToGame(1100);
  });
}

async function checkForScopedUpdate() {
  sendUpdateStatus("Checking for updates...", "Looking only at original Elder Souls releases");

  const latest = await findLatestOriginalRelease();
  if (!latest) {
    throw new Error("No Elder Souls original releases were found.");
  }

  const current = app.getVersion();
  if (compareVersions(latest.version, current) <= 0) {
    sendUpdateStatus("Elder Souls is up to date", `Version ${current}`);
    continueToGame(550);
    return;
  }

  const feedUrl = RELEASE_DOWNLOAD_ROOT + encodeURIComponent(latest.tag) + "/";
  autoUpdater.setFeedURL({
    provider: "generic",
    url: feedUrl
  });

  sendUpdateStatus("Update found", `Elder Souls ${current} → ${latest.version}`);
  await autoUpdater.checkForUpdates();
}

app.on("second-instance", () => {
  if (gameWindow) {
    if (gameWindow.isMinimized()) gameWindow.restore();
    gameWindow.focus();
  }
});

app.whenReady().then(async () => {
  createSplash();

  if (!app.isPackaged) {
    sendUpdateStatus("Development build", "Automatic updates run in installed builds.");
    continueToGame(500);
    return;
  }

  wireUpdaterEvents();

  try {
    await checkForScopedUpdate();
  } catch (error) {
    console.error("[Scoped updater check]", error);
    sendUpdateStatus("Update check unavailable", "Starting the installed version.");
    continueToGame(1100);
  }
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
