<#
.SYNOPSIS
    Get currently logged on users, remotely or locally.
.DESCRIPTION
    Get-LoggedOnUsers uses the HKEY_USERS registry key to determine currently logged on users.  Powershell Remoting is used for remote hosts.
.PARAMETER ComputerName
    Specify a remote machine to get logged on users from.
.PARAMETER Find
    Check if a specific user is logged in.
#>
function Get-LoggedOnUsers
{
  Param(
    $ComputerName="localhost",
    $Find=""
  )

  # Create script block which gets logged in users
  $Block = {
    $hosts = @()
    foreach($SID in (Get-ChildItem -Path Microsoft.PowerShell.Core\Registry::HKU).Name)
    {
      if($SID.StartsWith("HKEY_USERS\S"))
      {
        try
        {
          $hosts += $($(New-Object System.Security.Principal.SecurityIdentifier($("S" + $SID.TrimStart("HKEY_USERS\")))).Translate([System.Security.Principal.NTAccount])).Value
        }
        catch
        {
        }
      }
    }
    return $hosts
  }

  # If a computername is specified, run the script block there. If not, run on localhost
  if($ComputerName -ne "localhost")
  {
    # Run it on all the computers provided, storing results
    $Results=@{}
    foreach($Computer in $ComputerName)
    {
      $Results[$Computer] = (Invoke-Command -ComputerName $ComputerName $Block)
    }

    # Just return the results unless we are supposed to find specific users
    if($Find -ne "")
    {
      # Check if the user is in the results for each host, if it is, add it to the hashtable and return the hashtable
      $HostsLoggedInto = @{}
      foreach($User in $Find)
      {
        foreach($Result in $Results.keys)
        {
          if(($Results.$Result).Contains($User))
          {
            $HostsLoggedInto[$User] = $Result
          }
        }
      }
      return $HostsLoggedInto
    }
    return $Results
  }
  else
  {
    Invoke-Command $Block
  }
}