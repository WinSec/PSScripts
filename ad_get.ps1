#// Load help
$help="`n`nCOMMANDS:`n----------`nshow  		--	List all OU's with computers in them.`nselect <number>		--	Select a specific OU or computer to operate in.`nunselect		--	Unselect the selected OU.`nstatus			--	Show the up/down status of computers in the selected OU.`nevents			--	Show logon/logoff events from the selected computer.`n`n"

#// List all of the Organizational Units with computers in them, adding them to a list for future reference.
$ou_ls=@{}; $ou_num=0; $ou_out; Get-ADOrganizationalUnit -Filter {Name -like '*'} | foreach-object{$comps=Get-ADComputer -Filter * -Searchbase $_.DistinguishedName; if($comps.count -gt 0){$ou_num++;$ou_ls.Add($ou_num,$comps);$ou_out += $("OU Number $ou_num`n--------------`nRN: " + $_.Name + "`nDN: '" + $_.DistinguishedName + "'`n`n")}}

#// Load vars for while loop.
$prefix="ad_get>> "; $colorchange="white"; $ou_selected=0; $comp_selected=0; $no_ou="`nYou do not have an OU selected.  You can select one by tying 'select' followed by the OU number.`n"; $no_comp="`nYou do not have a computer selected.  You can select one by tying 'select' followed by the computer number.`n"

while($True)
{
  #// Take input
  Write-Host $prefix -Foregroundcolor $colorchange -NoNewline; $input=Read-Host

  #// show command
  if($input -eq "show"){if($ou_selected -gt 0){$comp_ls=@{}; $comp_num=0; foreach($comp in $ou_ls.$ou_selected){$comp_num++; $comp_ls.Add($comp_num, $comp); Write-Host "`n`nComputer Number "$($comp_num)"`n----------`nHN:  "$($comp.DNSHostName)"`nDN:  '"$($comp.DistinguishedName)"'"}; Write-Host "`n`n"} elseif($ou_selected -eq 0){$ou_out}}

  #// help command
  elseif($input -eq "help"){$help}

  #// select command
  elseif($input.StartsWith("select")){if($ou_selected -gt 0){[int]$comp_selected=$input.Substring(7); $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">comp_" + $($comp_selected.ToString()) + ">> "); $colorchange="cyan"} elseif($ou_selected -eq 0){[int]$ou_selected=$input.Substring(7); $prefix=$("ad_get>ou_" + $($ou_selected.ToString()) + ">> "); $colorchange="red"}}

  #// unselect command
  elseif($input -eq "unselect"){if($ou_selected -eq 0){$no_ou} else{[int]$ou_selected=0; $comp_selected=''; $prefix="ad_get>> "; $colorchange="white"}}

  #// status command
  elseif($input -eq "status"){if($ou_selected -eq 0){$no_ou} else{if(($ou_selected -gt 0) -and ($comp_selected -eq 0)){$res_ls=@(0,0); foreach($comp in $ou_ls.$ou_selected){$res=Test-Connection $comp.DNSHostName -Count 1 -Quiet;if($res -eq $True){$res_ls[0]++; Write-Host "$($comp.DNSHostName) is up." -foregroundcolor green} elseif($res -eq $False){$res_ls[1]++; Write-Host "$($comp.DNSHostName) is down." -foregroundcolor red}}Write-Host "`n`nSummary:`n----------`n$([string]$res_ls[0]) computers are up.`n$([string]$res_ls[1]) computers are down.`n`n"} elseif(($ou_selected -gt 0) -and ($comp_selected -gt 0)){$res=Test-Connection $comp_ls.$comp_selected.DNSHostName -Count 1 -Quiet;if($res -eq $True){Write-Host "$($comp.DNSHostName) is up." -foregroundcolor green} elseif($res -eq $False){Write-Host "$($comp.DNSHostName) is down." -foregroundcolor red}}}}

  #// events command
  elseif($input -eq "events"){if(($comp_selected -eq 0) -and ($ou_selected -ne 0)){$no_comp} elseif($ou_selected -eq 0){$no_ou} else{.\event_get.ps1 -$comp_ls.$comp_selected.DNSHostName}}
}
