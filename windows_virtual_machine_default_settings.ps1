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
      $RegFilePath = 'C:\Users\Default\NTUSER.DAT'
      $RegLoadPath = 'HKLM\Default'

      & REG LOAD $RegLoadPath $RegFilePath > $null 2>&1

      $LocaleValue = Get-ItemProperty -Path 'REGISTRY::HKEY_LOCAL_MACHINE\Default\Control Panel\International' -Name 'LocaleName'

      $unloaded = $false
      $attempts = 0
      while (!$unloaded -and ($attempts -le 5)) {
          [gc]::Collect() # necessary call to be able to unload registry hive
          & REG UNLOAD HKU\Replace > $null 2>&1
          $unloaded = $?
          $attempts += 1
      }
      @{ Result = $LocaleValue.LocaleName }
    }
    SetScript = {
      # Parameter
      $RegFileURL = "https://raw.githubusercontent.com/FiveH3ad/International_Reg/main/International.reg"
      $RegFile = "C:\Default_International.reg"

      # Download Registry File
      $webclient = New-Object System.Net.WebClient
      $webclient.DownloadFile($RegFileURL,$RegFile)

      $userprofiles = Get-Childitem C:\Users -Force -Exclude 'Default User','All Users','Public' -Directory | Select-Object name, fullname
      foreach($profile in $userprofiles){
          $username = $profile.name
          $profilepath = $profile.fullname
          if($username -ne 'Default'){
              $usersid = Get-LocalUser $username | Select-Object sid 
              $usersid = $usersid.SID.Value
          }
          else{
              $usersid = "None"
          }
          
          $UserRegPath = "Registry::HKEY_USERS\$($usersid)"
          
          $NTuserDatPath = Join-Path $profilepath "NTUSER.DAT"

          Write-Host $UserRegPath
          Write-Host $NTuserDatPath

          # Check if Hive is loaded or not
          if(Test-Path $UserRegPath){
              $PersonalRegFile = (Split-Path $RegFile -Parent) + "$username" + '.reg'
              $RegFileContent = Get-Content $RegFile
              $PersonalRegFileContent = $RegFileContent -Replace 'HKEY_USERS\\Replace',"HKEY_USERS\$usersid"
              Set-Content -Path $PersonalRegFile -Value $PersonalRegFileContent

              Remove-Item "$($UserRegPath)\Control Panel\International\User Profile" -Force -Recurse -confirm:$false -erroraction silentlycontinue
              Remove-Item "$($UserRegPath)\Keyboard Layout\Preload" -Force -Recurse -confirm:$false -erroraction silentlycontinue

              & REG import $PersonalRegFile > $null 2>&1
          }
          else{
              & REG LOAD HKU\Replace $NTuserDatPath > $null 2>&1

              Remove-Item 'Registry::HKEY_USERS\Replace\Control Panel\International\User Profile' -Force -Recurse -confirm:$false -erroraction silentlycontinue
              Remove-Item 'Registry::HKEY_USERS\Replace\Keyboard Layout\Preload' -Force -Recurse -confirm:$false -erroraction silentlycontinue

              & REG Import $RegFile > $null 2>&1

              $unloaded = $false
              $attempts = 0
              while (!$unloaded -and ($attempts -le 5)) {
                  [gc]::Collect() # necessary call to be able to unload registry hive
                  & REG UNLOAD HKU\Replace > $null 2>&1
                  $unloaded = $?
                  $attempts += 1
              }
          }
      }
    }
    TestScript = {
      $RegFilePath = 'C:\Users\Default\NTUSER.DAT'
      $RegLoadPath = 'HKLM\Default'

       & REG LOAD $RegLoadPath $RegFilePath > $null 2>&1

      $LocaleValue = Get-ItemProperty -Path 'REGISTRY::HKEY_LOCAL_MACHINE\Default\Control Panel\International' -Name 'LocaleName'

      $unloaded = $false
      $attempts = 0
      while (!$unloaded -and ($attempts -le 5)) {
        [gc]::Collect() # necessary call to be able to unload registry hive
        & REG UNLOAD HKLM\Default > $null 2>&1
        $unloaded = $?
        $attempts += 1
        Start-Sleep -Seconds 5
      }
      if ($LocaleValue.LocaleName.LocaleName -eq 'de-CH') {
        return $true
      }
      return $false
    }
  }
}

# This will generate the MOF files for the configuration.
WindowsServerDefaultSettings
