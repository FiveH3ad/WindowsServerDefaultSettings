Configuration WindowsServerDefaultSettings {
  Import-DscResource -ModuleName "PSDscResources" -Name WindowsFeature -ModuleVersion '2.12.0.0'
  Import-DscResource -ModuleName "PSDscResources" -Name Script -ModuleVersion '2.12.0.0'
  Import-DscResource -ModuleName "ComputerManagementDsc" -Name TimeZone -ModuleVersion '9.0.0'
  Import-DscResource -ModuleName "ComputerManagementDsc" -Name SystemLocale -ModuleVersion '9.0.0'
  WindowsFeature 'SNMP' {
    Ensure = 'Present'
    Name   = 'SNMP-Service'
    IncludeAllSubFeature = $true
  }
  TimeZone 'SetTimeZone' {
    TimeZone = 'W. Europe Standard Time'
    IsSingleInstance = 'Yes'

  }
  SystemLocale 'SetSystemLocale' {
    SystemLocale = 'de-CH'
    IsSingleInstance = 'Yes'
  }
}

# This will generate the MOF files for the configuration.
WindowsServerDefaultSettings
