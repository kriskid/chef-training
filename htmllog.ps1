<# 
.SYNOPSIS
Convert any csv to an html file with table.
.DESCRIPTION

.PARAMETER inputfile
Provide a file name in current directory same as the script or full path of a file name containing a list of OCID's. The default is .\serverocids.txt

.PARAMETER Outputfile
Provide a file name in current directory same as the script or full path of a file name containing a list of OCID's. the default is output-info.csv

.INPUTS
The defaut input file is named serverocids.txt which can be populated with the OCI ID of the compute instance for whcih backup inforation needs to be checked.

.OUTPUTS
The defaut output file is named output-info.csv and will be located in the same path as the script is kept and executed from.

.EXAMPLE


.NOTES
	Author: Krishna Kumar
    Change Log:
    Version 1.0
    2-Mar-2021 : 

.LINK
    
    
#>


Param(
      [Parameter(Mandatory=$True)] [string]$inputfile=".\inputfile.csv",
      [Parameter(Mandatory=$false)] [String]$Outputfile=".\htmlout.html"
  )


#$x = import-csv .\InstallUpdateslog.csv
$input = import-csv $inputfile


#$outputfile = ".\htmlout.html"

$htmlstart = @"
<!DOCTYPE html>
<html>
<head>
<style>
* {
  box-sizing: border-box;
}

#myInput {

  
  background-position: 10px 10px;
  background-repeat: no-repeat;
  width: 20%;
  font-size: 16px;
  padding: 12px 20px 12px 40px;
  border: 1px solid #ddd;
  margin-bottom: 12px;
}

#myTable {
  border-collapse: collapse;
  width: 100%;
  border: 1px solid #ddd;
  font-size: 18px;
}

#myTable th {
background-color: #007395;
color: #ffffff;
  text-align: left;
  padding: 12px;
  border: 1px solid black
}

#myTable td {
    
  text-align: left;
  padding: 12px;
  border: 1px solid black
}


#myTable tr {
  border-bottom: 1px solid #ddd;
}

/*#myTable tr.header, #myTable tr:hover {
  background-color: #f1f1f1;
}*/

</style>
</head>
<body>
<input type="text" id="myInput" onkeyup="myFunction()" placeholder="Filter by serverName." title="Type in server name.">
"@

$table = '<table id="myTable">'

$fields = $input |select -first 1 |%{
foreach ($property in $_.PSObject.Properties) 
{         
$property.Name
}
}
#"count of Fields = $($fields.count)" 

#comment: ----- Header row from csv.
$input |select -first 1|%{
$table += '<tr>'
foreach ($property in $_.PSObject.Properties) 
{         
#$property.Name
$table += "<th>$($property.Name)</th>"
}
$table += '</tr>'
}

#comment: ---- each row into table row
$count=1
$input|%{
if($_.EventType -eq "error") {$table += "<tr style='background-color: #ff5000; color: #ffffff'> `n`r"}else{
$table += "<tr> `n`r"
}
:inner
foreach ($property in $_.PSObject.Properties) 
{         
$table += "<td>$($property.Value)</td> `n`r"
if ($count%$fields.Count -eq 0){
$count++
break inner
}
$count++
}
$table += "</tr> `n`r"
}


$htmlend = @"
</table> 
<script>
function myFunction() {
  var input, filter, table, tr, td, i, txtValue;
  input = document.getElementById("myInput");
  filter = input.value.toUpperCase();
  table = document.getElementById("myTable");
  tr = table.getElementsByTagName("tr");
  for (i = 0; i < tr.length; i++) {
    td = tr[i].getElementsByTagName("td")[0];
    if (td) {
      txtValue = td.textContent || td.innerText;
      if (txtValue.toUpperCase().indexOf(filter) > -1) {
        tr[i].style.display = "";
      } else {
        tr[i].style.display = "none";
      }
    }       
  }
}
</script>

</body>
</html>
"@

$htmlstart | out-file $outputfile
$table |out-file $outputfile -Append
$htmlend | out-file $outputfile -Append
