#Package Installer
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
#Trust Repo
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#Dell Bios Powershell Interface
Install-Module -Name DellBIOSProvider
#Install Visual C++ Redist Depdendacy
if (-not (Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty | Where-Object { $_.DisplayName -match 'Microsoft Visual C\+\+.*Redistributable \(x64\)' })) { Invoke-WebRequest 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile "$env:TEMP\vc_redist.x64.exe"; Start-Process -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList '/install', '/quiet', '/norestart' -Wait }#Trust Powershell Script
Set-ExecutionPolicy Unrestricted
#Load Dell Bios Powershell Module
Import-Module "DellBIOSProvider"
# Set Dell Bios setting to AC Recover to On.
Set-Item -Path DellSmbios:\PowerManagement\AcPwrRcvry -Value On
Set-Item -Path DellSmbios:\PowerManagement\BlockSleep -Value Enabled
Set-Item -Path DellSmbios:\PowerManagement\DeepSleepCtrl -Value Disabled