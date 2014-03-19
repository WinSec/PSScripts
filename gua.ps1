param(
  [switch]$System=$False,
  [string]$File="\\127.0.0.1\ADMIN$\guaresults.txt"
)

$null = New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS
$ErrorActionPreference = "SilentlyContinue"

$Table = @{}
$Serials = @()

if(!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"))
{
  "No USB Devices found." > $File
  break
}
  
foreach($Name in (gci HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR -Name))
{
  foreach($Serial in (gci "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name" -Name))
  {
    $Table.Add($Serial, @{"regName" = $Name})
  }
}

foreach($Key in $Table.Keys)
{
  if((Test-Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\" + $Table.$Key.regName + "\"  + $Key)))
  {
    $FriendlyName = ((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\" + $Table.$Key.regName + "\" + $Key)).FriendlyName)
    $Driver = ((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\" + $Table.$Key.regName + "\" + $Key)).Driver)
    $GUID = ((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\" + $Table.$Key.regName + "\" + $Key)).ClassGUID)
    $DiskID = ((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\" + $Table.$Key.regName + "\" + $Key + "\Device Parameters\Partmgr")).DiskId)
    $Table.$Key.Add("Name",$FriendlyName)
    $Table.$Key.Add("Driver",$Driver)
    $Table.$Key.Add("GUID",$GUID)
    $Table.$Key.Add("DiskID",$DiskID)
  }

  foreach($SID in (gci HKU:\ -Name))
  {
    if(Test-Path "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\")
    {
      foreach($Subkey in (gci "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\" -Name))
      {
        if($Subkey -eq $Table.$Key.DiskID)
        {
          $Table.$Key.Add("UserThatInstalled", $(((New-Object System.Security.Principal.SecurityIdentifier($SID)).Translate( [System.Security.Principal.NTAccount])).Value))
        }
      }
      foreach($Subkey in (gci "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\CPC\Volume" -Name))
      {
        $ConvertedData = ([System.Text.Encoding]::Default.GetString(((((Get-ItemProperty "HKU:\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\CPC\Volume\$Subkey").Data) | ? {$_ -ne 0}))))
        if($ConvertedData.Contains($Key))
        {
          $Table.$Key.Add("UserThatInstalled", $(((New-Object System.Security.Principal.SecurityIdentifier($SID)).Translate( [System.Security.Principal.NTAccount])).Value))
        }

        $Table.$Key.Add("VendorID",($ConvertedData.Split("#")[6].Split("\")[5].Split("&")[0].TrimStart("VID_")))
        $Table.$Key.Add("ProductID",($ConvertedData.Split("#")[6].Split("\")[5].Split("&")[1].TrimStart("PID_")))

      }
    }
  }
    
  foreach($Subkey in (gci "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\EMDMgmt" -Name))
  {
    if($Subkey.Contains($Key))
    {

      $Table.$Key.Add("Vendor",($Subkey.Split("#")[1]).Split("&")[1].TrimStart("Ven_"))
      $Table.$Key.Add("Product",($Subkey.Split("#")[1]).Split("&")[2].TrimStart("Prod_"))
      $Table.$Key.Add("Revision",($Subkey.Split("#")[1]).Split("&")[3].TrimStart("Rev_"))

    }
  }

  foreach($Subkey in (gci "HKLM:\SYSTEM\CurrentControlSet\Enum\WpdBusEnumRoot\UMB" -Name))
  {
    if($Subkey.Contains($Key.ToUpper()))
    {
      $Table.$Key.Add("VolumeName",((Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\WpdBusEnumRoot\UMB\" + $Subkey)).FriendlyName))
    }
  }
  
  $DEV_LOG = Get-Content C:\Windows\Inf\setupapi.dev.log
  foreach($line in $DEV_LOG)
  {
    if($line.Contains("Device Install (Hardware initiated)") -and $line.Contains("USBSTOR"))
    {
      if($line.Split("#")[4] -eq $Key)
      {
        $Table.$Key.Add("OriginalInstallDate", $DEV_LOG[$DEV_LOG.IndexOf($line)+1].Substring(19))
      }
    }
  }

  if($System -and (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\"))
  {
    foreach($Subkey in (gci "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\" -Name))
    {
      if(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\$Subkey\0067")
      {
        $LEInstallDate = (REG QUERY "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\$Subkey\0064").Split()[14]
        $LEInstallDate_array = $($LEInstallDate -split "(\w{2})" | ? {$_})
        [array]::Reverse($LEInstallDate_array)
        $ConvertedInstallDate = -join $LEInstallDate_array
        $DPKInstallDate = [DateTime]::FromFileTime([Convert]::ToInt64($ConvertedInstallDate, 16))
         
        $LELastArrival = (REG QUERY "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\$Subkey\0066").Split()[14]
        $LELastArrival_array = $($LELastArrival -split "(\w{2})" | ? {$_})
        [array]::Reverse($LELastArrival_array)
        $ConvertedLastArrival = -join $LELastArrival_array
        $DPKLastArrival = [DateTime]::FromFileTime([Convert]::ToInt64($ConvertedLastArrival, 16))
          
        $LELastRemoval = (REG QUERY "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBSTOR\$Name\$Serial\Properties\$Subkey\0067").Split()[14]
        $LELastRemoval_array = $($LELastRemoval -split "(\w{2})" | ? {$_})
        [array]::Reverse($LELastRemoval_array)
        $ConvertedLastRemoval = -join $LELastRemoval_array
        $DPKLastRemoval = [DateTime]::FromFileTime([Convert]::ToInt64($ConvertedLastRemoval, 16))

        $Table.$Key.Add("DPKInstallDate",$DPKInstallDate)
        $Table.$Key.Add("DPKLastArrival",$DPKLastArrival)
        $Table.$Key.Add("DPKLastRemoval",$DPKLastRemoval)
      }
    }
  }

  foreach($Subkey in (gci "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\" -Name))
  {
    if((gci "HKLM:\SYSTEM\CurrentControlSet\Enum\USB\$Subkey" -Name).Contains($Key.TrimEnd("&0")))
    {
      $Table.$Key.Add("VendorID",$Subkey.Split("&")[0].TrimStart("VID_"))
      $Table.$Key.Add("ProductID",$Subkey.Split("&")[1].TrimStart("PID_"))
      $Table.$Key.Add("LocationInfo",(Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\USB\" + $Subkey + "\" + ($Key.TrimEnd("&0")))).LocationInformation)
    }
  }
}
foreach($Key in $Table.Keys)
{
  foreach($Subkey in $Table.$Key.Keys)
  {
    ($Key + "---" + $Subkey + "---" + $Table.$Key.$Subkey) >> $File
  }
}
"ENDFILEHERE" >> $File
