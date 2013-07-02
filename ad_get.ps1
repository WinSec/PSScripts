Import-Module NetAdapter
$ErrorActionPreference = "SilentlyContinue"

#// Load help
$help="`n`n/////// ad_get \\\\\\\`n`nCOMMANDS:`n----------`nrunas <user>		--	Execute commands as the user provided.`nshow			--	List all OU's with computers in them.`nselect <number>		--	Select a specific OU or computer to operate in.`nunselect		--	Unselect the selected OU.`n..			--	Go back.`ntest			--	Runs the Test-Connection module the selected OU.`nstatus			--	Returns the status of the selected computer (Active/Locked).`nnic			--	Show the network adapter information on the selected computer.`ninstalled		--	List the installed software on the selected computer.`ndisk			--	Show disk and partition information on the selected computer.`nevents			--	Show logon/logoff events from the selected computer.`nexit/quit		--	Quit ad_get.`nhelp			--	Display this help screen.`n`n"

#// List all of the Organizational Units with computers in them, adding them to a list for future reference.
$ou_ls=@{}; $ou_num=0; $ou_out;   Get-ADOrganizationalUnit -Filter {Name -like '*'} | foreach-object{ $comps=Get-ADComputer -Filter * -Searchbase $_.DistinguishedName; if($comps.count -gt 0){$ou_num++; $ou_ls.Add($ou_num,$comps); $ou_out += $("OU Number $ou_num`n--------------`nRN: " + $_.Name + "`nDN: '" + $_.DistinguishedName + "'`n`n")}}; if($ou_out -eq $null){Write-Host "Could not retrieve information from the Active Directory."; return}

#// Load vars for while loop.
$prefix="ad_get>> "; $colorchange="white"; $ou_selected=0; $comp_selected=0; $no_ou="`nYou do not have an OU selected.  You can select one by tying 'select' followed by the OU number.`n"; $no_comp="`nYou do not have a computer selected.  You can select one by tying 'select' followed by the computer number.`n"; $fail="That is not a valid selection."; $rpc="`nERROR: Failed to establish connection with the host.`n"; $select_lvl=0; $domain_num=0; $nic_running=$False

#// Print Help
$help

