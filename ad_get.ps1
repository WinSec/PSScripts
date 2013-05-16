#// Load help
$help="`n`n/////// ad_get \\\\\\\`n`nCOMMANDS:`n----------`nshow  		--	List all OU's with computers in them.`nselect <number>		--	Select a specific OU or computer to operate in.`nunselect		--	Unselect the selected OU.`nstatus			--	Show the up/down status of computers in the selected OU.`nevents			--	Show logon/logoff events from the selected computer.`nexit/quit		--	Quit ad_get.`n`n"

#// List all of the Organizational Units with computers in them, adding them to a list for future reference.
$ou_ls=@{}; $ou_num=0; $ou_out; Get-ADOrganizationalUnit -Filter {Name -like '*'} | foreach-object{$comps=Get-ADComputer -Filter * -Searchbase $_.DistinguishedName; if($comps.count -gt 0){$ou_num++;$ou_ls.Add($ou_num,$comps);$ou_out += $("OU Number $ou_num`n--------------`nRN: " + $_.Name + "`nDN: '" + $_.DistinguishedName + "'`n`n")}}

#// Load vars for while loop.
$prefix="ad_get>> "; $colorchange="white"; $ou_selected=0; $comp_selected=0; $no_ou="`nYou do not have an OU selected.  You can select one by tying 'select' followed by the OU number.`n"; $no_comp="`nYou do not have a computer selected.  You can select one by tying 'select' followed by the computer number.`n"; $fail="That is not a valid selection."

#// Print Help
$help

#// Main Loop
while($True)
{
  #// take input
  Write-Host $prefix -Foregroundcolor $colorchange -NoNewline; $input=Read-Host

  #// help command
  if($input -eq "help"){$help}

  #// exit/quit command
  elseif(($input -eq "quit") -or ($input -eq "exit")){break}
  
  #// show command
  elseif($input -eq "show")
  {
    #// if an ou is selected, along with an ou, show the selected comp
    if(($ou_selected -gt 0) -and ($comp_selected -gt 0))
	{
	  Write-Host "`n`nComputer Number"$comp_selected"`n----------`nHN:  "$($comp_ls.$comp_selected.DNSHostName)"`nDN:  '"$($comp_ls.$comp_selected.DistinguishedName)"'`n`n"
	}
	
    #// if an ou is selected, show the computers
    elseif($ou_selected -gt 0)
    {
      foreach($comp in $comp_ls.Keys)
      {
        Write-Host "`n`nComputer Number"$comp"`n----------`nHN:  "$($comp_ls.$comp.DNSHostName)"`nDN:  '"$($comp_ls.$comp.DistinguishedName)"'"
      }
      Write-Host "`n`n"
    }
    #// if an ou is not selected, show the ous
    elseif($ou_selected -eq 0)
    {
    $ou_out
    }
  }

  #// select command
  elseif($input.StartsWith("select"))
  {
    $testvar=$null
	#// if the selection is numerical, and and in the ou_ls, proceed
    if([Int32]::TryParse($input.Substring(7), [ref]$testvar) -and ([int32]$input.Substring(7) -ne 0))
    {
      #// if an ou is selected and a computer is selected, tell the user
	  if(($ou_selected -gt 0) -and ($comp_selected -gt 0))
	  {
	    Write-Host "You have already made a selection."
	  }
	  #// if an ou is selected, select a computer
      elseif($ou_selected -gt 0)
      {
	    #// if the selection is a valid comp number
	    if([int32]$input.Substring(7) -le $comp_ls.count)
		{
	      #// Computer Selection Process
          [int]$comp_selected=$input.Substring(7)
          $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">comp_" + $($comp_selected.ToString()) + ">> ")
          $colorchange="cyan"
		}
		else
	    {
	      Write-Host $fail
	    }
      }
      #// if an ou is not selected, select an ou 
      elseif($ou_selected -eq 0)
      {
	    #// if the selection is a valid ou number
	    if([int32]$input.Substring(7) -le $ou_ls.count)
		{
          #// OU Selection Process
          [int]$ou_selected=$input.Substring(7)
          $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">> ")
          $colorchange="red"
	    }
		else
	    {
	      Write-Host $fail
	    }
        #// Grab the info for that OU's computers
   	    $comp_ls=@{}
        $comp_num=0
    	foreach($comp in $ou_ls.$ou_selected)
        {
          $comp_num++
          $comp_ls.Add($comp_num, $comp)
    	}
      }
	}
	else
	{
	  Write-Host $fail
	}
  }

  #// unselect command
  elseif($input -eq "unselect")
  {
    #// if an ou isn't selected, tell the user
    if($ou_selected -eq 0)
    {
      $no_ou
    }
	#// if an ou is selected: deselect everything
    else
    {
      [int]$ou_selected=0
      $comp_selected=''
      $prefix="ad_get>> "
      $colorchange="white"
    }
  }

  #// status command
  elseif($input -eq "status")
  {
    #// if no ou is selected, tell the user
    if($ou_selected -eq 0)
    {
      $no_ou
    }
    #// if an ou is selected, 
    elseif($ou_selected -gt 0)
    {
      #// and a computer is not selcted: get the status of the whole OU
      if($comp_selected -eq 0)
      {
        $res_ls=@(0,0)
        foreach($comp in $ou_ls.$ou_selected)
        {
          $res=Test-Connection $comp.DNSHostName -Count 1 -Quiet
          if($res -eq $True)
          {
            $res_ls[0]++
            Write-Host "$($comp.DNSHostName) is up." -foregroundcolor green
          }
          elseif($res -eq $False)
          {
            $res_ls[1]++
            Write-Host "$($comp.DNSHostName) is down." -foregroundcolor red
          }
        }
        Write-Host "`n`nSummary:`n----------`n$([string]$res_ls[0]) computers are up.`n$([string]$res_ls[1]) computers are down.`n`n"
      }
      #// and a computer is selected: get the status of the selected computer
      elseif($comp_selected -gt 0)
      {
        $res=Test-Connection $comp_ls.$comp_selected.DNSHostName -Count 1 -Quiet
        if($res -eq $True)
        {
          Write-Host "$($comp_ls.$comp_selected.DNSHostName) is up." -foregroundcolor green
        }
        elseif($res -eq $False)
        {
          Write-Host "$($comp_ls.$comp_selected.DNSHostName) is down." -foregroundcolor red
        }
      }
    }
  }

  #// events command
  elseif($input -eq "events")
  {
    #// if an ou is selected, but a computer is not: tell the user
    if(($comp_selected -eq 0) -and ($ou_selected -gt 0))
    {
      $no_comp
    } 
	#// if no ou is selected: tell the user
    elseif($ou_selected -eq 0)
    {
      $no_ou
    }
	#// if a computer is selected: get it's events
    else
    {
	  $ErrorActionPreference = "SilentlyContinue"
      .\event_get.ps1 $comp_ls.$comp_selected.DNSHostName
	  $ErrorActionPreference = "Continue"
    }
  }
}
