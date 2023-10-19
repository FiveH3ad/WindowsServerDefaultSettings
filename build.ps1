# creates a whole build for the machine configuration

$configurationName = "WindowsServerDefaultSettings"
$version = "0.0.6"
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
  PolicyVersion = $version
  Mode         = 'ApplyAndAutoCorrect'
}

$policyPath = (New-GuestConfigurationPolicy @PolicyConfig).Path

$packageHash = Get-FileHash ".\$configurationName.zip" -Algorithm SHA256 | Select-Object -ExpandProperty Hash

$policyContentRaw = Get-Content $policyPath -Raw

$policyContentJson = $policyContentRaw -replace '"MicrosoftWindowsDesktop",','' | ConvertFrom-Json

$policyContentJson.properties.metadata.guestConfiguration.contentHash = $packageHash

$i = 0

foreach($item in $policyContentJson.properties.policyRule.then.details.deployment.properties.template.resources){
  $policyContentJson.properties.policyRule.then.details.deployment.properties.template.resources[$i].properties.guestConfiguration.contentHash = $packageHash
  $i++
}

Set-Content $policyPath -Value ($policyContentJson | ConvertTo-Json -Depth 100)

git add *

git commit -m "version $version"

git push https://github.com/FiveH3ad/WindowsServerDefaultSettings.git master --force

$policy = New-AzPolicyDefinition -Policy .\policies\WindowsServerDefaultSettings.json\WindowsServerDefaultSettings_DeployIfNotExists.json -Name 'WindowsServerDefaultSettings'
$subscription_id = (Get-AzContext).Subscription.Id

New-AzPolicyAssignment -Name 'WindowsServerDefaultSettings' -DisplayName 'Windows Server Default Settings' -Scope "/subscriptions/$subscription_id" -PolicyDefinition $policy -IdentityType SystemAssigned -Location 'West Europe'