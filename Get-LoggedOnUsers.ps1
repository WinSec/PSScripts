<#
.SYNOPSIS
    Get currently logged on users, remotely or locally.

.DESCRIPTION
    Get-LoggedOnUsers uses the HKEY_USERS registry key to determine currently logged on users.  It goes through each SID in HKEY_USERS and prints it's corresponding username to the screen.

	PARAMETERS:
	-----------
	[-ComputerName]     -     Specify a remote machine to get logged on users from.
#>
function Get-LoggedOnUsers
{
  Param(
    $ComputerName="localhost"
  )

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

  if($ComputerName -ne "localhost")
  {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $Block
  }
  else
  {
    Invoke-Command -ScriptBlock $Block
  }
}