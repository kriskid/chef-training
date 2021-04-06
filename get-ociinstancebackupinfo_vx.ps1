<# 
.SYNOPSIS
Export backup details of block volumes attached to a compute instance in CSV format. 
.DESCRIPTION
This script uses oci commands and normalizes the output and converts the output to a standard csv format which can be read using MS Excel.
.PARAMETER inputfile
Provide a file name in current directory same as the script or full path of a file name containing a list of OCID's. The default is .\serverocids.txt

.PARAMETER Outputfile
Provide a file name in current directory same as the script or full path of a file name containing a list of OCID's. the default is output-info.csv

.PARAMETER profile
While loging in to OCI a profile name is requested. The user has the option to choose the profile name, the default value has been kept as "default".
If you are choosing a differnet profile, use -profile profile-name to specify the profile to use.

.PARAMETER MaxSimultaneousJobs
This parameter helps you tue the number of jobs that can be executed simultaneously to complete retrieving information as quickly as possible by running multiple queries.


.INPUTS
The defaut input file is named serverocids.txt which can be populated with the OCI ID of the compute instance for whcih backup inforation needs to be checked.

.OUTPUTS
The defaut output file is named output-info.csv and will be located in the same path as the script is kept and executed from.

.EXAMPLE
C:\oci> .\get-ociinstancebackupinfo.ps1

Without any patameter, the script assumes all the default parameters will work.
1. a file named serverocids.txt exist in the folder from where the script is being executed.
2. outputfile name will be output-info.csv
3. profile name is "DEFAULT"
4. MaxSimultaneousJobs is 3

.EXAMPLE
C:\oci> .\get-ociinstancebackupinfo.ps1 -inputfile .\inputfile.txt 
With only inputfile Parameter the script assumes all other parameters to be default.
1. outputfile name will be output-info.csv
2. profile name is "DEFAULT"
3. MaxSimultaneousJobs is 3

.EXAMPLE

C:\oci> .\get-ociinstancebackupinfo.ps1 -inputfile .\inputfile.txt -Outputfile output.csv -profile MYPROFILE

Profile name is case sensitive, if you use a differnet profile name other than DEFAULT, specify the profile name using the -profile parameter.

.EXAMPLE

C:\oci> .\get-ociinstancebackupinfo.ps1 -inputfile .\inputfile.txt -Outputfile output.csv -profile DEFAULT -MaxSimultaneousJobs 6

This will run 6 simultaneous jobs instead of default 3.

.NOTES
	Author: Krishna Kumar
        Change Log:
    Version 1.0
    16-Feb-2021 : Initial Version created for retrieving backup info for a compute instance using oci cli.
    17-Feb-2021 : updated the script help section with examples.
    23-Feb-2021 : Input file simplified, no need to search for OCIID's, script will leverage the asset query api to get the information from server names provided in input file.

.LINK
    https://www.google.com
    
#>

Param(
      [Parameter(Mandatory=$False) ] [String]$profile="DEFAULT",
	  [Parameter(Mandatory=$false)] [string]$inputfile=".\serverocids.txt",
      [Parameter(Mandatory=$false)] [int]$MaxSimultaneousJobs=3,
      [Parameter(Mandatory=$false)] [String]$Outputfile=".\output-info.csv"
  )

$ErrorActionPreference = "SilentlyContinue"
#=====check if user has a valid  OCI session=====# 
oci session validate --profile $profile --auth security_token
$checkerror = $?
 if($checkerror -eq $false) {
  Write-Host "Authentication failed - Please authenticate to oci-cli and also verify oci-cli is installed" -ForegroundColor 'red'
  break
 }

$scriptstarttime =  get-date
$watch = $false
$serverlist = gc $inputfile
$serverlistcount = $serverlist.count
$srvcount=0
$jobcount=0

if($serverlist.count -eq 0){
Write-Host "Input file empty" -ForegroundColor 'red'
break
}

