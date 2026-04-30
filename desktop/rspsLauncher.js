const child_process = require('child_process');
const path = require('path');
const bootstrap = require('./rspsBootstrap');
const config = require('./rspsConfig');

async function launchRSPS() {
  await bootstrap.ensureFiles();

  const serverPath = path.join(bootstrap.baseDir, config.downloads.server.folderName);
  const clientPath = path.join(bootstrap.baseDir, config.downloads.client.folderName);

  child_process.spawn('gradlew.bat', [config.launch.loginTask], { cwd: serverPath, shell: true });

  setTimeout(() => {
    child_process.spawn('gradlew.bat', [config.launch.gameTask], { cwd: serverPath, shell: true });
  }, 5000);

  setTimeout(() => {
    child_process.spawn('gradlew.bat', [config.launch.clientTask], { cwd: clientPath, shell: true });
  }, 10000);
}

module.exports = { launchRSPS };