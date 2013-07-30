$ErrorActionPreference = "SilentlyContinue"

#// Load help
$help="`n`n/////// ad_get \\\\\\\`n`nNAVIGATIONAL COMMANDS:`n----------------------------------------------------------------------------------------------------`nfind <search term>  --	Search through all OUs for a specific computer.`nshow			--	List all OU's with computers in them.`nselect <number>		--	Select a specific OU or computer to operate in.`nunselect		--	Unselect the selected OU.`n..			--	Go back.`nexit/quit		--	Quit ad_get.`nhelp			--	Display this help screen.`n----------------------------------------------------------------------------------------------------`n`nMANAGEMENT COMMANDS:`n----------------------------------------------------------------------------------------------------`nshell			--	Interact with a remote host via the command line.`ntest			--	Runs the Test-Connection module the selected OU.`nstatus			--	Returns the status of the user on the selected computer.`nnic			--	Show/Configure network adapters on localhost.`ninstalled		--	List the installed software on the selected computer.`ndisk			--	Show disk and partition information on the selected computer.`nevents			--	Show logon/logoff events from the selected computer.`n----------------------------------------------------------------------------------------------------`n`nWINDOWS\POWERSHELL COMMANDS:`n----------------------------------------------------------------------------------------------------`nAlmost all Powershell and Windows commands can be executed as usual.`n----------------------------------------------------------------------------------------------------`n`n"
$shell_help="`n`nUsage: shell [OPTIONAL: [-n] [-c string] [-p]]`n`nCreate a remote Powershell session on a selected computer.`n`nOPTIONS:`n`n  -p		Begin a psexec session as opposed to a PSSession.`n  -n		No new window.`n  -c <computer>	Specify a specific computer to connect to.`n  -h		Print this help screen.`n`n"
$nic_help = "`n/////// Network Adapter Configuration Editor \\\\\\\`n`nCOMMANDS:`n----------`nipconfig		--	Display and change IP info. (All params supported).`nping			--	ICMP Echo request utility. (All params supported).`nnetsh interface		--	Use netsh to change interface settings.  (All params supported).`nset static		--	Set static IP settings.`nset dhcp		--	Receive IP settings via DHCP.`ndc			--	Show domain controllers.`ndomains			--	Show domains.`nedit suffix		--	Change DNS suffix.`nedit interface		--	Change your currently selected network adapter.`nhelp			--	Display this help screen.`nexit/quit		--	Exit to ad_get.`n"    

#// List all of the Organizational Units with computers in them, adding them to a list for future reference.
$ou_ls=@{}; $ou_num=0; $ou_out;   Get-ADOrganizationalUnit -Filter {Name -like '*'} | foreach-object{ $comps=Get-ADComputer -Filter * -Searchbase $_.DistinguishedName; if($comps.count -gt 0){$ou_num++; $ou_ls.Add($ou_num,$comps); $ou_out += $("OU Number $ou_num`n--------------`nRN: " + $_.Name + "`nDN: '" + $_.DistinguishedName + "'`n`n")}}; if($ou_out -eq $null){Write-Host "Could not retrieve information from the Active Directory."; return}

#// Load vars for while loop.
$session=$null; $prefix="ad_get>> "; $colorchange="white"; $ou_selected=0; $comp_selected=0; $no_ou="`nYou do not have an OU selected.  You can select one by tying 'select' followed by the OU number.`n"; $no_comp="`nYou do not have a computer selected.  You can select one by tying 'select' followed by the computer number.`n"; $fail="That is not a valid selection."; $rpc="`nERROR: Failed to establish connection with the host.`n"; $select_lvl=0; $domain_num=0; $nic_running=$False; 

#List of accepted commands:
$cmd_ls=@("help", "exit", "quit", "show", "unselect", "..", "test", "status", "events", "installed", "disk", "nic", "shell", "find")

#// Print Help
$help

