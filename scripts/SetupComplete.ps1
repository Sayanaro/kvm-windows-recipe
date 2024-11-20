# Setting PS Execution Policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Confirm:$false

# Force enable TLS12 in PowerShell session (important for WIndows Server 2016 and earlier)
Write-Host "Enable TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# serial console
& bcdedit /ems "{current}" on
& bcdedit /emssettings EMSPORT:2 EMSBAUDRATE:115200

# powerplan
& powercfg -setactive "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
& powercfg -change -monitor-timeout-ac 0
& powercfg -change -standby-timeout-ac 0
& powercfg -change -hibernate-timeout-ac 0

# shutdown
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name "ShutdownWarningDialogTimeout" -Value 1

# clock
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Value 1 -Type DWord -Force

# icmp
Get-NetFirewallRule -Name "vm-monitoring-icmpv4" | Enable-NetFirewallRule

# Sysprep task on startup
& schtasks /Create /TN "update-task" /RU System /SC ONSTART /RL HIGHEST /TR "Powershell -NoProfile -ExecutionPolicy Bypass -File \`"C:\Windows\Setup\Scripts\InstallUpdates.ps1`"" | Out-Null

# Set never expiried Administrator password
Get-LocalUser | Where-Object -Property "SID" -like "S-1-5-21-*-500" | Set-LocalUser -PasswordNeverExpires 1

# Set Remote Desktop
Get-CimInstance -ClassName Win32_TSGeneralSetting -Namespace root\cimv2\terminalservices | Invoke-CimMethod -MethodName SetUserAuthenticationRequired -Arguments @{ UserAuthenticationRequired = 1 }
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Get-ScheduledTask -TaskName "ScheduledDefrag" | Disable-ScheduledTask | Out-Null

# Install Telnet Client, WS Backup & .NET 3.5
Write-Host "Adding windows features: Telnet Client, WS Backup & .NET 3.5"
$outNull = Add-WindowsFeature "Windows-Server-Backup", "Telnet-Client", "NET-Framework-Features" -Source "D:\sources\sxs\"

# Install password reset agent
$YCAgentUpdaterBaseUri = "https://storage.yandexcloud.net/yandexcloud-guestagent-updater"
$YCAgentUpdaterVersion = (Invoke-RestMethod "$YCAgentUpdaterBaseUri/release/stable").Trim()
$YCAgentUpdaterDir = "C:\Program Files\Yandex.Cloud\Guest Agent Updater"

$outNull = New-Item -Path $YCAgentUpdaterDir -ItemType "directory" -Force -ErrorAction SilentlyContinue

# Downloading agent
$Params = @{
    Uri = "$YCAgentUpdaterBaseUri/release/$YCAgentUpdaterVersion/windows/amd64/guest-agent-updater.exe"
    OutFile = "$YCAgentUpdaterDir\guest-agent-updater.exe"
}
Invoke-RestMethod @Params

# Verifying agent checksum
$YCAgentUpdaterHashOrig = (Invoke-RestMethod "$YCAgentUpdaterBaseUri/release/$YCAgentUpdaterVersion/windows/amd64/guest-agent-updater.exe.sha256").Trim()
$YCAgentUpdaterHashCopy = (Get-Filehash -Path "$YCAgentUpdaterDir\guest-agent-updater.exe" -Algorithm SHA256 | Select-Object -ExpandProperty Hash).ToLower()

if ($YCAgentUpdaterHashOrig -eq $YCAgentUpdaterHashCopy) {
    Write-Host "Agent updater checksum verified"
    # Installing agent
    & $YCAgentUpdaterDir\guest-agent-updater.exe update

    # Starting agent service
    Start-Service "yc-guest-agent"

    # Creating update scheduled task
    $YCAgentUpdaterLogFilepath = "C:\Windows\Temp\guest-agent-updater.log"
    $Params = @{
        Execute = 'C:\Windows\System32\cmd.exe'
        Argument = "/c `"$YCAgentUpdaterDir\guest-agent-updater.exe`" update --log-level debug > $YCAgentUpdaterLogFilepath"
    }
    $YCAgentUpdaterAction = New-ScheduledTaskAction @Params

    $RandomWeekdayNumber = Get-Random -Minimum 0 -Maximum 6
    $DaysOfWeek = @("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    $RandomWeekday = $DaysOfWeek[$RandomWeekdayNumber]

    $RandomHour = Get-Random -Minimum 0 -Maximum 23
    $RandomMinute = Get-Random -Minimum 0 -Maximum 59
    $RandomSecond = Get-Random -Minimum 0 -Maximum 59

    $Params = @{
        Weekly = $true
        At = ([datetime]::Today).AddHours($RandomHour).AddMinutes($RandomMinute).AddSeconds($RandomSecond)
        RandomDelay = New-TimeSpan -Hours 24 # with huge random delay
        DaysOfWeek = $RandomWeekday
    }
    $YCAgentUpdaterTrigger = New-ScheduledTaskTrigger @Params

    $YCAgentUpdaterTaskName = "yc-guest-agent-updater"
    $Params = @{
        TaskName = $YCAgentUpdaterTaskName
        Action = $YCAgentUpdaterAction
        User = 'System'
        RunLevel = 'Highest'
        Trigger = $YCAgentUpdaterTrigger
    }

    Register-ScheduledTask @Params | Out-Null
}
else {
    Write-Host "Agent updater checksum NOT verified. Skipping installation..."
}

