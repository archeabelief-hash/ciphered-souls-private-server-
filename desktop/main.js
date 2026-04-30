const { app, BrowserWindow } = require('electron');
const path = require('path');
const { startServer } = require(path.join(__dirname, '..', 'src', 'server'));

let mainWindow;
let serverInstance;

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true
    }
  });

  try {
    serverInstance = await startServer(8787, '127.0.0.1');
    await mainWindow.loadURL('http://127.0.0.1:8787/index.html');
  } catch (error) {
    console.error('Failed to start server:', error);
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (serverInstance) serverInstance.close();
  if (process.platform !== 'darwin') app.quit();
});
