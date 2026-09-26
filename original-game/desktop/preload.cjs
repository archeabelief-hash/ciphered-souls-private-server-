const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("elderSoulsDesktop", {
  version: process.versions.electron,
  onUpdateStatus(callback) {
    const handler = (_event, payload) => callback(payload);
    ipcRenderer.on("elder-souls-update-status", handler);
    return () => ipcRenderer.removeListener("elder-souls-update-status", handler);
  }
});