function get-auth_token{
$headers1 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers1.Add("Content-Type", "application/x-www-form-urlencoded")
$headers1.Add("Authorization", "Basic R0JVQ1MtQ29tcHV0ZS1PcGVyYXRpb25zXzQ0YzEyZTdkZDg1YzRjOWJiZWJlYzk5OWJkMGJmYmQxOllscUhzeFNxd043")
$body1 = "grant_type=client_credentials&scope=GBUCS-Compute-Operations.AssetMgmt.rest.public"
$response1 = Invoke-RestMethod "https://oauth-e.oracle.com/ms_oauth/oauth2/endpoints/oauthservice/tokens" -Method 'POST' -Headers $headers1 -Body $body1
$token = $response1.access_token
return $token
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("client-id", "GBUCS-Compute-Operations_44c12e7dd85c4c9bbebec999bd0bfbd1")
$headers.Add("client-scope", "GBUCS-Compute-Operations.AssetMgmt.rest.public")
#$headers.Add("assertion", $token)
#$tkn = get-auth_token
$error.clear();
 try {$tkn = gc .\access_token.txt -ErrorAction silentlycontinue}catch{}
  if ($error.exception -like "*does not exist*"){
   #write-host "error file dosent exist" -ForegroundColor "RED";"axcfgsdt"|out-file .\access_token.txt
   $tkn = gc .\access_token.txt
  }
#$tkn = gc .\access_token.txt
$headers.Add("assertion",$tkn)
$headers.Add("AM-QUERY-SCOPE", "LIKE")
$headers.Add("AM-QUERY-BOOLEAN", "AND")
$headers.Add("Authorization", "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsIng1dCI6Il96SzlXaWZXXzZIS1Z5UmRhOGZpUjQyTlFPVSIsImtpZCI6InN0YW5kYXJkX29hdXRoX2tleV9zaGEyNTZ3aXRocnNhIn0.eyJzdWIiOiJBc3NldE1nbXQtZjM3NWJiMzc5YmRlNDljYzlkZTc0N2M0MGRmZGFlNzIiLCJpc3MiOiJ3d3cub3JhY2xlLmV4YW1wbGUuY29tIiwib3JhY2xlLm9hdXRoLnN2Y19wX24iOiJPQXV0aFNlcnZpY2VQcm9maWxlIiwiaWF0IjoxNTg2MjExNTE3LCJvcmdJRCI6IjQ1Njc4Iiwib3JhY2xlLm9hdXRoLnBybi5pZF90eXBlIjoiQ2xpZW50SUQiLCJleHAiOjE1ODYyMTUxMTcsIm9yYWNsZS5vYXV0aC50a19jb250ZXh0IjoicmVzb3VyY2VfYWNjZXNzX3RrIiwicHJuIjoiQXNzZXRNZ210LWYzNzViYjM3OWJkZTQ5Y2M5ZGU3NDdjNDBkZmRhZTcyIiwianRpIjoiZDI5MWQ2MmYtMWViMi00MmMxLWEzODEtN2RlYmE2MTZhZDhjIiwib3JhY2xlLm9hdXRoLmNsaWVudF9vcmlnaW5faWQiOiJBc3NldE1nbXQtZjM3NWJiMzc5YmRlNDljYzlkZTc0N2M0MGRmZGFlNzIiLCJvcmFjbGUub2F1dGguc2NvcGUiOiJBc3NldE1nbXQucmVzdC5wdWJsaWMiLCJ1c2VyLnRlbmFudC5uYW1lIjoiRGVmYXVsdERvbWFpbiIsIm9yYWNsZS5vYXV0aC5pZF9kX2lkIjoiZmRkY2JhYzItZGVlMi00NzhiLTg1YzItY2ZkNmMwNDY1MWJiIn0.Il4wtyBeXhgc6chaYmb1PG4jXQ_IAAVmSb2ASaPR979xz4C1mr1GzEniWHjZd7_Y1oE7Ch69i_WiDeVaTiIWuy006RQQjXXr_nxplR8NM-sP2ukk7nosTuVeQEEnAcKk0QkOruMXcxaqpDUAj-k724gAx-uiG4mm_aq0XXkfEOPaclwMnEOoDncrJ_sm3cYdDDJv7tMs8-xqSlxI-I45PpE2Gj-sdvAly7x90bZ3afUyk04uW1xgRyZuchwqF2EPtYKmFIpQCEm42JVXeoNy33FkK8MgBCeL2zYFZaS26lJsvdJPIu82-TRy0Z64W4nlH1IfZXe4yUNBqiq9KWtRVA")

$serverocids = Foreach ($server in $serverlist) {
$body = "{`n  `"component`": [`n    {`n      `"name`": `"$server%`",`n `"source_system`": `"OCI%`",`n  `"type_pre_translation`": `"Instance`"`n }`n  ]`n}"
$error.clear()
try{
$response = Invoke-RestMethod 'https://am-gbucs.oracleindustry.com/assetmgmt/search?pageNumber=1&pageSize=200' -Method 'POST' -Headers $headers -Body $body -ErrorAction SilentlyContinue
}catch{
}
#$error.exception
if ($error.exception -like "*(401) Unauthorized*"){
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("client-id", "GBUCS-Compute-Operations_44c12e7dd85c4c9bbebec999bd0bfbd1")
$headers.Add("client-scope", "GBUCS-Compute-Operations.AssetMgmt.rest.public")
#$headers.Add("assertion", $token)
get-auth_token | out-file access_token.txt
$tkn = gc access_token.txt
$headers.Add("assertion",$tkn)
$headers.Add("AM-QUERY-SCOPE", "LIKE")
$headers.Add("AM-QUERY-BOOLEAN", "AND")
$headers.Add("Authorization", "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsIng1dCI6Il96SzlXaWZXXzZIS1Z5UmRhOGZpUjQyTlFPVSIsImtpZCI6InN0YW5kYXJkX29hdXRoX2tleV9zaGEyNTZ3aXRocnNhIn0.eyJzdWIiOiJBc3NldE1nbXQtZjM3NWJiMzc5YmRlNDljYzlkZTc0N2M0MGRmZGFlNzIiLCJpc3MiOiJ3d3cub3JhY2xlLmV4YW1wbGUuY29tIiwib3JhY2xlLm9hdXRoLnN2Y19wX24iOiJPQXV0aFNlcnZpY2VQcm9maWxlIiwiaWF0IjoxNTg2MjExNTE3LCJvcmdJRCI6IjQ1Njc4Iiwib3JhY2xlLm9hdXRoLnBybi5pZF90eXBlIjoiQ2xpZW50SUQiLCJleHAiOjE1ODYyMTUxMTcsIm9yYWNsZS5vYXV0aC50a19jb250ZXh0IjoicmVzb3VyY2VfYWNjZXNzX3RrIiwicHJuIjoiQXNzZXRNZ210LWYzNzViYjM3OWJkZTQ5Y2M5ZGU3NDdjNDBkZmRhZTcyIiwianRpIjoiZDI5MWQ2MmYtMWViMi00MmMxLWEzODEtN2RlYmE2MTZhZDhjIiwib3JhY2xlLm9hdXRoLmNsaWVudF9vcmlnaW5faWQiOiJBc3NldE1nbXQtZjM3NWJiMzc5YmRlNDljYzlkZTc0N2M0MGRmZGFlNzIiLCJvcmFjbGUub2F1dGguc2NvcGUiOiJBc3NldE1nbXQucmVzdC5wdWJsaWMiLCJ1c2VyLnRlbmFudC5uYW1lIjoiRGVmYXVsdERvbWFpbiIsIm9yYWNsZS5vYXV0aC5pZF9kX2lkIjoiZmRkY2JhYzItZGVlMi00NzhiLTg1YzItY2ZkNmMwNDY1MWJiIn0.Il4wtyBeXhgc6chaYmb1PG4jXQ_IAAVmSb2ASaPR979xz4C1mr1GzEniWHjZd7_Y1oE7Ch69i_WiDeVaTiIWuy006RQQjXXr_nxplR8NM-sP2ukk7nosTuVeQEEnAcKk0QkOruMXcxaqpDUAj-k724gAx-uiG4mm_aq0XXkfEOPaclwMnEOoDncrJ_sm3cYdDDJv7tMs8-xqSlxI-I45PpE2Gj-sdvAly7x90bZ3afUyk04uW1xgRyZuchwqF2EPtYKmFIpQCEm42JVXeoNy33FkK8MgBCeL2zYFZaS26lJsvdJPIu82-TRy0Z64W4nlH1IfZXe4yUNBqiq9KWtRVA")
$response = Invoke-RestMethod 'https://am-gbucs.oracleindustry.com/assetmgmt/search?pageNumber=1&pageSize=200' -Method 'POST' -Headers $headers -Body $body -ErrorAction SilentlyContinue
}
$response.component |select Name,Source_system, type, id
#($response.component).count
}

#$serverocids
if ($serverocids.count -eq 0){
Write-Host "Could not find the servers listed in the input file." -ForegroundColor 'red'
Break
}

$assetqueryresponsecount = $serverocids.Count
if($serverlistcount -eq 1) {
Write-Host "Input file has $serverlistcount item, found $assetqueryresponsecount with asset query" -ForegroundColor 'Yellow'
}else{
Write-Host "Input file has $serverlistcount items, found $assetqueryresponsecount with asset query" -ForegroundColor 'Yellow'
}

$scriptblock = {
 #script Parameters
 Param($instanceid,$profile)
  
 if ($profile -eq "") {
  $profile = "default"
 }
  
 $region = $instanceid.Split('.')[3]
 $ociid = $instanceid
 
 $instanceinfo = oci --profile $profile --auth security_token compute instance get --instance-id $ociid --region $region|convertfrom-json
 
 $vmbv = oci compute volume-attachment list --instance-id $ociid --profile $profile --auth security_token --region $region|convertfrom-json
 $vmbv1 = oci compute boot-volume-attachment list --instance-id $ociid --profile $profile --auth security_token --region $region --availability-domain $instanceinfo.data.'availability-domain' --compartment-id $instanceinfo.data.'compartment-id' |convertfrom-json
  
  $volbackups = foreach($bv in $vmbv.data.'volume-id'){
   oci bv backup list --compartment-id $instanceinfo.data.'compartment-id' --volume-id $bv --profile $profile --auth security_token --region $region| ConvertFrom-Json
  }
  
  $uniqvoldid = $volbackups.data |select 'volume-id' -Unique
  $volbackups1 = $uniqvoldid | %{
  $volid = $_.'Volume-id'
  $volname = ($vmbv.data |?{$_.'volume-id' -eq $volid}).'display-name'
   $volbackups.data |?{$_.'volume-id' -eq $volid} | select * , @{l="devname";e={$volname}}
   }
      
   $bootvolbackup = oci bv boot-volume-backup list --compartment-id $instanceinfo.data.'compartment-id' --boot-volume-id $vmbv1.data.'boot-volume-id' --profile $profile --auth security_token --region $region|convertfrom-json
   
   $output = [PSCustomObject]@{
        IN = $instanceinfo.data.'display-Name'
        VD = $vmbv.data
   		'Comp-id' = $instanceinfo.data.'compartment-id'
   		AD = $instanceinfo.data.'availability-domain'
   		Customer = $instanceinfo.data.'extended-metadata'.IC_global_tag_ns.IC_customer
   		Costcenter = $instanceinfo.data.'extended-metadata'.IC_global_tag_ns.IC_Cost_Center
   		LOB = $instanceinfo.data.'extended-metadata'.IC_global_tag_ns.IC_Line_of_Business
   		'Maintenance_reboot' = $instanceinfo.data.'Maintenance-reboot'
   		'Compliance-Level' = $instanceinfo.data.'extended-metadata'.IC_global_tag_ns.IC_Compliance_Level
   		'Boot-volume' = $vmbv1.data
   		'block-volume-backup' = $volbackups1
   		'boot-volume-backup' = $bootvolbackup.data
       }
   	
   $output.'Boot-volume-backup' | select @{l="vmname";e={$output.IN}}, "Display-name", @{l="Volume-id";e={$_.'image-id'}}, 'size-in-gbs', 'unique-size-in-gbs', 'time-created', 'expiration-time','lifecycle-state',  @{l='Backuptype';e={"boot-volume-backup"}}
   $output.'Block-volume-backup'| select @{l="vmname";e={$output.IN}}, @{l="Display-name";e={$_.devname}}, 'Volume-id', 'size-in-gbs', 'unique-size-in-gbs', 'time-created', 'expiration-time', 'lifecycle-state', @{l='Backuptype';e={"block-volume-backup"}}
      

  }

$total = $serverocids.count
##====Initiating the jobs====##
$serverocids | foreach-object{
 $ocid = $_.id
 
$job = Start-job -ScriptBlock $scriptblock -ArgumentList $ocid,$profile
$job | export-csv tempjoblist.csv -append

$srvcount = $srvcount + 1
$progress = ($srvcount/$total)*100
$progress1 = [math]::round($progress,1)
Write-Progress -id 1 -Activity "Progress - >" -Status "$progress1 % Complete:" -PercentComplete $progress -CurrentOperation "Created Job  $srvcount of $total : $ocid"

$jobs = import-csv tempjoblist.csv
 $activejob = $jobs |%{
  get-job -id $_.id |?{$_.State -eq "Running"}
 }
$jobcount = $activejob.count
 while ($jobcount -ge $MaxSimultaneousJobs) {
  $activejob = $jobs |%{
   get-job -id $_.id |?{$_.State -eq "Running"}
  }
  $jobcount = $activejob.count
  sleep 1
 }


}
Write-Progress -id 1 -Activity "Progress - >" -Status "$progress1 % Complete:" -PercentComplete $progress -CurrentOperation "Creating Job Completed"

 $progress = 0
 $completedjobs=0
##====jobs in progress====##
$jobs = import-csv tempjoblist.csv
 while ($watch -eq $false) {
  $check = $jobs|%{
   $jobid = $_.id
   get-job -id $_.id |?{$_.State -eq "Running"}
   $jbstat = (get-job -id $_.id).State
    if ($jbstat -eq "Completed") { 
     ##====recieving jobs=Pass1===##
     $joboutput = get-job -id $jobid|receive-job
    }
    if ($joboutput -ne $null){
     $joboutput|select vmname,'display-name','Volume-id','size-in-gbs','unique-size-in-gbs','time-created','expiration-time','lifecycle-state',Backuptype |export-csv $outputfile -notypeinformation -encoding utf8 -append
    }
   $joboutput = $null
  }
 
  $runningjobcount = $check.count
  
  if ($jobs.count -ne $null){
   $completedjobs = $jobs.count - $check.count
   $progress = ($completedjobs/$jobs.count)*100
   $progress1 = [math]::round($progress,1)
    if($runningjobcount -eq 1) {
     Write-Progress -id 2 -Activity "Progress - >" -Status "$progress1 % Complete:" -PercentComplete $progress -CurrentOperation "$runningjobcount Job in Progress"
    }else{
    Write-Progress -id 2 -Activity "Progress - >" -Status "$progress1 % Complete:" -PercentComplete $progress -CurrentOperation "$runningjobcount Jobs in Progress"
    }
  }
  else{
   $completedjobs = 1 - 1
   $progress = (0/1)*100
   $progress1 = [math]::round($progress,1)
   Write-Progress -id 2 -Activity "Progress - >" -Status "$progress1 % Complete:" -PercentComplete $progress -CurrentOperation "1 Job in Progress"
  }

  if ($check -eq $null) { 
   $watch = $true	
  }
 }

##====recieving jobs=Pass2===##
$jobs |%{
$jobid = $_.id
$jobstat = (get-job -id $jobid).State
if($jobstat -eq "Completed") {
 $joboutput = get-job -id $jobid|receive-job
 $joboutput |select vmname,'display-name','Volume-id','size-in-gbs','unique-size-in-gbs','time-created','expiration-time','lifecycle-state',Backuptype|export-csv $outputfile -notypeinformation -encoding utf8 -append
}

remove-job -id $jobid
}


##====cleanup====##
Remove-Item tempjoblist.csv

##=====Validate output===========##
$validateoutput = import-csv $Outputfile
$serverlist | %{
$srch = $_
$srchcount = $null
$srchcount = $validateoutput|?{$_.VMname -like "*$srch*"}
 if($srchcount -eq $null) {
  Write-host "No Backups found for $srch" -ForegroundColor 'red'
 }
}


##====Total time taken====##
$scriptendtime =  get-date
$exectime = [string]($scriptendtime-$scriptstarttime).Minutes + " Minutes " + [string]($scriptendtime-$scriptstarttime).seconds + " Seconds"
write-host "Total Script execution time: $exectime" -ForegroundColor Cyan