# Update virtio drivers to current stable version
Write-Host "Update virtio drivers to current stable version"
Write-Host "Downloading latest virtio drivers"
Start-BITSTransfer -Source "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" -Destination "C:\sysprep-temp"
ls c:\sysprep-temp\virtio-win.iso
Write-Host "Mounting image c:\sysprep-temp\virtio-win.iso"
Mount-DiskImage -ImagePath c:\sysprep-temp\virtio-win.iso -StorageType ISO
$VirtioDriveLetter = (Get-Volume -FileSystemLabel "*virtio*").DriveLetter
$VirtioDriveRoot = "$VirtioDriveLetter"+":\"
Write-Host "Virtio drive letter is $VirtioDriveLetter"
Write-Host "Virtio root is $VirtioDriveRoot"
& $VirtioDriveRoot\virtio-win-guest-tools.exe /install /quiet /NoRestart
Start-Sleep 60
Write-Host "Dismouting image c:\sysprep-temp\virtio-win.iso"
Dismount-DiskImage -ImagePath c:\sysprep-temp\virtio-win.iso


# Install Cloudbase-Init
# Deleting first unattend if it exist
$outNull = Remove-Item c:\*.xml -Recurse -Force -ErrorAction SilentlyContinue

Start-BitsTransfer https://storage.yandexcloud.net/cloudbase/cloudbase-init.zip -Destination "C:\sysprep-temp"
Expand-Archive -Path C:\sysprep-temp\cloudbase-init.zip -DestinationPath C:\sysprep-temp\cloudbase-init
$PathToMSI = "C:\sysprep-temp\cloudbase-init\cloudbase-init\CloudbaseInit.msi"
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $PathToMSI /qn" -Wait
$CloudbaseinitConfigDir = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\"
$PathToConfig = "C:\sysprep-temp\cloudbase-init\cloudbase-init\cloudbase-init-unattend.conf"
Copy-Item "$PathToConfig" "$CloudbaseinitConfigDir\cloudbase-init.conf"
Copy-Item "$PathToConfig" "$CloudbaseinitConfigDir\cloudbase-init-unattend.conf"


# Create allow firewall rules for WinRM
$WINRMHTTPS = Get-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -ErrorAction SilentlyContinue

if ($WINRMHTTPS) {
    $WINRMHTTPS | Enable-NetFirewallRule  
}
else {
    $NetFirewallRuleParams = @{
        Group = "Windows Remote Management"
        DisplayName = "Windows Remote Management (HTTPS-In)"
        Name = "WINRM-HTTPS-In-TCP"
        LocalPort = 5986
        Action = "Allow"
        Protocol = "TCP"
        Program = "System"
    }

    New-NetFirewallRule @NetFirewallRuleParams
}

$WINRMHTTPS = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue

if ($WINRMHTTPS) {
    $WINRMHTTPS | Enable-NetFirewallRule  
}
else {
    $NetFirewallRuleParams = @{
        Group = "Windows Remote Management"
        DisplayName = "Windows Remote Management (HTTP-In)"
        Name = "WINRM-HTTP-In-TCP"
        LocalPort = 5985
        Action = "Allow"
        Protocol = "TCP"
        Program = "System"
    }

    New-NetFirewallRule @NetFirewallRuleParams
}

Remove-Item "C:\Windows\Setup\Scripts\SetupComplete.ps1" -Force -Confirm:$false

Restart-Computer -Force
