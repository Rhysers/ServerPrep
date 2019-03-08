
Write-Host "Install DC Step 1: Install-DC
Install DC Step 2: DC-Promo -DomainName <domain.com> [-AddDC]
Install Exchange Step 1: Install-ExchPreReq -Directory <C:\ExchFiles>
Install Exchange Setp 2 (once per domain): Prepare-Exchange -Directory <C:\ExchFiles>
Install Exchange Step 3: Install-Exchange -Directory <C:\ExchFiles>"

function Install-DC {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -IncludeAllSubFeature
}

function DC-Promo {
    param(
        [string][Parameter(Mandatory=$true,Position=0)]$DomainName,
        [switch]$AddDC
    )
    if($AddDC){
        #Add DC to existing Forrest
        $Creds = Get-Credential -Message "Enter Valid Crednetials to join the $DomainName Domain"
        Install-ADDSDomainController -DomainName $DomainName -Credential $Creds -InstallDNS
    }else{
        #Create New Forest
        Install-ADDSForest -DomainName $DomainName -InstallDNS
    }
}

function Install-ExchPreReq{
    param (
        [string][Parameter(Mandatory=$true, Position=0)][ValidateScript({test-path $_})]$Directory
    )
    Push-Location $Directory #Change Dir to the given Directory
    Get-ChildItem | ForEach-Object { Unblock-File $_ }
    $myProcess = Start-Process "(1st) NDP471-KB4033342-x86-x64-AllOS-ENU.exe" -PassThru -ArgumentList "/q","/norestart"
        $myProcess | Wait-Process
    write-host ".NET Framework Installed" -ForegroundColor Green
    $myProcess = Start-Process "(2nd)vcredist_x64.exe" -PassThru -ArgumentList "/passive","/norestart"
        $myProcess | Wait-Process
    Write-Host "Visiual C++ 2012 Installed" -ForegroundColor Green
    $myProcess = Start-Process "(3rd)vcredist_x64.exe" -PassThru -ArgumentList "/install","/passive","/norestart"
        $myProcess | Wait-Process
    Write-Host "Visiual C++ 2013 Installed" -ForegroundColor Green
    $myProcess = Start-Process "(4th)UcmaRuntimeSetup.exe" -PassThru -ArgumentList "/passive","/norestart"
        $myProcess | Wait-Process
    Write-Host "Unified Communications Managed API Installed" -ForegroundColor Green
    #Pop-Location #return to previous directory
    sleep 4
    Install-WindowsFeature NET-Framework-45-Features, Server-Media-Foundation, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS
    write-host "Installed Windows Features" -ForegroundColor Green
    Write-Host "Will Reboot in 8 Sec." -ForegroundColor Red -BackgroundColor Black
    sleep 8
    Restart-Computer
}

$SchemaPartition = (Get-ADRootDSE.NamingContexts | Where-Object ($_ -like "*Schema*"}
Test-Path "AD:CN=ms-Exch-Schema-Version-Pt,$SchemaPartition"

function Prepare-Exchange{
    param (
        [string][Parameter(Mandatory=$true, Position=0)][ValidateScript({test-path $_})]$Directory
    )
    Set-Location $Directory
    $mountResult = Mount-DiskImage C:\ExchFiles\ExchangeServer2016-x64-cu11.iso -PassThru
    $DriveLetter = ($mountResult | Get-Volume).DriveLetter
    $DriveLetter+=':\'
    Push-Location $DriveLetter
    $MyFile = $DriveLetter+"setup.exe"
    if (!(test-path C:\ExchFiles\SchemaPrepared.txt)){
        try{
            $myProcess = Start-Process $MyFile -ArgumentList "/IAcceptExchangeServerLicenseTerms","/PrepareSchema" -PassThru
                $myProcess | Wait-Process
            new-item "C:\ExchFiles\SchemaPrepared.txt" -ItemType File -Force
        }catch{
            Write-Warning "Something went terribly wrong preparing the schema, I hope you know what you are doing`n$_"
            return
        }
    }
    if (!(test-path C:\ExchFiles\ADPrepared.txt)){
        try{
            $myProcess = Start-Process $MyFile -ArgumentList '/IAcceptExchangeServerLicenseTerms','/PrepareAD','/OrganizationName:"ORGANIZATION"' -PassThru
                $myProcess | Wait-Process
            new-item "C:\ExchFiles\ADPrepared.txt" -ItemType File -Force
        }catch{
            Write-Warning "Something went terribly wrong preparing AD, I hope you know what you are doing`n$_"
            return
        }
    }
    if (!(Test-Path C:\ExchFiles\AllDomainsPrepared.txt)){
        try{
            $myProcess = Start-Process $MyFile -ArgumentList "/IAcceptExchangeServerLicenseTerms","/PrepareAllDomains" -PassThru
                $myProcess | Wait-Process
                new-item "C:\ExchFiles\AllDomainsPrepared.txt" -ItemType File -Force
        }catch{
            Write-Warning "Something went terribly wrong preparing AD, I hope you know what you are doing`n$_"
            return
        }
    }
    Pop-Location
    Write-host "Completed"
    sleep 8
    Restart-Computer
}

function Install-Exchange{
    param (
        [string][Parameter(Mandatory=$true, Position=0)][ValidateScript({test-path $_})]$Directory
    )
    set-Location $Directory
    $mountResult = Mount-DiskImage C:\ExchFiles\ExchangeServer2016-x64-cu11.iso -PassThru
    $DriveLetter = ($mountResult | Get-Volume).DriveLetter
    $DriveLetter+=':\'
    $MyFile = $DriveLetter+"setup.exe"
    Push-Location $DriveLetter
    $myProcess = Start-Process $myFile -ArgumentList "/IAcceptExchangeServerLicenseTerms","/Mode:Install","/Role:Mailbox" -PassThru
        $myProcess | Wait-Process
    #Restart-Computer
    Pop-Location
}

function Move-Database{
    param (
        [string]$DriveLetter1,
        [stting]$DriveLetter2
    )
    $DBs = Get-mailboxDatabase
    $i = 1
    foreach ($DB in $DBs){
        Set-MailboxDatabase -identity $DB.Name -Name "MBDB0"+$i
        Move-DatabasePath -Identity "MBDB0+$i" -force -EdbFilePath $DriveLetter1+"DB1\MBDB0"+$i+".edb" -LogFolderPath $DriveLetter2+"DB"+$i
    }
    New-SendConnector –Name Internet –AddressSpaces * -Internet –DNSRoutingEnabled $true
    Write-host "Renamed and moved Databases and created Send Connector for Internet"
}
