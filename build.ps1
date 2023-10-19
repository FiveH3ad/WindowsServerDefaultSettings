# creates a whole build for the machine configuration
param(
  [Parameter(Mandatory = $false)]
  [string]$configurationName = "WindowsServerDefaultSettings",
  [Parameter(Mandatory = $false)]
  [string]$version = "0.0.7",
  [Parameter(Mandatory = $false)]
  [string]$ScriptName = "windows_virtual_machine_default_settings.ps1",
  [Parameter(Mandatory = $false)]
  [string]$PolicyName = "Default Windows Server Settings Policy",
  [Parameter(Mandatory = $false)]
  [string]$PolicyDescription = "This Policy sets TimeZone, Language, Keyboard, and Location settings for Windows Server and installs the SNMP Service."
)

$ConfiguratioPath = "$configurationName\$configurationName.mof"

Set-Location -Path $PSScriptRoot

# Create a build for the machine configuration
powershell.exe -command "Set-Location $PSScriptRoot
. .\$scriptName"

if(Test-Path -Path $ConfiguratioPath){
  Remove-Item -Path $ConfiguratioPath -Force
}

Rename-Item -Path "$configurationName\localhost.mof" -NewName "$configurationName.mof"

$params = @{
  Name          = $configurationName
  Configuration = $ConfiguratioPath
  Type          = 'AuditAndSet'
  Force         = $true
}

New-GuestConfigurationPackage @params

$PolicyConfig      = @{
  PolicyId      = '6be70959-6cd7-4adb-a592-2678ca9170f5'
  ContentUri    = 'https://github.com/FiveH3ad/WindowsServerDefaultSettings/raw/master/WindowsServerDefaultSettings.zip'
  DisplayName   = $PolicyName
  Description   = $PolicyDescription
  Path          = './policies/'
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

$policy = New-AzPolicyDefinition -Policy $policyPath -Name $configurationName
$subscription_id = (Get-AzContext).Subscription.Id

if (Get-AzPolicyAssignment -Name $configurationName -ErrorAction SilentlyContinue){
  Remove-AzPolicyAssignment -Name $configurationName -Scope "/subscriptions/$subscription_id"
}

New-AzPolicyAssignment -Name $configurationName -DisplayName $PolicyName -Scope "/subscriptions/$subscription_id" -PolicyDefinition $policy -IdentityType SystemAssigned -Location 'West Europe'