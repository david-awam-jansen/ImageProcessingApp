const { ipcRenderer } = require('electron');

// Helper function to attach a click event for a "Browse" button
function setupBrowseButton(buttonId, inputId) {
  const button = document.getElementById(buttonId);
  const inputField = document.getElementById(inputId);

  button.addEventListener('click', () => {
    // Send an IPC message to open a folder dialog
    ipcRenderer.invoke('open-folder-dialog').then((selectedPath) => {
      if (selectedPath) {
        inputField.value = selectedPath;  // No conversion here, just set the Windows path
      }
    });
  });
}

// Set up the two browse buttons
setupBrowseButton('browse-source', 'source-folder');
setupBrowseButton('browse-dest', 'destination-folder');

// Handle Rename Images button click
document.getElementById('rename-images').addEventListener('click', () => {
    const sourceFolder = document.getElementById('source-folder').value; // Get source folder value
    const destinationFolder = document.getElementById('destination-folder').value; // Get destination folder value
    const filePattern = document.getElementById('file-pattern').value; // Get file pattern value
  
    // Send the data to main process with original Windows paths
    ipcRenderer.invoke('rename-images', { sourceFolder, destinationFolder, filePattern });
});
