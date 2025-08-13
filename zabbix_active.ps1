$service = Get-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue
if($service -ne $null)
{
    exit
}

# Check if the script is running as Administrator
function Test-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If the script is not running as Administrator, prompt to run as Admin
if (-not (Test-Admin)) {
    Write-Host "This script needs to be run as Administrator!"
    $choice = Read-Host "Do you want to run this script as Administrator? (Y/N)"
    if ($choice -eq 'Y') {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $($MyInvocation.MyCommand.Path)" -Verb RunAs
        exit
    } else {
        Write-Host "Exiting script."
        exit
    }
}

# Create a function to change colors in PowerShell
function Color-Console {
	$Host.ui.rawui.backgroundcolor = "White"
	$Host.ui.rawui.foregroundcolor = "Blue"
	$hosttime = (Get-ChildItem -Path  $PSHOME\\PowerShell.exe).CreationTime
	$Host.UI.RawUI.WindowTitle  =  "PowerShell ($hosttime)"
	Clear-Host
}
 
# Calls the Color-Console function
Color-Console


$eus = "
                                     :::...::::.::::...::::..:::::..::::::.::..:...                 
                                    .:::.::....:.:.....:...:.::::..:.::...:::.::::.:::.             
                                  ..:::                   :.:::.:.                 .:::::.:         
                                  :.:.                 ...::.                          ..:.::       
                                ::::                  .::..        ..:.:::::.:..:        .:.:..     
                    ::.::::::::.:::                 .::..       ..:::.::::::..:.::::       :::..    
                    .:.::::::::..::                .::::      .:.::.            .:::.:       ...:   
                   .::.        ..:.:              ::::      :.:.::                 ::..:      :.:.  
                  :.::           .:..            .::.      ...:                      ::::      :..: 
                 .:::             :::::          .:..     :.:.                        ::::     ..:.:
                 ::.               .:.::        .:.:     :.:.                          .:::     .:.:
                .:::                 :.:::::::::::::::::::::::::::::::::::::::::::::::::::.      .::
               :..:                   ::.:::::::::..............................::::.::.::       ::.
:::::::.::::....::                             .:::                                              .:.
:::::::::::::::::.                             ::::      :....:................................:..::
              ..::.                            ::::     ::::::::::::::::::::::::::::::::::::::::::::
               :...                            :.::      :::                                        
                :::.                           ::::      ::.                                        
                 :::                 ..:::::::::::::::::::::::::::::::::::::::::::::::::::.:::      
                 ..:.              .:...        :::..     ..::.                        :.:.:::::..  
                  :.:.            :::.:          ..::      .:::.                      .::..  .::.:::
                  ..:.:          ::..             .::.      .:::::                  .::::      ...:.
                   ..:.::..:.::..:::               :.::.      ..::::..          :::::.:       .::.. 
                    ::::::::::::::.                  .:.:        ..::.::::::::::::::.       ..:.:   
                               :::::                  .:.::          ....::::.:.          ::::::    
                                 .:..                   :.:::.                         .:.:::       
                                  .:...                    .:.::..                 :.::.::.         
                                    ::..:.:.:::.....::::::::::.::::.::::.:::.:.:.:::....            
                                     ..:::::::::::::::::::::::::::::::::::::::.:::.                 
                                                                                                    
                                                                                                    
                                                                                                    
                                         ..:            .::                                         
              .:::::::::::               ..:            .::            ::.                          
                     .::::               ..:            .::            .:.                          
                     :..                 ..:            .::                                         
                    .::       .:::..:    ..:.::.::.     .::.:..::.     :.:  ::::    :.:             
                  :..:       ...:.:..:   ..:..:::.:::   ......:.:.:.   ..:   ::.: .:.:              
                 :...              ..::  ..:.     .::   .:.      :.:   ..:     .::.:.               
                :.:.        .::..::..:.  ..:       :::  ...      :::.  ..:      .:.                 
               ::::        :.:.    :::.  ..:.     ::.   ..:.     .:.   ..:    :::::.:               
              .:::........  :..:  ::.:.  ...::: ....:   .:.:.. .:..    ..:   ....  .:.              
             .............   ...:..:.:   :..::::.::     ::....:::.     :..  :::.    ..:             
                                                                                                    "

Write-Output $eus
# Now proceed with your original script if it is running as Admin
$TempPath = $env:Temp
$zabbixPath = Join-Path -Path $TempPath -ChildPath "zabbix"
Set-Location $TempPath

# Check if the 'zabbix' folder exists and handle it
if (-not (Test-Path -Path $zabbixPath)) {
    New-Item -ItemType Directory -Path $zabbixPath | Out-Null
    Write-Host "Cartella creata."
} else {
    Remove-Item -Path $zabbixPath -Recurse -Force
    New-Item -ItemType Directory -Path $zabbixPath | Out-Null
    Write-Host "Cartella già esistente, rimossa e ricreata."
}

# Change directory to 'zabbix'
Set-Location $zabbixPath
$ProgressPreference = 'SilentlyContinue'

$LatestVersion = (Invoke-RestMethod -Uri "https://services.zabbix.com/updates/v1").versions |
    Where-Object { $_.version -eq "7.0" } |
    Select-Object -ExpandProperty latest_release |
    Select-Object -ExpandProperty release

# Download the installer (using the link you selected)

$url = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$($LatestVersion)/zabbix_agent2-$($LatestVersion)-windows-amd64-openssl.msi"

# Download
wget -UseBasicParsing $url -OutFile "installer.msi"
Write-Host "Installer scaricato."
# Install the MSI package silently
Write-Host "Installazione avviata."
Start-Process -FilePath msiexec.exe -ArgumentList '/l*v','C:\package.log','/i','installer.msi','/qn','SERVER=EUSZBX01,EUSPROXY01,195.65.61.109,195.65.61.168','SERVERACTIVE=SERVER=EUSZBX01,EUSPROXY01,195.65.61.109:10051,195.65.61.168:10051','HOSTNAMEITEM=system.hostname' -Wait
Write-Host "Installazione completata."
# Go back to the previous directory
Set-Location ..

# Remove the 'zabbix' folder after installation (optional)
Remove-Item -Path $zabbixPath -Recurse -Force
Write-Host "Rimossi file temporanei."
Write-Host "Attesa del servizio."
Start-Sleep -Seconds 4
Start-Process -FilePath "sc.exe" -ArgumentList 'failure "Zabbix Agent 2" reset= 0 actions= restart/60000/restart/60000/restart/60000'
Restart-Service -Name "Zabbix Agent 2"
Write-Host "Riavvio automatico processo impostato."
Write-Host "Operazione completata. La finestra si chiuderà tra 4 secondi."
Start-Sleep -Seconds 4
exit
