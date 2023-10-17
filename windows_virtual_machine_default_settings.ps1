Configuration WindowsServerDefaultSettings {
  Import-DscResource -ModuleName "PSDscResources" -Name WindowsFeature -ModuleVersion '2.12.0.0'
  Import-DscResource -ModuleName "PSDscResources" -Name Script -ModuleVersion '2.12.0.0'
  Import-DscResource -ModuleName "ComputerManagementDsc" -Name TimeZone -ModuleVersion '9.0.0'
  Import-DscResource -ModuleName "ComputerManagementDsc" -Name SystemLocale -ModuleVersion '9.0.0'
  Import-DscResource -ModuleName "ComputerManagementDsc" -Name PendingReboot -ModuleVersion '9.0.0'
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
  PendingReboot 'CheckPendingReboot' {
    Name = 'CheckPendingReboot'
    DependsOn = '[WindowsFeature]SNMP'
  }
  Script 'UserRegistry' {
    GetScript = {
      @{
        Result = (Get-WinHomeLocation).GeoId
      }
    }
    SetScript = {
      $xmlFile = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToSystemAcct="true" CopySettingsToDefaultUserAcct="true"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="de-CH" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="0807:00000807" Default="true"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="de-CH"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="223"/>
    </gs:LocationPreferences>
    <gs:SystemLocale Name="de-CH"/>
</gs:GlobalizationServices>
"@
      $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
      Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFile

      # Copy the current user language settings to the default user account and system user account.
      $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
      $procStartInfo.UseShellExecute = $false
      $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
      $proc = [System.Diagnostics.Process]::Start($procStartInfo)
      $proc.WaitForExit()
      $proc.Dispose()

      # Delete the XML file.
      Remove-Item -LiteralPath $xmlFileFilePath -Force
    }
    TestScript = {
      if ('223' -eq (Get-WinHomeLocation).GeoId) {
        return $true
      }
      else {
        return $false
      }
  }
}
}

# This will generate the MOF files for the configuration.
WindowsServerDefaultSettings
