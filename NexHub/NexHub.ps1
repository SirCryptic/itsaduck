# NEXHub.ps1
# Professional Local Listener & Server Hub with Settings Submenu and Ncat Support
# Developed by SirCryptic

# Check for admin privileges and elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating to admin privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-File `"$PSCommandPath`""
    exit
}

function Write-Gradient {
    param ([string]$Text, [ConsoleColor[]]$Colors)
    $length = $Text.Length
    for ($i = 0; $i -lt $length; $i++) {
        $colorIndex = [math]::Floor(($i / $length) * ($Colors.Length - 1))
        Write-Host $Text[$i] -NoNewline -ForegroundColor $Colors[$colorIndex]
    }
    Write-Host ""
}

function Show-Header {
    Clear-Host
    Write-Gradient "=== NEXHub Control Center ===" -Colors Cyan,Blue,DarkBlue
    $listenerStatus = if (Test-ConnectionStatus) { "[OK] Connected" } else { "[X] Not Connected" }
    Write-Host "Listener: $global:listenerIP`:$global:listenerPort  Status: $listenerStatus" -ForegroundColor Magenta
    $serverStatus = if (Test-ServerStatus) { "[OK] Running" } else { "[X] Stopped" }
    $serverDisplay = if (Test-ServerStatus -and $global:serverUrl) { $global:serverUrl } else { "Not Started" }
    Write-Host "Server: $serverDisplay  Status: $serverStatus" -ForegroundColor Green
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Local Listener and Server Management Hub" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-MainMenu {
    Write-Host "Main Menu:" -ForegroundColor Yellow
    Write-Host "  1. " -NoNewline; Write-Gradient "Settings" -Colors Green,Cyan
    Write-Host "  2. " -NoNewline; Write-Gradient "Start Listener" -Colors Green,Cyan
    Write-Host "  3. " -NoNewline; Write-Gradient "Start Web Server" -Colors Green,Cyan
    Write-Host "  4. " -NoNewline; Write-Gradient "Stop All Services" -Colors Green,Cyan
    Write-Host "  5. " -NoNewline; Write-Gradient "View Server Logs" -Colors Green,Cyan
    Write-Host "  6. " -NoNewline; Write-Gradient "Watch Logs Live" -Colors Green,Cyan
    Write-Host "  7. " -NoNewline; Write-Gradient "Exit" -Colors Red,Magenta
    Write-Host "Enter choice (1-7): " -NoNewline -ForegroundColor Yellow
}

function Show-SettingsMenu {
    Clear-Host
    Write-Gradient "=== Settings ===" -Colors Cyan,Blue,DarkBlue
    Write-Host "Settings Options:" -ForegroundColor Yellow
    Write-Host "  1. " -NoNewline; Write-Gradient "Set Listener IP/Port" -Colors Green,Cyan
    Write-Host "  2. " -NoNewline; Write-Gradient "Set Server IP" -Colors Green,Cyan
    Write-Host "  3. " -NoNewline; Write-Gradient "Back to Main Menu" -Colors Green,Cyan
    Write-Host "Enter choice (1-3): " -NoNewline -ForegroundColor Yellow
}

function Test-ConnectionStatus {
    $ncatRunning = Get-Process -Name "ncat" -ErrorAction SilentlyContinue
    return $null -ne $ncatRunning
}

function Test-ServerStatus {
    Start-Sleep -Seconds 3  # Delay for PHP server to register
    $phpRunning = Get-Process -Name "php" -ErrorAction SilentlyContinue
    return $null -ne $phpRunning
}

function Get-Config {
    $configFile = "$PSScriptRoot\config.json"
    if (Test-Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        $global:listenerIP = $config.listenerIP
        $global:listenerPort = $config.listenerPort
        $global:serverIP = $config.serverIP
        Write-Host "Loaded Listener IP: $global:listenerIP, Port: $global:listenerPort, Server IP: $global:serverIP" -ForegroundColor Green
    } else {
        $global:listenerIP = "192.168.1.115"
        $global:listenerPort = "4444"
        $global:serverIP = "127.0.0.1"  # Default to localhost
        Write-Host "Set default Listener IP: $global:listenerIP, Port: $global:listenerPort, Server IP: $global:serverIP" -ForegroundColor Green
    }
}

function Save-Config {
    $config = @{ 
        listenerIP = $global:listenerIP
        listenerPort = $global:listenerPort
        serverIP = $global:serverIP
    }
    $config | ConvertTo-Json | Set-Content "$PSScriptRoot\config.json"
}

