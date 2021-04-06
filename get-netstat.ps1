$netstat = netstat -aon -p tcp |findstr /I "TCP"

$tcpconnections = foreach($line in $netstat){
 [pscustomobject]@{
  SourceIP = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[1].split(":")[0]
  SourcePort = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[1].split(":")[1]
  DestinationIP = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[2].split(":")[0]
  DestinationPort = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[2].split(":")[1]
  ConnectionState = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[3]  
  PID = $line.Split("",[System.StringSplitOptions]::RemoveEmptyEntries)[4]
  }
}

$dynport = netsh int ipv4 show dynamicport tcp |findstr /I ":"
$dynports = [pscustomobject]@{
StartPort = $dynport[0].split(":",[System.StringSplitOptions]::RemoveEmptyEntries)[1]
TotalPorts = $dynport[1].split(":",[System.StringSplitOptions]::RemoveEmptyEntries)[1]
}


$ephport = ($tcpconnections|?{$_.Sourceport -gt [int]$dynports.startport}).count

$Portusagepct = ($ephport/[int]$dynports.TotalPorts)/100

$Portusagepct
[math]::round($Portusagepct,2)