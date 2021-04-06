param(
[Parameter(mandatory=$True)] [string]$adminserver,
[Parameter(mandatory=$True)] [string]$adcomputer
)


$cred = Get-Credential $env:userdomain\$env:username 

Invoke-Command -ComputerName Serverwithadmintools -usessl -Credential $cred -ScriptBlock {param($cred1)
get-adcomputer PCNAMEHERE -properties * -credential $($cred1)
} -ArgumentList $cred