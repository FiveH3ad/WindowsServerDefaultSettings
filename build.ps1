# creates a whole build for the machine configuration

$configurationName = "WindowsServerDefaultSettings"

Set-Location -Path $PSScriptRoot

# Create a build for the machine configuration
. .\windows_virtual_machine_default_settings.ps1

Rename-Item -Path "$configurationName\localhost.mof" -NewName "$configurationName.mof"

$params = @{
  Name          = 'WindowsServerDefaultSettings'
  Configuration = './WindowsServerDefaultSettings/WindowsServerDefaultSettings.mof'
  Type          = 'AuditAndSet'
  Force         = $true
}

New-GuestConfigurationPackage @params

$PolicyConfig      = @{
  PolicyId      = '6be70959-6cd7-4adb-a592-2678ca9170f5'
  ContentUri    = 'https://github.com/FiveH3ad/WindowsServerDefaultSettings/raw/master/WindowsServerDefaultSettings.zip'
  DisplayName   = 'Default Windows Server Settings Policy'
  Description   = 'This Policy sets TimeZone, Language, Keyboard, and Location settings for Windows Server and installs the SNMP Service.'
  Path          = './policies/WindowsServerDefaultSettings.json'
  Platform      = 'Windows'
  PolicyVersion = '0.0.1'
  Mode         = 'ApplyAndAutoCorrect'
}

$policyPath = (New-GuestConfigurationPolicy @PolicyConfig).Path

$policyContentRaw = Get-Content $policyPath -Raw

$policyContentJson = $policyContentRaw -replace '"MicrosoftWindowsDesktop",','' | ConvertFrom-Json

Set-Content $policyPath -Value ($policyContentJson | ConvertTo-Json -Depth 100)

$policy = New-AzPolicyDefinition -Policy .\policies\WindowsServerDefaultSettings.json\WindowsServerDefaultSettings_DeployIfNotExists.json -Name 'WindowsServerDefaultSettings'
$subscription_id = (Get-AzContext).Subscription.Id

New-AzPolicyAssignment -Name 'WindowsServerDefaultSettings' -DisplayName 'Windows Server Default Settings' -Scope "/subscriptions/$subscription_id" -PolicyDefinition $policy -IdentityType SystemAssigned -Location 'West Europe'