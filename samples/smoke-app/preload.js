const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('reaDemo', {
  readConfig: (name) => ipcRenderer.invoke('read-config', name),
});
