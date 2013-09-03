<#
.SYNOPSIS
    Get currently logged on users, remotely or locally.
.DESCRIPTION
    Get-LoggedOnUsers uses the HKEY_USERS registry key to determine currently logged on users.  It goes through each SID in HKEY_USERS and prints it's corresponding username to the screen.
    
	PARAMETERS:
	-----------
	[-ComputerName]     -     Specify a remote machine to get logged on users from.
	[-File]             -     Specify a file which contains a list of remote machines.
	[-Recurse]          -     Continuosly attempt to connect to the remote machine.
	[-Force]            -     Attempts to execute code on the remote host without testing testing the connection first.
	[-Label]            -     Labels output by computer name.
#>

Param(
  $ComputerName="localhost",
  [string]$File="",
  [switch]$Recurse=$False,
  [switch]$Force=$False,
  [switch]$Label=$False
)

if($Force -and $Recurse)
{
  "Force and Recurse cannot be used together."
  break
}
if($File -ne "")
{
  if(Test-Path $File)
  {
    [array]$ComputerName = Get-Content $File
    if($ComputerName.Count -eq 0)
    {
      "File is empty."
      break
    }
  }
  else
  {
    "File not found."
    break
  }
}

$ErrorActionPreference = "SilentlyContinue"

function Get-LoggedOnUsers
{
  foreach($SID in $(Get-ChildItem -Path Microsoft.PowerShell.Core\Registry::HKU).Name)
  {
    if($SID.StartsWith("HKEY_USERS\S"))
    {
      try
      {
        Write-Host $($(New-Object System.Security.Principal.SecurityIdentifier($("S" + $SID.TrimStart("HKEY_USERS\")))).Translate([System.Security.Principal.NTAccount])).Value
      }
      catch
      {
      }
    }
  }
}

function Det
{
  if($Label -and ($ComputerName.Count -gt 1))
  {
    foreach($Comp in $ComputerName)
    {
      "`n" + $Comp + ":`n----------"
      Invoke-Command -ComputerName $Comp -ScriptBlock ${function:Get-LoggedOnUsers}
      "`n"
    }
  }
  elseif($Label -and !($ComputerName.Count -gt 1))
  {
    "`n" + $ComputerName + ":`n----------"
    Invoke-Command -ComputerName $ComputerName -ScriptBlock ${function:Get-LoggedOnUsers}
    "`n"
  }
  else
  {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock ${function:Get-LoggedOnUsers}
  }
}


if(@("localhost","127.0.0.1",$(hostname).ToLower()).Contains($ComputerName.ToLower()))
{
  if($Label)
  {
    "`n" + $ComputerName + ":`n----------"
    Get-LoggedOnUsers
    "`n"
  }
  else
  {
    Get-LoggedOnUsers
  }
}
else
{
  if(Test-Connection $ComputerName -Count 1)
  {
    Det
  }
  else
  {
    if($Recurse -and !($Force))
    {
      while(!(Test-Connection $ComputerName -Count 1))
      {
      }
      Det
    }
    elseif($Force -and !($Recurse))
    {
      try
      {
        Det
      }
      catch
      {
      }
    }
    else
    {
      "Failed to connect to the remote host."
    }
  }
}
