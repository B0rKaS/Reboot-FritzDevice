<#
.SYNOPSIS
	Reboots  FRITZ! devices
.DESCRIPTION
	This PowerShell script reboots different FRITZ! devices in the Local Area Network (LAN)
	(Options: 1: Router, 2: Repeater, 3: Router & Repeater, 4: Custom FQDN)
.PARAMETER option
	Specifies device to be rebooted
.PARAMETER customFQDN
	To be used for option 4 to predefine the customFQDN
.EXAMPLES
	PS> ./reboot-fritzdevice -option 1
	PS> ./reboot-fritzdevice -option 4 -customFQDN fritz.repeater2
.NOTES
	Author: B0rKaS / License: CC0
#>

param([string]$option, [string]$customFQDN)

# PARAMETERS --------------------------

$winCredStoreName = "fritz"
$FQDN_FritzBox = "fritz.box"
$FQDN_FritzRepeater = "fritz.repeater"

# -------------------------------------

Write-Host "Info: This script reboots specific FRITZ! Devices automatically (if you want to abort it, press CTRL+C)"

$validInput = $false
do {
    if(!$option) {
        Write-Host "`nWhich FRITZ! Device you want to reboot?`n`n1: Router (FQDN: $FQDN_FritzBox)`n2: Repeater (FQDN: $FQDN_FritzRepeater)`n3: Router & Repeater  (FQDNs: $FQDN_FritzBox, $FQDN_FritzRepeater)`n4: Custom (insert a custom FQDN)"
        Write-Host "`nChoose (1-4): " -NoNewline 
        $action = Read-Host
    } else {
        if($option -ge 1 -and $option -le 4) {
            $action = $option
        }
    }

    switch ($action) {
        1 {
            $targetFQDN = $FQDN_FritzBox
            $validInput = $true
        }
        2 {
            $targetFQDN = $FQDN_FritzRepeater
            $validInput = $true
        }
        3 {
            $targetFQDN = @($FQDN_FritzBox, $FQDN_FritzRepeater)
            $validInput = $true
        }
        4 {
            if($customFQDN) {
                $targetFQDN = $customFQDN
            } else {
                Write-Host "`nInsert custom FQDN (without protocol, like 'fritz.box'): " -NoNewline
                $targetFQDN = Read-Host
            }
            $validInput = $true
        }
        default {
            Write-Host "`nNo match found, please choose between 1 - 4... (or leave with CTRL+C)`n" -ForegroundColor Red
        }
    }
} while(!$validInput)

try{
    Write-Host "`nChecking if module 'CredentialManager' is already installed" -ForegroundColor Yellow
    $credModule = Find-Module CredentialManager -ErrorAction SilentlyContinue

    if($credModule) {
        Write-Host "Found module 'CredentialManager'" -ForegroundColor Green
    } else {
        Write-Host "Didn't found module 'CredentialManager' - installing..." -ForegroundColor Red
        Install-Module CredentialManager -Scope CurrentUser
    }

    $cred = Get-StoredCredential -Target $winCredStoreName
} catch {Write-Host $PSItem.Exception}

if($cred) {
    Write-Host "`nGot credentials from credential-store '$winCredStoreName'" -ForegroundColor Green
} else {
    Write-Host "No stored credentials found. " -ForegroundColor Yellow
    Write-Host "`nPlease insert administrative credentials for your FRITZ! Devices"
    Write-Host "`nUsername: " -NoNewline
    $username = Read-Host
    
    Write-Host "Password: " -NoNewline
    $password = Read-Host -AsSecureString

    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
}

foreach($FQDN in $targetFQDN){
    try {
        $headers = @{}
        $headers.Add("Content-Type","text/xml; charset='utf-8'")
        $headers.Add("SoapAction", "urn:dslforum-org:service:DeviceConfig:1#Reboot")

        Write-Host "`nSending reboot-call to FRITZ! Device (FQDN: $($FQDN))..." -ForegroundColor Cyan
        $response = Invoke-WebRequest -Method Post -Uri "http://$($FQDN):49000/upnp/control/deviceconfig" -Headers $headers -Credential $cred -UseBasicParsing -Body "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:Reboot xmlns:u='urn:dslforum-org:service:DeviceConfig:1'></u:Reboot></s:Body></s:Envelope>"
        
        if($response.StatusCode -eq 200) {
            Write-Host "`nSuccess! Device ($FQDN) should reboot now...`n(this action takes like 2-5 minutes until the device is available again)" -ForegroundColor Green
        } else {
            Write-Host "`nSomething went wrong! Device ($FQDN) responded:`n$response" -ForegroundColor Red
        }
    } catch {
        Write-Host "`n"$PSItem.Exception -ForegroundColor Red
    }
}

if(!$option -or ($response.StatusCode -ne 200) -or ($username -and $password)) {
    Write-Host "`nPress any key to leave script..."
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
