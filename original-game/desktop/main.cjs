const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const { autoUpdater } = require("electron-updater");

let splash;
let gameWindow;
let updateFinished = false;

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

  if (splash) {
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
  if (updateFinished) return;
  updateFinished = true;
  setTimeout(createGameWindow, delay);
}

function wireUpdater() {
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.allowPrerelease = false;

  autoUpdater.on("checking-for-update", () => {
    sendUpdateStatus("Checking for updates...", "Connecting to Elder Souls releases on GitHub");
  });

  autoUpdater.on("update-available", (info) => {
    sendUpdateStatus("Update found", `Downloading Elder Souls ${info.version}...`);
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
    sendUpdateStatus("Update ready", `Installing Elder Souls ${info.version}...`);
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

  wireUpdater();

  try {
    await autoUpdater.checkForUpdates();
  } catch (error) {
    console.error("[Updater check]", error);
    sendUpdateStatus("Update check unavailable", "Starting the installed version.");
    continueToGame(1100);
  }
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
