const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const { exec } = require('child_process');

// Helper function to convert Windows path to Unix path
function convertWindowsPathToUnix(windowsPath) {
  // Convert the drive letter to lowercase and prepend '/mnt/'
  return windowsPath.replace(/^([a-zA-Z]):\\/, '/mnt/$1/').replace(/\\/g, '/');
}

function createWindow() {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true, // Allow using require in renderer
      contextIsolation: false, // For simplicity in this example
    },
  });

  win.loadFile('index.html');
}

app.whenReady().then(createWindow);


// Listen for the 'open-folder-dialog' IPC call from renderer.js
ipcMain.handle('open-folder-dialog', async (event) => {
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory'],
  });
  if (!result.canceled && result.filePaths && result.filePaths.length > 0) {
    return result.filePaths[0];
  }
  return null;
});

// Handle the 'rename-images' action from renderer.js
ipcMain.handle('rename-images', (event, { sourceFolder, destinationFolder, filePattern }) => {
  // Convert paths to Unix format for WSL compatibility
  const sourceFolderUnix = convertWindowsPathToUnix(sourceFolder);
  const destinationFolderUnix = convertWindowsPathToUnix(destinationFolder);
  //console.log("WSL Path Check:");
  //console.log("process.env.PATH:", process.env.PATH);
  
    // Log paths for debugging
    //console.log(`Window path to source folder: ${sourceFolder}`);
    //console.log(`Window path to destination folder: ${destinationFolder}`);
    //console.log(`Linux path to source folder: ${sourceFolderUnix}`);
    //console.log(`Linux path to destination folder: ${destinationFolderUnix}`);

  // Build the bash command with converted paths
  const bashCommand = `bash ./code/rename_barcode.sh "${sourceFolderUnix}" "${destinationFolderUnix}" "${filePattern}"`;

  // Execute the bash script
  exec(bashCommand, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing script: ${error.message}`);
      return;
    }
    if (stderr) {
      console.error(`stderr: ${stderr}`);
      return;
    }
    console.log(`stdout: ${stdout}`);
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});