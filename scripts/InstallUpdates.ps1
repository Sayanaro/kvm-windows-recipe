# Install updates if exist

# Force enable TLS12 in PowerShell session (important for Windows Server 2016 and earlier)
Write-Host "Enable TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Updating NuGet
Write-Host "Updating NuGet"
Install-PackageProvider -Name NuGet -Force -Confirm:$false

# Installing PowerShell module PSWindowsUpdate
Write-Host "Installing PowerShell module PSWindowsUpdate"
Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

Write-Host "Importing module PSWindowsUpdate"
Import-Module PSWindowsUpdate

# Checking Windows Update as source
Write-Host "Checking Windows Update as source"
if(!(Get-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d")) {
    Write-Host "Source Windows Update not found. Adding 7971f918-a847-4430-9279-4a52d1efe18d..."
    Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d" -AddServiceFlag 7 -Confirm:$false
}

Write-Host "Getting update list"
$UpdateList = Get-WindowsUpdate -ErrorAction SilentlyContinue

if(!$UpdateList) {
    Write-Host "Update list is empty trying to fix it"
    $outNull = Reset-WUComponents
    $UpdateList = Get-WindowsUpdate -ErrorAction SilentlyContinue
}

# Downloading and installing updates
Write-Host $UpdateList
Write-Host "Installing updates"
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "c:\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -force

# Sysprep task on startup
Get-ScheduledTask "update-task" | Unregister-ScheduledTask -Confirm:$false

# Sysprep task on startup
& schtasks /Create /TN "sysprep" /RU System /SC ONSTART /RL HIGHEST /TR "Powershell -NoProfile -ExecutionPolicy Bypass -File \`"C:\Windows\Setup\Scripts\Sysprep.ps1`"" | Out-Null

Remove-Item "C:\Windows\Setup\Scripts\InstallUpdates.ps1" -Force -Confirm:$false

Restart-Computer -Force