function Set-ListenerIPPort {
    $newIP = Read-Host "Enter Listener IP (current: $global:listenerIP)"
    if ($newIP) { $global:listenerIP = $newIP }
    $newPort = Read-Host "Enter Listener port (current: $global:listenerPort)"
    if ($newPort) { $global:listenerPort = $newPort }
    Save-Config
    Write-Host "Listener IP set to $global:listenerIP, Port set to $global:listenerPort" -ForegroundColor Cyan
    Show-Progress -Message "Settings Saved" -Duration 3
    Write-Host "Press any key to return..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Set-ServerIP {
    $newIP = Read-Host "Enter Server IP (current: $global:serverIP, default: 127.0.0.1)"
    if ($newIP) { $global:serverIP = $newIP }
    Save-Config
    Write-Host "Server IP set to $global:serverIP" -ForegroundColor Cyan
    Show-Progress -Message "Settings Saved" -Duration 3
    Write-Host "Press any key to return..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-Listener {
    if (-not (Get-Command "ncat" -ErrorAction SilentlyContinue)) {
        Write-Host "Error: ncat not found! Please install Nmap (includes ncat) from https://nmap.org/download.html" -ForegroundColor Red
        Write-Host "Press any key to return..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    if (Test-ConnectionStatus) {
        Write-Host "Listener already running on $global:listenerIP:$global:listenerPort!" -ForegroundColor Yellow
    } else {
        Write-Host "Starting Ncat listener on $global:listenerIP:$global:listenerPort..." -ForegroundColor Cyan
        Start-Process -FilePath "ncat" -ArgumentList "-lvp $global:listenerPort" -WindowStyle Minimized
        Show-Progress -Message "Listener Active" -Duration 5
    }
    Write-Host "Press any key to return..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-Server {
    if (Test-ServerStatus) {
        Write-Host "Server already running at $global:serverUrl!" -ForegroundColor Yellow
    } else {
        if (-not (Get-Command "php" -ErrorAction SilentlyContinue)) {
            Write-Host "Error: PHP not found! Please install PHP from https://windows.php.net/download/" -ForegroundColor Red
            Write-Host "Press any key to return..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        if (-not (Test-Path $serverDir)) { New-Item -Path $serverDir -ItemType Directory | Out-Null }
        
        # Corrected upload.php content with proper escaping
        $phpUploadContent = @'
<?php
header("Content-Type: application/json");
$response = [];
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_FILES["file"])) {
    $target_dir = "uploads/";
    if (!file_exists($target_dir)) {
        mkdir($target_dir, 0777, true);
    }
    $filename = basename($_FILES["file"]["name"]);
    $target_file = $target_dir . $filename;
    if (file_exists($target_file) && !isset($_POST["overwrite"])) {
        $response["status"] = "confirm";
        $response["message"] = "File '" . $filename . "' already exists. Overwrite it?";
    } else {
        if (move_uploaded_file($_FILES["file"]["tmp_name"], $target_file)) {
            $response["status"] = "success";
            $response["message"] = "File uploaded: " . $filename;
            $files = array_diff(scandir($target_dir), array(".", ".."));
            $response["files"] = array_values($files);
        } else {
            $response["status"] = "error";
            $response["message"] = "Upload failed: " . $_FILES["file"]["error"];
        }
    }
} else {
    $response["status"] = "error";
    $response["message"] = "No file uploaded or invalid request";
}
echo json_encode($response);
?>
'@
        Set-Content -Path $uploadScript -Value $phpUploadContent

        # Existing download.php content
        $phpDownloadContent = @'
<?php
if (isset($_GET["file"])) {
    $file = "uploads/" . basename($_GET["file"]);
    if (file_exists($file)) {
        header("Content-Type: application/octet-stream");
        header("Content-Disposition: attachment; filename=\"" . basename($file) . "\"");
        header("Content-Length: " . filesize($file));
        readfile($file);
        exit;
    } else {
        http_response_code(404);
        echo "File not found";
    }
} else {
    http_response_code(400);
    echo "No file specified";
}
?>
'@
        Set-Content -Path "$serverDir\download.php" -Value $phpDownloadContent

        # Existing index.php content (unchanged for this fix)
        $phpIndexContent = @"
<?php
`$dir = 'uploads/';
if (!file_exists(`$dir)) { mkdir(`$dir, 0777, true); }
`$files = array_diff(scandir(`$dir), array('.', '..'));
if (isset(`$_POST['delete_file'])) {
    `$fileToDelete = `$dir . basename(`$_POST['delete_file']);
    if (file_exists(`$fileToDelete)) {
        unlink(`$fileToDelete);
        header('Location: scns.php'); // Refresh page after deletion
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NexHub Control Center</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🛠️</text></svg>">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Roboto', 'Segoe UI', Arial, sans-serif;
            background: #1a1a2e;
            color: #e0e0e0;
            line-height: 1.6;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: #16213e;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
            border: 1px solid #0f3460;
        }
        h1 {
            font-size: 2.2em;
            color: #00d4ff;
            margin-bottom: 30px;
            text-align: center;
            letter-spacing: 1px;
            text-transform: uppercase;
        }
        .upload {
            background: #0f3460;
            padding: 25px;
            border-radius: 8px;
            margin-bottom: 40px;
            box-shadow: inset 0 2px 10px rgba(0, 0, 0, 0.3);
        }
        .upload form {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 20px;
        }
        .upload input[type="file"] {
            padding: 10px;
            background: #1a1a2e;
            border: 1px solid #00d4ff;
            border-radius: 5px;
            color: #e0e0e0;
            width: 100%;
            max-width: 400px;
            font-size: 1em;
        }
        .upload input[type="submit"] {
            padding: 12px 30px;
            background: #00d4ff;
            border: none;
            border-radius: 5px;
            color: #1a1a2e;
            font-size: 1.1em;
            font-weight: bold;
            text-transform: uppercase;
            cursor: pointer;
            transition: background 0.3s ease, transform 0.2s ease;
        }
        .upload input[type="submit"]:hover {
            background: #00b4d8;
            transform: translateY(-2px);
        }
        .file-list {
            background: #0f3460;
            padding: 25px;
            border-radius: 8px;
            box-shadow: inset 0 2px 10px rgba(0, 0, 0, 0.3);
        }
        .file-list h2 {
            font-size: 1.6em;
            color: #00d4ff;
            margin-bottom: 20px;
            text-align: center;
        }
        .file-list ul {
            list-style: none;
        }
        .file-list li {
            margin: 8px 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 15px;
            background: #1a1a2e;
            border-radius: 5px;
        }
        .file-list .filename {
            color: #00d4ff;
            font-size: 1em;
            flex-grow: 1;
            margin-right: 10px;
        }
        .file-list .filename::before {
            content: "📄 ";
            margin-right: 10px;
        }
        .file-list button {
            padding: 6px 12px;
            border: none;
            border-radius: 5px;
            font-size: 0.9em;
            cursor: pointer;
            transition: background 0.3s ease;
        }
        .file-list .download-btn {
            background: #00d4ff;
            color: #1a1a2e;
            margin-right: 10px;
        }
        .file-list .download-btn:hover {
            background: #00b4d8;
        }
        .file-list .delete-btn {
            background: #ff4d4d;
            color: #fff;
        }
        .file-list .delete-btn:hover {
            background: #cc0000;
        }
        footer {
            text-align: center;
            margin-top: 30px;
            font-size: 0.9em;
            color: #b0b0b0;
        }
        #status {
            text-align: center;
            margin-top: 15px;
            padding: 10px;
            border-radius: 5px;
            display: none;
        }
        #status.success {
            background: #1a3c34;
            color: #00d4ff;
        }
        #status.error {
            background: #4a1a2e;
            color: #ff4d4d;
        }
        #status.confirm {
            background: #3c2f1a;
            color: #ffcc00;
        }
        @media (max-width: 600px) {
            .container {
                padding: 20px;
            }
            h1 {
                font-size: 1.8em;
            }
            .upload, .file-list {
                padding: 15px;
            }
            .file-list li {
                flex-direction: column;
                align-items: flex-start;
            }
            .file-list button {
                margin-top: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>NexHub Control Center</h1>
        <div class="upload">
            <form id="uploadForm" enctype="multipart/form-data" method="POST" action="upload.php">
                <input type="file" name="file" id="fileInput" required>
                <input type="submit" value="Upload File">
            </form>
            <div id="status"></div>
        </div>
        <div class="file-list">
            <h2>Uploaded Files</h2>
            <ul id="fileList">
                <?php foreach (`$files as `$file) { echo "<li><span class='filename'>`$file</span><button class='download-btn' onclick=\"window.location.href='download.php?file=`$file'\">Download</button><form method='POST' onsubmit='return confirmDelete(\"`$file\")'><input type='hidden' name='delete_file' value='`$file'><button type='submit' class='delete-btn'>Delete</button></form></li>"; } ?>
            </ul>
        </div>
        <footer>Developed by SirCryptic</footer>
    </div>
    <script>
        function confirmDelete(filename) {
            return confirm('Are you sure you want to delete ' + filename + '?');
        }

        let lastFormData = null; // Store the last form data for overwrite confirmation

        document.getElementById('uploadForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const formData = new FormData(this);
            const status = document.getElementById('status');
            const fileList = document.getElementById('fileList');

            // If this is an overwrite submission, add the overwrite flag
            if (lastFormData && confirm('Do you want to overwrite the existing file?')) {
                formData.append('overwrite', 'true');
            }

            fetch('/upload.php', {
                method: 'POST',
                body: formData
            })
            .then(response => {
                if (!response.ok) throw new Error('Network response was not ok: ' + response.status);
                return response.json();
            })
            .then(data => {
                status.style.display = 'block';
                status.textContent = data.message;
                status.className = data.status;

                if (data.status === 'success' && data.files) {
                    fileList.innerHTML = '';
                    data.files.forEach(file => {
                        const li = document.createElement('li');
                        const span = document.createElement('span');
                        span.className = 'filename';
                        span.textContent = file;
                        const downloadBtn = document.createElement('button');
                        downloadBtn.className = 'download-btn';
                        downloadBtn.textContent = 'Download';
                        downloadBtn.onclick = () => window.location.href = 'download.php?file=' + encodeURIComponent(file);
                        const form = document.createElement('form');
                        form.method = 'POST';
                        form.onsubmit = () => confirmDelete(file);
                        const input = document.createElement('input');
                        input.type = 'hidden';
                        input.name = 'delete_file';
                        input.value = file;
                        const deleteBtn = document.createElement('button');
                        deleteBtn.type = 'submit';
                        deleteBtn.className = 'delete-btn';
                        deleteBtn.textContent = 'Delete';
                        form.appendChild(input);
                        form.appendChild(deleteBtn);
                        li.appendChild(span);
                        li.appendChild(downloadBtn);
                        li.appendChild(form);
                        fileList.appendChild(li);
                    });
                    lastFormData = null; // Reset after successful upload
                } else if (data.status === 'confirm') {
                    lastFormData = formData; // Store form data for overwrite confirmation
                }

                setTimeout(() => { status.style.display = 'none'; }, 3000);
            })
            .catch(error => {
                status.style.display = 'block';
                status.textContent = 'Upload error: ' + error.message;
                status.className = 'error';
                setTimeout(() => { status.style.display = 'none'; }, 3000);
                lastFormData = null;
            });

            if (!lastFormData) {
                this.reset(); // Only reset form if no confirmation is pending
            }
        });
    </script>
</body>
</html>
"@
        Set-Content -Path "$serverDir\scns.php" -Value $phpIndexContent
        Write-Host "Starting web server at $global:serverIP:80..." -ForegroundColor Cyan
        Start-Process -FilePath "powershell" -ArgumentList "-NoExit -Command cd $serverDir; php -S $global:serverIP`:80" -WindowStyle Minimized
        Show-Progress -Message "Server Initializing" -Duration 3
        if (Test-ServerStatus) {
            $global:serverUrl = "http://$global:serverIP`:80"
            Write-Host "Server started successfully!" -ForegroundColor Green
            Write-Host "Server URL: $global:serverUrl (copied to clipboard)" -ForegroundColor Green
            Set-Clipboard -Value $global:serverUrl
            [Console]::Out.Flush()
            Show-Progress -Message "Server Online" -Duration 5
        } else {
            Write-Host "Failed to start server! Check PHP installation, port 80 availability, or admin rights." -ForegroundColor Red
        }
    }
    Write-Host "Press any key to return..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Progress {
    param ([string]$Message, [int]$Duration)
    Write-Host "${Message}: " -NoNewline -ForegroundColor Cyan
    for ($i = 0; $i -lt $Duration; $i++) {
        Write-Host "#" -NoNewline -ForegroundColor Green
        [Console]::Out.Flush()
        Start-Sleep -Seconds 1
    }
    Write-Host ""
}

