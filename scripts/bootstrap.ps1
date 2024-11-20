# setupcomplete
mkdir "C:\Windows\Setup\Scripts" | Out-Null
mkdir "C:\Program Files\Yandex.Cloud\Guest Agent Updater" | Out-Null
mkdir "C:\sysprep-temp" | Out-Null
cp "$PSScriptRoot\SetupComplete.cmd" "C:\Windows\Setup\Scripts\"
cp "$PSScriptRoot\SetupComplete.ps1" "C:\Windows\Setup\Scripts\"
cp "$PSScriptRoot\InstallUpdates.ps1" "C:\Windows\Setup\Scripts\"
cp "$PSScriptRoot\Sysprep.ps1" "C:\Windows\Setup\Scripts\"
cp "$PSScriptRoot\SetupComplete-final.ps1" "C:\Windows\Setup\Scripts\"
cp "$PSScriptRoot\sysprepunattend-cloudbase-init.xml" "C:\sysprep-temp\unattend.xml"
