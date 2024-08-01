$executablePath = Join-Path $env:APPDATA "Flarial\Flarial.Minimal.exe"
if (Test-Path $executablePath -PathType Leaf) {
    $shortcutPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Desktop', 'Flarial.Minimal.lnk')

    $shell = New-Object -ComObject WScript.Shell

    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $executablePath
    $shortcut.Save()

    Write-Host "Shortcut created on the desktop."
} else {
    Write-Host "Error: The specified executable does not exist."
}