while($True)
{
  #// update the selection level
  #// ou and comp
  if(($ou_selected -gt 0) -and ($comp_selected -gt 0))
  {
    $select_lvl=2
  }
  #// just ou
  elseif(($ou_selected -gt 0) -and ($comp_selected -eq 0))
  {
    $select_lvl=1
  }
  #// nothing
  elseif($ou_selected -eq 0)
  {
    $select_lvl=0
  }

  #// take input
  Write-Host $prefix -Foregroundcolor $colorchange -NoNewline; $input=Read-Host

  switch($input)
  {
    #// help command
    "help"{$help}

    #// exit/quit command
    "exit"{return}
    "quit"{return}

    #// show command
    "show"
    {
      switch ($select_lvl) 
      {
        #// if an ou is selected, along with a comp, show the selected comp
        2
  	     {
          Write-Host "`n`nComputer Number"$comp_selected"`n----------`nHN:  "$($comp_ls.$comp_selected.DNSHostName)"`nDN:  '"$($comp_ls.$comp_selected.DistinguishedName)"'`n`n"
        }
        #// if an ou is selected, show the computers
        1
        {
          foreach($comp in $comp_ls.Keys)
          {
            Write-Host "`n`nComputer Number"$comp"`n----------`nHN:  "$($comp_ls.$comp.DNSHostName)"`nDN:  '"$($comp_ls.$comp.DistinguishedName)"'"
          }
          Write-Host "`n`n"
        }
        #// if an ou is not selected, show the ous
        0
        {
          $ou_out
        }
      }
    }

    #// unselect command
    "unselect"
    {
      if($select_lvl -eq 0)
	  {
	    $no_ou
	  }
	  else
	  {
	    [int]$ou_selected=0
        $comp_selected=0
        $prefix="ad_get>> "
        $colorchange="white"
	  }
    }
  
    #// go back
    ".."
    {
      switch($select_lvl)
      {
        #// if an ou isn't selected, tell the user
        0
        {
          $no_ou
        }
        #// if an ou is selected, and not a computer deselect the ou
        1
        {
          $ou_selected=0
          $comp_selected=0
          $prefix="ad_get>> "
          $colorchange="white"
        }
        #// if both, deselect the computer
        2
        {
          $comp_selected=0
          $colorchange="red"
          $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">> ")
        }
      }
    }

    #// test command
    "test"
    {
      switch($select_lvl)
      {
        #// if no ou is selected, tell the user
        0
        {
          $no_ou
        }
        #// if an ou is selected, 
        1
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
        2
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
  
    #// status command
    "status"
    {
      switch($select_lvl)
      {
        #// if an ou is selected, but a computer is not: tell the user
        1
        {
          $no_comp
        } 
        #// if no ou is selected: tell the user
        0
        {
          $no_ou
        }
        #// if a computer is selected: get it's status
        2
        {
          $stat_usr=Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue -Computer $comp_selected | select username
          if($stat_usr -eq $null)
          {
            $rpc
          }
          else
          {
            if(QUERY SESSION /server:$comp_selected $stat_usr | -contains "Active")
            {
              Write-Host "Session is currently active."
            }
            else
            {
              Write-Host "Session is currently locked."
            }
          }
        }
      }    
    }

    #// events command
    "events"
    {
      switch($select_lvl)
      {
        #// if an ou is selected, but a computer is not: tell the user
        1
        {
          $no_comp
        } 
        #// if no ou is selected: tell the user
        0
        {
          $no_ou
        }
        #// if a computer is selected: get it's events
        2
        {
          $ErrorActionPreference = "SilentlyContinue"
          .\event_get.ps1 $comp_ls.$comp_selected.DNSHostName
          $ErrorActionPreference = "Continue"
        }
      }
    }
  
    #// installed command
    "installed"
    {
      switch($select_lvl)
      {
        #// if an ou is selected, but a computer is not: tell the user
        1
        {
          $no_comp
        }
        #// if no ou is selected: tell the user
        0
        {
          $no_ou
        }
        2
        {
          #// Request the software information and disable errors for this command
          $installed=Get-WmiObject -ErrorAction SilentlyContinue -Class Win32_Product -ComputerName $comp_selected -Credential $usr_selected

          #// If it didn't work, tell the user
          if($installed -eq $null)
          {
            $rpc
          }
          #// If it worked, show the software information
          else
          {
            $installed
          }
        }
      }
    }

    #// disk command
    "disk"
    {
      #// Request Disk Information
      $disk_ls = Get-WmiObject Win32_DiskPartition -ComputerName $comp_selected -ErrorAction SilentlyContinue

      #// If it didn't work
      if($disk_ls -eq $null)
      {
        $rpc
      }
      else
      {
        foreach($disk in $disk_ls)
        {
          Write-Host $("`n" + $disk.Name + "`n----------`nBoot Partition: " + $disk.BootPartition + "`nSize: " + $disk.Size + "`nStarting Offset: " + $disk.StartingOffset + "`n")
        }
      }
    }
	
    #// nic command
    "nic"
    {
	  $nic_running=$True
	  Write-Host "Please select an interface..." -NoNewLine
	  Read-Host
	  netsh interface show interface
	  $nic_selected = Read-Host "Interface Name "
	  if((netsh interface show interface name=$nic_selected) -eq "An interface with this name is not registered with the router.")
	  {
	    Write-Host "That is an invalid selection."
		$nic_running=$False
	  }
	  $nic_help = "`n/////// Network Adapter Configuration Editor \\\\\\\`n`nCOMMANDS:`n----------`nipconfig		--	Display and change IP info. (All params supported).`nnetsh interface		--	Use netsh to change interface settings.  (All params supported).`ndc			--	Show domain controllers.`ndomains			--	Show domains.`nedit suffix		--	Change DNS suffix.`nedit interface		--	Change your currently selected network adapter.`nedit mac		--	Change your MAC Address.`nhelp			--	Display this help screen.`nexit/quit		--	Exit to ad_get.`n"
	  $nic_help
	  $ou_selected = 0
      $comp_selected = 0
      $colorchange = "white"
	  while($nic_running -eq $True)
	  {
		Write-Host "nic_get>> " -NoNewline
		$nic_input = Read-Host
		if($nic_input.StartsWith("ipconfig"))
		{
		  Invoke-Expression $nic_input
		  ""
		}
		elseif($nic_input.StartsWith("netsh interface"))
		{
		  Invoke-Expression $nic_input
		}
		switch($nic_input)
		{
		  "domains"
		  {
			# Connect to RootDSE
            $rootDSE = [ADSI]"LDAP://RootDSE"
 
            # Connect to the Configuration Naming Context
            $configSearchRoot = [ADSI]("LDAP://" + `
            $rootDSE.Get("configurationNamingContext"))
 
            # Configure the filter
            $filter = "(NETBIOSName=*)"
 
            # Search for all partitions where the NetBIOSName is set
            $configSearch = New-Object `
            DirectoryServices.DirectorySearcher($configSearchRoot, $filter)
 
            # Configure search to return dnsroot and ncname attributes
            $retVal = $configSearch.PropertiesToLoad.Add("dnsroot")
            $retVal = $configSearch.PropertiesToLoad.Add("ncname")
 
            $csfa=$configSearch.FindAll()
			Write-Host "`nDomains`n----------"
		    $csfa.Properties.dnsroot
		    ""
		  }
		  "dc"
		  {
            Write-Host "`nDomain Controllers:`n----------"
            [system.directoryservices.activedirectory.domain]::GetCurrentDomain() | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name}
			Write-Host ""
		  }
		  "edit suffix"
		  {
			$nic_suffix = Read-Host "DNS Suffix "
			Set-DnsClient -InterfaceIndex 12 -ConnectionSpecificSuffix $nic_suffix
		  }
		  "edit mac"
		  {
			$nic_mac = Read-Host "MAC Address "
			Set-NetAdapter -InterfaceDescription B*2 -MacAddress $nic_mac
		  }
		  "edit interface"
		  {
		  	netsh interface show interface
	        $nic_selected = Read-Host "Interface Name "
	        if((netsh interface show interface name=$nic_selected) -eq "An interface with this name is not registered with the router.")
	        {
	          Write-Host "That is an invalid selection."
		    }
		  }
		  "help"
		  {
			$nic_help
		  }
	      "exit"
	      {
			$nic_running=$False
			switch($select_lvl)
			{
			  2
			  {
			    $colorchange="cyan"
			  }
			  1
			  {
			    $colorchange="red"
			  }
			  0
			  {
			    $colorchange="white"
			  }
			}
		  }
	      "quit"
		  {
            $nic_running=$False
			switch($select_lvl)
			{
			  2
			  {
			    $colorchange="cyan"
			  }
			  1
			  {
			    $colorchange="red"
			  }
			  0
			  {
			    $colorchange="white"
			  }
			}
		  }
	    }
	  }
    }
  }
  
  #// select command
  if($input.StartsWith("select"))
  {
    $testvar=$null
    if($input -eq "select")
    {
      Write-Host $fail
    }
    #// if the selection is numerical, and and in the ou_ls, proceed
    elseif(([Int32]::TryParse($input.Substring(7), [ref]$testvar) -and ([int32]$input.Substring(7) -ne 0)) -and !($input -eq "select"))
    {
      switch ($select_lvl)
      {
        #// if an ou is selected and a computer is selected, tell the user
        2
        {
          Write-Host "You have already made a selection."
          $select_lvl=2
        }
        #// if an ou is selected, select a computer
        1
        {
          #// if the selection is a valid comp number
          if([int32]$input.Substring(7) -le $comp_ls.count)
          {
            #// Computer Selection Process
            [int]$comp_selected=$input.Substring(7)
            $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">comp_" + $($comp_selected.ToString()) + ">> ")
            $colorchange="cyan"
            $select_lvl=2
          }
          else
          {
            Write-Host $fail
          }
        }
        #// if an ou is not selected, select an ou 
        0
        {
          #// if the selection is a valid ou number
          if([int32]$input.Substring(7) -le $ou_ls.count)
          {
            #// OU Selection Process
            [int]$ou_selected=$input.Substring(7)
            $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">> ")
            $colorchange="red"
            $select_lvl=1
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
    }
    else
    {
      Write-Host $fail
    }
  }   
  
  #// runas command
  elseif($input.StartsWith("runas"))
  {
    if($input -eq "runas")
    {
      $fail
    }
    else
    {
      if((($input.Substring(6) -eq $null) -or ($input.Substring(6) -eq " ")) -and !([Int32]::TryParse($input.Substring(6), [ref]$testvar)))
      {
        $fail
      }
      else
      {
        $usr_selected=$input.Substring(6)
        switch($select_lvl)
        {
          2
          {
            $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">comp_" + $($comp_selected.ToString()) + ">> ")
          }
          1
          {
            $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">> ")
          }
          0
          {
            $prefix="ad_get>> "
          }
        }
      }
    }
  }  
}
