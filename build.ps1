# creates a whole build for the machine configuration

$configurationName = "WindowsServerDefaultSettings"

Set-Location -Path $PSScriptRoot

# Create a build for the machine configuration
. .\windows_virtual_machine_default_settings.ps1

Rename-Item -Path "$configurationName\localhost.mof" -NewName "$configurationName.mof"