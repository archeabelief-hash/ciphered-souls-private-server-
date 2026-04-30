const { app } = require('electron');
const { launchRSPS } = require('./rspsLauncher');

app.whenReady().then(async () => {
  await launchRSPS();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