function event_get
{
  param([string]$compname , [string]$howmany)

  if($compname.length -eq 0){$compname=Read-Host "`nWhat host do you wish to retrieve logs from?(Type 'localhost', IP Address, NETBIOS, ComputerName, or FQ Domain Name)`n`nGet Logs From"}
  if($howmany.length -eq 0){$howmany=Read-Host "`nHow many of the most recent logs should be retrieved?(Must be greater than or equal to one.)`n`nNumber of Logs"}

  if($compname -eq 'localhost')
  {
    $logs10 = Get-WinEvent -ErrorAction SilentlyContinue -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='10']]</Select></Query></QueryList>"
    $logs2 = Get-WinEvent -ErrorAction SilentlyContinue -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='2']]</Select></Query></QueryList>"
    $logs3 = Get-WinEvent -ErrorAction SilentlyContinue -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='3']]</Select></Query></QueryList>"
  }
  else
  {
    $logs10 = Get-WinEvent -ErrorAction SilentlyContinue -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='10']]</Select></Query></QueryList>"
    $logs2 = Get-WinEvent -ErrorAction SilentlyContinue -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='2']]</Select></Query></QueryList>"
    $logs3 = Get-WinEvent -ErrorAction SilentlyContinue -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='3']]</Select></Query></QueryList>"
  }

  $logobjects=@{}; $count=0
  if((($logs2.count -eq 0) -and ($logs10.count -eq 0)) -and ($logs3.count -eq 0))
  {
    Write-Host "`n`nERROR: Failed to establish connection with the host."
    exit
  }
  
  foreach($log in $logs2)
  {
    $count++
    if($log.Id -eq 4624)
    {
      $props = @{"Id" = $($log.Id);"LogonType" = 2;"SubjectUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
      $object= New-Object -TypeName PSObject -Prop $props
    }
    elseif($log.Id -eq 4634)
    {
      $props = @{"Id" = $($log.Id);"LogonType" = 2;"MachineName" = $($log.MachineName);"Time" = $($log.TimeCreated);}
      $object= New-Object -TypeName PSObject -Prop $props
    }
    $logobjects.Add("Log " + $count, $object)
  }

  foreach($log in $logs10)
  {
    $count++
    if($log.Id -eq 4624)
    {
      $props = @{"Id" = $($log.Id);"LogonType" = 10;"SubjectUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
      $object= New-Object -TypeName PSObject -Prop $props
    }
    elseif($log.Id -eq 4634)
    {
      $props = @{"Id" = $($log.Id);"LogonType" = 10;"TargetUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
      $object= New-Object -TypeName PSObject -Prop $props
    }
    $logobjects.Add("Log " + $count, $object)
  }

  foreach($log in $logs3)
  {
    $count++
    if($log.Id -eq 4624)
    {
      $props = @{"Id" = $($log.Id);"LogonType" = 3;"TargetUsername" = $($log.Properties[5].Value);"LogonProcessName" = $($log.Properties[9].Value);"Time" = $($log.TimeCreated);}
      $object= New-Object -TypeName PSObject -Prop $props
    }
    elseif($log.Id -eq 4634)
    {
      $props = @{"Id" = $($log.Id);    "LogonType" = 3;    "TargetUsername" = $($log.Properties[1].Value);    "Time" = $($log.TimeCreated);    }
      $object= New-Object -TypeName PSObject -Prop $props
    }
    $logobjects.Add("Log " + $count, $object)
  }

  $logobjects= $logobjects.Values | Sort-Object Time -Descending
  $lcount=0
  "`n`nLogons and Logoffs:`n____________________________________`n"
  [int]$countdown=$howmany

  foreach($log in $logobjects)
  {
    $countdown--
    if($countdown -lt 0){break}
    $lcount++
    if($log.LogonType -eq 2){$ltype="Local Interactive Logon (Type 2)"}
    elseif($log.LogonType -eq 3){$ltype="Network Logon (Type 3)"}
    #  elseif($log.LogonType -eq 4){$ltype="Batch Logon (Type 4)"}
    #  elseif($log.LogonType -eq 5){$ltype="Service Logon (Type 5)"}
    #  elseif($log.LogonType -eq 7){$ltype="Unlock Logon (Type 7)"}
    #  elseif($log.LogonType -eq 8){$ltype="Network Cleartext Logon (Type 8)"}
    #  elseif($log.LogonType -eq 9){$ltype="New Credentials Logon (Type 9)"}
    elseif($log.LogonType -eq 10){$ltype="Remote Interactive Logon (Type 10)"}
    #  elseif($log.LogonType -eq 11){$ltype="Cached Interactive Logon (Type 11)"}
  
    "Event Number " + $($lcount)
    "--------------"
    if($log.Id -eq 4624)
    {
      "LOGON"
      $log.Time
      $ltype
      if($log.LogonType -eq 2){$log.SubjectUsername}
      elseif($log.LogonType -eq 3){$log.TargetUsername,$log.LogonProcessName}
      elseif($log.LogonType -eq 10){$log.SubjectUsername}
    }
    elseif($log.Id -eq 4634)
    {
      "LOGOFF"
      $log.Time
      $ltype
      if($log.LogonType -eq 2){$log.MachineName}
      elseif($log.LogonType -eq 10 -or 3){$log.TargetUsername}
    }
    ""
  }  
}

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
          $res=Test-Connection $comp_ls.$comp_selected.DNSHostName -Count 3 -Quiet
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
          $stat_usr=Invoke-Command -ComputerName $comp_ls.$comp_selected.DNSHostName -ScriptBlock {Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue -Computer localhost | select username}
          $stat_usr=$stat_usr.username
          if($stat_usr -eq $null)
          {
            $rpc
          }
          else
          {
            if((Invoke-Command -ComputerName $comp_ls.$comp_selected.DNSHostName -ScriptBlock {$(QUERY SESSION /server:localhost $stat_usr).Contains("Active")}))
            {
              Write-Host "The user is currently active."
            }
            else
            {
              Write-Host "The user is not currently active."
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
        1{$no_comp} 
        0{$no_ou}
        2
        {
          event_get $comp_ls.$comp_selected.DNSHostName
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
      if($select_lvl -eq 2)
      {
        #// Request Disk Information
        $disk_ls = Invoke-Command -ComputerName $comp_ls.$comp_selected.DNSHostName {Get-WmiObject Win32_DiskPartition -ComputerName localhost -ErrorAction SilentlyContinue}

        #// If it didn't work
        if($disk_ls -eq $null)
        {
          $rpc
        }
        else
        {
          Write-Host $("`nDisk Information for " + $comp_ls.$comp_selected.DNSHostName + ":`n")
          foreach($disk in $disk_ls)
          {
            Write-Host $($disk.Name + "`n----------`nBoot Partition: " + $disk.BootPartition + "`nSize: " + $disk.Size + "`nStarting Offset: " + $disk.StartingOffset + "`n")
          }
        }
      }
      else
      {
        $disk_ls = Get-WmiObject Win32_DiskPartition -ComputerName localhost -ErrorAction SilentlyContinue
        #// If it didn't work
        if($disk_ls -eq $null)
        {
          "Failed to retrieve disk information."
        }
        else
        {
          Write-Host $("`nDisk Information for " + $(hostname) + ":`n`n")
          foreach($disk in $disk_ls)
          {
            Write-Host $($disk.Name + "`n----------`nBoot Partition: " + $disk.BootPartition + "`nSize: " + $disk.Size + "`nStarting Offset: " + $disk.StartingOffset + "`n")
          }
        }
      }
    }
    
    #// nic command
    "nic"
    {
      $nic_running=$True
      Write-Host "Loading available interfaces..." 
      netsh interface show interface
      $nic_selected = Read-Host "Interface Name "
      if((netsh interface show interface name $nic_selected) -eq "An interface with this name is not registered with the router.")
      {
        Write-Host "That is an invalid selection."
        $nic_running=$False
      }
      $nic_cmd_ls=@("help", "exit", "quit", "set static", "set dhcp", "domains", "dc", "edit suffix", "edit interface")
      $nic_help
      $colorchange = "white"
      while($nic_running -eq $True)
      {
        Write-Host "nic_get>> " -NoNewline
        $nic_input = Read-Host
        switch($nic_input)
        {
          "set static"
          {
            Write-Host "Here are your current settings."
            netsh interface ipv4 show address $nic_selected
            Write-Host "FILL ALL FIELDS:"
            $static_ip=Read-Host "IP Addr "
            $static_sub=Read-Host "Subnet "
            $static_gate=Read-Host "Gateway "
            netsh interface ipv4 set address $nic_selected static $static_ip $static_sub $static_gate
          }
          "set dhcp"
          {
            netsh interface ipv4 set address $nic_selected dhcp
          }
          "domains"
          {
            $rootDSE = [ADSI]"LDAP://RootDSE"
            $configSearchRoot = [ADSI]("LDAP://" + `
            $rootDSE.Get("configurationNamingContext"))
            $filter = "(NETBIOSName=*)"
            $configSearch = New-Object `
            DirectoryServices.DirectorySearcher($configSearchRoot, $filter)
            $rv = $configSearch.PropertiesToLoad.Add("dnsroot")
            $rv = $configSearch.PropertiesToLoad.Add("ncname")
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
          "edit interface"
          {
            netsh interface show interface
            $nic_selected = Read-Host "`nInterface Name "
            Write-Host "Now using NIC : $nic_selected"
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
        if(($nic_cmd_ls -contains $nic_input) -eq $False)
        {
          Invoke-Expression $nic_input
        }
      }
    }
  }

  #// select command
  if($input.StartsWith("select"))
  {
    $input_ls=$input.Split()
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

  #// find command
  elseif($input.StartsWith("find"))
  {
    if($input -eq "find")
    {
      $fail
    }
    else
    {
      $searchterm=$input.Substring(5)
      $find_comp_num=0
      $foundone=0
      foreach($ou in $ou_ls.Keys)
      {
        foreach($comp in $ou_ls.$ou)
        {
          $find_comp_num++
          if($comp.DNSHostName.ToLower() -eq $searchterm.ToLower())
          {
            "`nFOUND		"+$comp.DNSHostName
            "Located@	ou_$ou>comp_$find_comp_num"
            ""
            $foundone++
          }
          elseif($comp.DNSHostName.ToLower() -like $searchterm.ToLower())
          {
            "`nFOUND		"+$comp.DNSHostName
            "Located@	ou_$ou>comp_$find_comp_num"
            ""
            $foundone++
          }
          elseif($comp.Name.ToLower() -like $searchterm.ToLower())
          {
            "`nFOUND		"+$comp.DNSHostName
            "Located@	ou_$ou>comp_$find_comp_num"
            ""
            $foundone++
          }
          elseif($comp.Name.ToLower() -match $searchterm.ToLower())
          {
            "`nFOUND		"+$comp.DNSHostName
            "Located@	ou_$ou>comp_$find_comp_num"
            ""
            $foundone++
          }
        }
        $find_comp_num=0
      }
      if($foundone -eq 0)
      {
        Write-Host "No results."
      }
      else
      {
        Write-Host $foundone" results found.`n"
      }
    }
  }

  #// shell command
  elseif($input.StartsWith("shell"))
  {
    $input_ls=$input.Split()
    $shell_helped=$False
    if($(@("shell -h","shell --help","shell help","shell(help)")).Contains($input))
    {
      $shell_help
      $shell_helped=$True
    }
    if(($input.Contains("-c") -and ($shell_helped -eq $False)) -and ($($input_ls.IndexOf("-c")+2) -le $input_ls.Count))
    {
      $shell_RHOST=$input_ls[$input_ls.IndexOf("-c")+1]
      if($input_ls.Contains("-p"))
      {
        foreach($dir in $($env:PATH.Split(";")))
        {
          if($(Get-ChildItem -Path $dir -Filter psexec.exe) -ne $null)
          {
            $psexec_found=$True
          }
        }
        if($psexec_found)
        {
          psexec -AcceptEULA -s \\$shell_RHOST cmd.exe
        }
        else
        {
          "psexec.exe is not currently in any directory listed in your PATH variable."
        }
      }
      else
      {
        "Testing Connection..."
        if($(Test-Connection -Count 2 -q $shell_RHOST))
        {
          "Connection is sustainable."
          "Starting Session..."
          if($input_ls.Contains("-n"))
          {
          Write-Host "`n|||||CAUTION:`n|||||This command creates a Powershell session within a Powershell session within a Powershell session.`n|||||You must type exit an additional time to return to reality!`n"
          Powershell -NoExit Enter-PSSession $shell_RHOST
        }
          else
          {
          Start-Process Powershell -ArgumentList "-NoExit Enter-PSSession $shell_RHOST"
          }
        }
        else
        {
        Write-Host $("Cannot connect to " + $shell_RHOST + "!")
        }
      }
    }
    elseif((($input.Contains("-c") -eq $False) -and ($shell_helped -eq $False)) -and ($select_lvl -eq 2))
    {
      $shell_RHOST=$comp_ls.$comp_selected.DNSHostName
      if($input_ls.Contains("-p"))
      {
        foreach($dir in $($env:PATH.Split(";")))
        {
          if($(Get-ChildItem -Path $dir -Filter psexec.exe) -ne $null)
          {
            $psexec_found=$True
          }
        }
        if($psexec_found)
        {
          psexec -AcceptEULA -s \\$shell_RHOST cmd.exe
        }
        else
        {
          "psexec.exe is not currently in any directory listed in your PATH variable."
        }
      }
      else
      {
        "Testing Connection..."
        if($(Test-Connection -Count 2 -q $shell_RHOST))
        {
          "Connection is sustainable."
          "Starting Session..."
          if($input_ls.Contains("-n"))
          {
            Write-Host "`n|||||CAUTION:`n|||||This command creates a Powershell session within a Powershell session within a Powershell session.`n|||||You must type exit an additional time to return to reality!`n"
            Powershell -NoExit Enter-PSSession $shell_RHOST
          }
          else
          {
            Start-Process Powershell -ArgumentList "-NoExit Enter-PSSession $shell_RHOST"
          }
        }
        else
        {
          Write-Host $("Cannot connect to " + $shell_RHOST + "!")
        }
      }
    }
    elseif($shell_helped -eq $False)
    {
      $fail
    }
  }

  #// everything else
  elseif(($cmd_ls -contains $input) -eq $False)
  {
    Invoke-Expression $input
  }
}
