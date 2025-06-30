Param ( [Array]$OVApplianceIP                  = @(),
        [String]$OneViewModule                  = "HPEOneView.540",
        [String]$StudentRange                   = "171-180",
        [String]$Out                            = "variables_WKSHP-OneView.yml"
)

$server_names = "Synergy-Encl-1, bay 5",
                "Synergy-Encl-2, bay 5",
                "Synergy-Encl-1, bay 9",
                "Synergy-Encl-2, bay 1",
                "Synergy-Encl-1, bay 12",
                "Synergy-Encl-2, bay 2",
                "Synergy-Encl-1, bay 11",
                "Synergy-Encl-2, bay 3",
                "Synergy-Encl-1, bay 4",
                "Synergy-Encl-2, bay 4"

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}


if (-not (Get-Module $OneViewModule))
{
    Import-Module -Name $OneViewModule
}

if ($ConnectedSessions) {
    Write-Error "Please run this script without any pre-established OneView connection, exiting..."
    return
}
$password = ConvertTo-SecureString 'password' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('Administrator',$password)

$StudentRange | Select-String -Pattern "^(\d+)-(\d+)$" | ForEach-Object { $start, $end = $_.Matches[0].Groups[1..2].Value }
if ( ([int]$end - $start + 1) % 10 -ne 0 ) {
    Write-Error "Range $StudentRange does not contain a multiple of 10 students, exiting..."
    return
}

$appliances_required = ([int]$end - $start + 1) / 10
if ($appliances_required -ne $OVApplianceIP.Count) {
    $r = [int]$end - $start + 1
    $c = $OVApplianceIP.Count
    Write-Error "Range of $r students requires $appliances_required OneView instances but $c were supplied. Exiting..."
    return
}

$OVApplianceIP | ForEach-Object {
    try {
        Connect-OVMgmt -Hostname $_ -Credential $credential
    }
    catch {
        Write-Error $_
        exit
    }
}

"---" | Out-File $Out
"OVIP:" | Out-File $Out -Append
[int]$start .. [int]$end | ForEach-Object {
    $a = $OVApplianceIP[[int][Math]::Floor(($_ - $start)/20)]
    "      ${_}: $a" | Out-File $Out -Append
}

"SRVNAME:" | Out-File $Out -Append
[int]$start .. [int]$end | ForEach-Object {
    $srvname = $server_names[($_ - [int]$start) % 20]
    "      ${_}: $srvname" | Out-File $Out -Append
}

"SHT:" | Out-File $Out -Append
$templates = @("") * ([int]$end - $start + 1)
[int]$start .. [int]$end | ForEach-Object {
    $a = $ConnectedSessions[[int][Math]::Floor(($_ - $start)/20)]
    $i = $_ - [int]$start
    $m = $i % 20
    $srvname = $server_names[$m]
    try {
        $sht = send-ovrequest -Hostname $a -uri (Get-OVServer -ApplianceConnection $a -name $srvname | Select-Object -ExpandProperty serverHardwareTypeUri) | Select-Object -expandproperty name
    }
    catch {
        Write-Error $_
        exit
    }
    $sht | Select-String -Pattern "^SY (.+)" | ForEach-Object { $templates[$i] = $_.Matches[0].Groups[1].Value }
    "      ${_}: $sht" | Out-File $Out -Append
}

"SPTNAME:" | Out-File $Out -Append
[int]$start .. [int]$end | ForEach-Object {
    $tmpl = $templates[$_ - [int]$start]
    "      ${_}: Template for $tmpl" | Out-File $Out -Append
}

$ConnectedSessions | Disconnect-OVMgmt 
