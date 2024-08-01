# Define global variables
$location = "$env:APPDATA\Flarial"
$url = "https://backup.flarial.net/launcher/latest.zip"
$silent = $false

# Function to create shortcuts
function Create-Shortcut {
    param(
        [string]$Name,
        [string]$Directory,
        [string]$TargetFile,
        [string]$IconLocation,
        [string]$Description
    )

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$Directory\$Name.lnk")
    $Shortcut.TargetPath = $TargetFile
    $Shortcut.IconLocation = $IconLocation
    $Shortcut.Description = $Description
    $Shortcut.Save()
}

# Function for installation
function Install {
    Start-Sleep -Seconds 2
    if (Test-Path $location) {
        Remove-Item -Path $location -Recurse -Force
    }

    try {
        if (-not (Test-Path $location)) {
            New-Item -ItemType Directory -Path $location | Out-Null
        }

        $webClient = New-Object System.Net.WebClient

        $webClient.DownloadFile($url, "$location\latest.zip")

        # Perform actions after download completion
        Expand-Archive -Path "$location\latest.zip" -DestinationPath $location -Force
        Remove-Item "$location\latest.zip"

        Create-Shortcut -Name "Flarial" -Directory ([Environment]::GetFolderPath("Desktop")) -TargetFile "$location\Flarial.Launcher.exe" -IconLocation "$location\Flarial.Launcher.exe" -Description "Launch Flarial"
        Create-Shortcut -Name "Flarial" -Directory ([Environment]::GetFolderPath("StartMenu")) -TargetFile "$location\Flarial.Launcher.exe" -IconLocation "$location\Flarial.Launcher.exe" -Description "Launch Flarial"

        Create-Shortcut -Name "Flarial Minimal" -Directory ([Environment]::GetFolderPath("Desktop")) -TargetFile "$location\Flarial.Minimal.exe" -IconLocation "$location\Flarial.Minimal.exe" -Description "Launch Flarial Minimal"
        Create-Shortcut -Name "Flarial Minimal" -Directory ([Environment]::GetFolderPath("StartMenu")) -TargetFile "$location\Flarial.Minimal.exe" -IconLocation "$location\Flarial.Minimal.exe" -Description "Launch Flarial Minimal"

        if (-not $silent) {
            Write-Host "Flarial has been installed. You can find it on your desktop and in the Windows menu."
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        # Display error message
    }
}

# Main script
if ($args.Length -gt 0) {
    # Custom installation path logic (if needed)
}

if (Test-Path $location) {
    Get-ChildItem $location | Remove-Item -Force
}

Install
