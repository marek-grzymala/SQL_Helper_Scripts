# Set Static Variable Values:
$SQLService = "SQL Server (Inst1)"; # Replace <SQL Server (Inst1)> with your SQLService Name as shown in DisplayName by ps command: Get-Service -name *SQL*
$IpAll_StaticTcpPort = "51433"      # Replace with Static TCP Port Number of your choice for regular TCP Client Connections
$DAC_StaticTcpPort = "51434"        # Replace with Static TCP Port Number of your choice for Dedicated Admin Connection


function Test-RegistryValue {
    param (
    
            [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]$Path,
    
            [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]$Value
    )
    
    try {
            Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
            return $true
        }
    catch {return $false}
}


# Get SQL Server Instance Path:
$SQLInstancePath = "";

$SQLServiceName = ((Get-Service | WHERE { $_.DisplayName -eq $SQLService }).Name).Trim();
If ($SQLServiceName.contains("`$")) { $SQLServiceName = $SQLServiceName.SubString($SQLServiceName.IndexOf("`$")+1,$SQLServiceName.Length-$SQLServiceName.IndexOf("`$")-1) }
foreach ($i in (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server").InstalledInstances)
{
  If ( ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").$i).contains($SQLServiceName) )
  { $SQLInstancePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"+`
  (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").$i}
}
# $SQLInstancePath


##################################################################################################################################################
# IPAll Section:
##################################################################################################################################################

$SQLTcpPath = "$SQLInstancePath\MSSQLServer\SuperSocketNetLib\Tcp"
Write-Host 'Entries in Path: '$SQLTcpPath " (before applying changes):"

Get-ChildItem $SQLTcpPath | ForEach-Object {Get-ItemProperty $_.pspath} `
| Format-Table -Autosize -Property @{N='IPProtocol';E={$_.PSChildName}}, Enabled, Active, TcpPort, TcpDynamicPorts, IpAddress


Set-ItemProperty -Path "$SQLTcpPath" -Name "Enabled" -Value "1"
Set-ItemProperty -Path "$SQLTcpPath" -Name "ListenOnAllIPs" -Value "1"

# TcpDynamicPorts has to be set to empty string if you want IPAll to listen remotely on static $IpAll_StaticTcpPort:
Set-ItemProperty -Path "$SQLTcpPath\IPALL" -Name "TcpDynamicPorts" -Value ""
Set-ItemProperty -Path "$SQLTcpPath\IPALL" -Name "TcpPort" -Value $IpAll_StaticTcpPort

If (Test-RegistryValue -Path "$SQLTcpPath\IPALL" -Value "IPV6Supported") {
    Write-Host "Setting the IPV6Supported to 0: "
    Set-ItemProperty -Path "$SQLTcpPath\IPALL" -Name "IPV6Supported" -Value 0
}
Else {
    Write-Host "Creating and Setting the IPV6Supported to 0: "
    New-ItemProperty -Path "$SQLTcpPath\IPALL" -Name "IPV6Supported" -Value 0 -PropertyType DWord
}

Write-Host 'Entries in Path: '$SQLTcpPath " (after applying changes, if any):"

Get-ChildItem $SQLTcpPath | ForEach-Object {Get-ItemProperty $_.pspath} `
| Format-Table -Autosize -Property @{N='IPProtocol';E={$_.PSChildName}}, Enabled, Active, TcpPort, TcpDynamicPorts, IpAddress


##################################################################################################################################################
# DAC Section:
##################################################################################################################################################

$DACPath = "$SQLInstancePath\MSSQLServer\SuperSocketNetLib\AdminConnection\Tcp"
Write-Host 'Entries in DAC Path: '$DACPath " (before applying changes):"
Get-ItemProperty -Path $DACPath

Set-ItemProperty -Path "$DACPath" -Name "Enabled" -Value "1"
Set-ItemProperty -Path "$DACPath" -Name "ListenOnAllIPs" -Value "1"

# You can set the static DAC TcpPort but SQL will completely ignore it and will read/overwrite (if needed) just the `TcpDynamicPorts` string value. 
# The logic being: unlike with regular client connections you can establish only one DAC connection, 
# and it's better to override DAC's port value at startup if necessary (hence Dynamic having priority) than to leave SQL without DAC whatsoever.

Set-ItemProperty -Path "$DACPath" -Name "TcpDynamicPorts" -Value $DAC_StaticTcpPort 
Set-ItemProperty -Path "$DACPath" -Name "TcpPort" -Value $DAC_StaticTcpPort


If (Test-RegistryValue -Path "$DACPath" -Value "IPV6Supported") {
    Write-Host "Setting the DAC IPV6Supported to 0: "
    Set-ItemProperty -Path "$DACPath" -Name "IPV6Supported" -Value 0
}
Else {
    Write-Host "Creating and Setting the DAC IPV6Supported to 0: "
    New-ItemProperty -Path "$DACPath" -Name "IPV6Supported" -Value 0 -PropertyType DWord
}

Write-Host 'Entries in DAC Path: '$DACPath " (after applying changes, if any):"
Get-ItemProperty -Path $DACPath