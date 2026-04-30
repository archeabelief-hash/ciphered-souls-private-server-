const { app, BrowserWindow, ipcMain } = require('electron');
const { exec } = require('child_process');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('src/index.html');
}

app.whenReady().then(createWindow);

ipcMain.handle('launch-client', async (event, path) => {
  exec(`"${path}"`);
  return true;
});

ipcMain.handle('detect-windows', async () => {
  return new Promise((resolve) => {
    exec(`powershell "Get-Process | Where-Object { $_.MainWindowTitle -like '*RuneLite*' -or $_.MainWindowTitle -like '*Old School RuneScape*' } | Select-Object Id,MainWindowTitle"`, (err, stdout) => {
      resolve(stdout);
    });
  });
});

ipcMain.handle('tile-windows', async () => {
  exec(`powershell -Command \"$sig = '[DllImport(\"user32.dll\")]public static extern bool MoveWindow(IntPtr hWnd,int X,int Y,int nWidth,int nHeight,bool bRepaint);'; add-type -MemberDefinition $sig -Name Win32 -Namespace API; $procs = Get-Process | Where-Object {$_.MainWindowTitle -like '*RuneLite*'}; $i=0; foreach ($p in $procs){ $x = ($i%2)*800; $y = [math]::Floor($i/2)*450; [API.Win32]::MoveWindow($p.MainWindowHandle,$x,$y,800,450,$true); $i++ }\"`);
  return true;
});