# Default settings
$serverDir = "C:\Server"
$uploadScript = "$serverDir\upload.php"
$global:serverRunning = $false
$global:serverUrl = ""
$global:listenerIP = "192.168.1.115"
$global:listenerPort = "4444"
$global:serverIP = "127.0.0.1"

# Load persistent IP/Port
Get-Config

# Main loop
$running = $true
do {
    Show-Header
    Show-MainMenu
    $choice = Read-Host
    switch ($choice) {
        "1" { 
            $settingsRunning = $true
            while ($settingsRunning) {
                Show-SettingsMenu
                $settingsChoice = Read-Host
                switch ($settingsChoice) {
                    "1" { Set-ListenerIPPort }
                    "2" { Set-ServerIP }
                    "3" { $settingsRunning = $false }
                    default { 
                        Write-Host "Invalid choice!" -ForegroundColor Red
                        Start-Sleep -Seconds 2 
                    }
                }
            }
        }
        "2" { Start-Listener }
        "3" { Start-Server }
        "4" { Stop-Services }
        "5" { Get-Logs }
        "6" { Watch-Logs }
        "7" { 
            Write-Gradient "Shutting Down..." -Colors Red,Magenta
            $running = $false
        }
        default { 
            Write-Host "Invalid choice!" -ForegroundColor Red
            Start-Sleep -Seconds 2 
        }
    }
} while ($running)