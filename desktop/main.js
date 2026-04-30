const { app, BrowserWindow } = require('electron');
const { spawn } = require('child_process');

let serverProcess;

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    autoHideMenuBar: true
  });

  setTimeout(() => {
    win.loadURL('http://localhost:8787?v=desktop');
  }, 2000);
}

app.whenReady().then(() => {
  serverProcess = spawn('npm', ['run', 'dev'], { shell: true });
  createWindow();
});

app.on('window-all-closed', () => {
  if (serverProcess) serverProcess.kill();
  if (process.platform !== 'darwin') app.quit();
});
