#!/usr/bin/pwsh
#
# This script will install all required Powershell modules for the jupyter notebooks run
#
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

echo "Cleaning up previously installed modules"
Get-InstalledModule -Name ImportExcel | Uninstall-Module
Get-InstalledModule -Name HP* | Uninstall-Module
# Uninstall doesn't manage deps so iterating
Get-InstalledModule -Name VMware.* | Uninstall-Module
Get-InstalledModule -Name VMware.* | Uninstall-Module
Get-InstalledModule -Name VMware.* | Uninstall-Module
Get-InstalledModule -Name VMware.* | Uninstall-Module
Get-InstalledModule -Name VMware.* | Uninstall-Module

rm -rf /usr/local/share/powershell/Modules/*
rm -rf $HOME/.local/share/powershell/Modules/*

echo "install excel"
Install-Module -Name ImportExcel
echo "install OneView"
Install-Module -Name HPOneView.520
Install-Module -Name HPEOneView.530
Install-Module -Name HPEOneView.540
Install-Module -Name HPEOneView.550

echo "Make these modules accessible for all users"
mv $HOME/.local/share/powershell/Modules/* /opt/microsoft/powershell/Modules/7/

echo "install vmware powercli"
Install-Module -Name VMware.PowerCLI
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings $false -Scope User -Confirm:$false
