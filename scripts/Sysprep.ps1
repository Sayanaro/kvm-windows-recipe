# Global vars
$WorkDirectory = "C:\sysprep-temp"

# Await if update process TiWorker running and finalizing updates after system reboot
$UpdateFinishing = Get-WmiObject Win32_Process | where {$_.Name -eq "TiWorker.exe"}
while($UpdateFinishing) {
    Start-Sleep 5
    $UpdateFinishing = Get-WmiObject Win32_Process | where {$_.Name -eq "TiWorker.exe"}
}

# Cleaning up downloaded patches
Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force

# Start sysprep
& $env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /unattend:"$WorkDirectory\unattend.xml" /shutdown

Move-Item "C:\Windows\Setup\Scripts\SetupComplete-final.ps1" "C:\Windows\Setup\Scripts\SetupComplete.ps1" -Force -Confirm:$false

#Wait for correct system state
do {
    Start-Sleep -s 5

    $SetupState = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
    $ImageState = $SetupState | Select-Object -ExpandProperty ImageState    
    $ImageState | Out-Default
} while ($ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE')

Remove-Item $WorkDirectory -Recurse -Force
Get-ScheduledTask sysprep | Unregister-ScheduledTask -Confirm:$false
Remove-Item "C:\Windows\Setup\Scripts\Sysprep.ps1" -Force
Start-Sleep -s 10

# Wait for sysprep tag
while (-not (Test-Path 'C:\Windows\System32\Sysprep\Sysprep_succeeded.tag') ) {
    'Sysprep succeeded tag not yet exist...' 

    Start-Sleep -s 1
}

Start-Sleep -s 10

Stop-Computer -Force

& shutdown -s -f -t 0
