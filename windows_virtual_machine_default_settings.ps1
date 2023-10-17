Configuration WindowsServerDefaultSettings {
  Import-DscResource -ModuleName "PSDscResources" -Name WindowsFeature
  WindowsFeature 'SNMP' {
    Ensure = 'Present'
    Name   = 'SNMP-Service'
    IncludeAllSubFeature = $true
  }
}

# This will generate the MOF files for the configuration.
WindowsServerDefaultSettings
