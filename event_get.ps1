param([string]$compname)

if($compname.length -eq 0){$compname=Read-Host "`nWhat host do you wish to retrieve logs from?(Type 'localhost', IP Address, NETBIOS, ComputerName, or FQ Domain Name)`n`nGet Logs From"}

$howmany=Read-Host "`nHow many of the most recent logs should be retrieved?(Must be greater than or equal to one.)`n`nNumber of Logs"

if($compname -eq 'localhost'){
  $logs10 = Get-WinEvent -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='10']]</Select></Query></QueryList>"
  $logs2 = Get-WinEvent -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='2']]</Select></Query></QueryList>"
  $logs3 = Get-WinEvent -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='3']]</Select></Query></QueryList>"
}
else{
  $logs10 = Get-WinEvent -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='10']]</Select></Query></QueryList>"
  $logs2 = Get-WinEvent -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='2']]</Select></Query></QueryList>"
  $logs3 = Get-WinEvent -ComputerName $compname -MaxEvents $howmany -FilterXml "<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[(EventID=4624 or EventID=4634)]] and *[EventData[Data[@Name='LogonType']='3']]</Select></Query></QueryList>"
}

$logobjects=@{}

$count=0

foreach($log in $logs2)
{
  $count++
  if($log.Id -eq 4624){
    $props = @{"Id" = $($log.Id);"LogonType" = 2;"SubjectUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
    $object= New-Object -TypeName PSObject -Prop $props
  }
  elseif($log.Id -eq 4634){
    $props = @{"Id" = $($log.Id);"LogonType" = 2;"MachineName" = $($log.MachineName);"Time" = $($log.TimeCreated);}
    $object= New-Object -TypeName PSObject -Prop $props
  }
  $logobjects.Add("Log " + $count, $object)
}


foreach($log in $logs10)
{
  $count++
  if($log.Id -eq 4624){
    $props = @{"Id" = $($log.Id);"LogonType" = 10;"SubjectUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
    $object= New-Object -TypeName PSObject -Prop $props
  }
  elseif($log.Id -eq 4634){
    $props = @{"Id" = $($log.Id);"LogonType" = 10;"TargetUsername" = $($log.Properties[1].Value);"Time" = $($log.TimeCreated);}
    $object= New-Object -TypeName PSObject -Prop $props
  }
  $logobjects.Add("Log " + $count, $object)
}

foreach($log in $logs3)
{
  $count++
  if($log.Id -eq 4624){
    $props = @{"Id" = $($log.Id);"LogonType" = 3;"TargetUsername" = $($log.Properties[5].Value);"LogonProcessName" = $($log.Properties[9].Value);"Time" = $($log.TimeCreated);}
    $object= New-Object -TypeName PSObject -Prop $props
  }
  elseif($log.Id -eq 4634){
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
