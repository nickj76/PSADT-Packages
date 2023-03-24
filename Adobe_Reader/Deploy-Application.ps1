<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Adobe'
    [String]$appName = 'Acrobat Reader DC'
    [String]$appVersion = '2022.001.20169'
    [String]$appArch = 'x64'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '13/02/2023'
    [String]$appScriptAuthor = 'Nick Jenkins'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.2'
    [String]$deployAppScriptDate = '02/02/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'acrobat,acrocef,acrodist,acrotray,adobe audition cc,adobe cef helper,adobe desktop service,adobe qt32 server,adobearm,adobecollabsync,adobegcclient,adobeipcbroker,adobeupdateservice,afterfx,agsservice,animate,armsvc,cclibrary,ccxprocess,cephtmlengine,coresync,creative cloud,dynamiclinkmanager,illustrator,indesign,node,pdapp,photoshop,firefox,chrome,excel,groove,iexplore,infopath,lync,onedrive,onenote,onenotem,outlook,mspub,powerpnt,winword,winproj,visio' -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>
        ## This essentially replaces the functionality of Creative Cloud Packager. It even uses the same xml file as Creative Cloud Packager to perform the uninstall.
		$applicationList = 'Acrobat'
		ForEach($installedApplication in $applicationList) {
			$installedApplicationList = Get-InstalledApplication -Name $installedApplication
			ForEach($application in $installedApplicationList) {
				$application
				if($application.UninstallString) {
					Write-Log -Message "Uninstall string: $($application.UninstallString)" -Source 'Pre-Installation' -LogType 'CMTrace'
					Write-Log -Message "Uninstall subkey: $($application.UninstallSubkey)" -Source 'Pre-Installation' -LogType 'CMTrace'
					## First, we want to check if the program was installed with a package. If it was, then we simply run the MSI uninstaller.
					if($application.UninstallString.contains("MsiExec.exe") -and ($application.UninstallSubkey)) {						$uninstallerParameters
						## You might get exit code 1603 if the packaged apps were uninstalled without using the MSI uninstaller.
						## The MSI uninstaller will try to run, see that there are no apps to uninstall, and fail with exit code 1603.
						## The only way to remove the package is to reinstall the package and then uninstall it with the MSI uninstaller.
						## You might also be able to do a manual cleanup of leftover files, directories, and or reg keys.
						Write-Log -Message "Attempting to run uninstaller..." -Source 'Pre-Installation' -LogType 'CMTrace'
						$exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/x$($application.UninstallSubkey) /q" -WindowStyle "Hidden"-IgnoreExitCodes '1603' -PassThru
						If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
					}
					## If the application wasn't installed with a package, we'll to check to see if it uses the standard Adobe uninstaller. If it does, we're in luck.
					## Unfortunately, we can't run it as is because the standard Adobe uninstaller requires user interaction. However, it does give us everything we need to do a silent uninstall.
					## The full uninstall string provided by Get-InstalledApplication will look something like this:
					## C:\Program Files (x86)\Common Files\Adobe\Adobe Desktop Common\HDBox\Uninstaller.exe" --uninstall=1 --sapCode=ILST --productVersion=26.3.1 --productPlatform=win64 --productAdobeCode={ILST-26.3.1-64-ADBEADBEADBEADBEADBEA} --productName="Illustrator" --mode=0
					## First, we separate out the options into individual strings using split and then remove everything except the value using trim.
					ElseIf($application.UninstallString.contains("${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Uninstaller.exe")) {
						$substringArray = $application.UninstallString -split " --"
						ForEach($item in $substringArray) {
							if($item.contains("sapCode=")) {
								$sapCode = $item.trim("sapCode=")
							}
							elseif($item.contains("productVersion=")) {
								$productVersion = $item.trim("productVersion=")
								$pointValues = $productVersion.split('.')
								$baseVersion = $pointValues[0]
							}
							elseif($item.contains("productPlatform=")) {
								$productPlatform = $item.trim("productPlatform=")
							}
						}
						## This next part is a little messy. We can't just pass the $productVersion into the uninstaller below because the uninstaller is expecting the base version of the application so it knows what to uninstall.
						## To get around that, we have to compare the installed version against a list of base versions that Adobe provides as an xml file.
						## If you look above, you'll see that we take our $productVersion and pare it down to $baseVersion. In other words, 25.4.6 becomes 25.
						## Unfortunately, we can't pass that directly, because the base version could be 25.0 or even 25.0.0. So now, we compare our 25 to the product version contained in our xml file.
						## Conceivably, you could get 13.0.25 instead of 25.0.0, so we want to make sure that 25 shows up at the beginning of the version number. We perform a wildcard comparision  using * to see if 25 matches 25.0 in the XML file.
						[xml]$xmlAdobeCCUninstallerConfig = Get-Content -Path "$dirFiles\AdobeCCUninstallerConfig.xml"
						$xmlAdobeCCUninstallerConfig.CCPUninstallXML.UninstallInfo.RIBS.Products.Product | Where-Object {$_.SapCode -eq $sapCode -and $_.Version -like "$baseVersion*"} |  ForEach-Object {
							Write-Log -Message "$($_.SapCode), $($_.Version)" -Source 'Pre-Installation' -LogType 'CMTrace'
							If ( Test-Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe") {
								$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe" -Parameters "--uninstall=1 --sapCode=$($_.SapCode) --baseVersion=$($_.Version) --platform=$($_.Platform) --deleteUserPreferences=false" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
								If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
							}
						}
						$xmlAdobeCCUninstallerConfig.CCPUninstallXML.UninstallInfo.HD.Products.Product | Where-Object {$_.SapCode -eq $sapCode -and $_.BaseVersion -like "$baseVersion*"} |  ForEach-Object {
							Write-Log -Message "$($_.SapCode), $($_.BaseVersion)" -Source 'Pre-Installation' -LogType 'CMTrace'
							If ( Test-Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe") {
								$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Common Files\Adobe\Adobe Desktop Common\HDBox\Setup.exe" -Parameters "--uninstall=1 --sapCode=$($_.SapCode) --baseVersion=$($_.BaseVersion) --platform=$($_.Platform) --deleteUserPreferences=false" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
								If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
							}
						}
					}
					ElseIf($application.UninstallString.contains("${Env:ProgramFiles(x86)}\Adobe\Adobe Creative Cloud\Utils\Creative Cloud Uninstaller.exe")) {
						Write-Log -Message "Attempting to run uninstaller..." -Source 'Pre-Installation' -LogType 'CMTrace'
						Write-Log -Message "Note: Creative Cloud can not be uninstalled if there are Creative Cloud applications installed that require it." -Source 'Pre-Installation' -LogType 'CMTrace'
						$exitCode = Execute-Process -Path "${Env:ProgramFiles(x86)}\Adobe\Adobe Creative Cloud\Utils\Creative Cloud Uninstaller.exe" -Parameters "-u" -WindowStyle "Hidden" -PassThru
						If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
					}
					Else {
						Write-Log -Message "The uninstall string returned was not expected." -Source 'Pre-Installation' -LogType 'CMTrace'
					}
				}
				Else {
					Write-Log -Message "A program was detected but a valid uninstall string and or subkey could not be found." -Source 'Pre-Installation' -LogType 'CMTrace'

				}
			}
		}

		## This is the old way of doing it. Adobe is no longer continuing development and maintenance of Creative Cloud Packager and
		## recommends that you do not continue using Creative Cloud Packager to uninstall Creative Cloud apps.
		<#
		Remove-File -Path "$envCommonProgramFilesX86\Adobe\OOBE\PDApp\*" -Recurse -ContinueOnError $true
		If (-not ($envOSVersion -like "10.0*")) {
			Install-MSUpdates -Directory "$dirSupportFiles\$envOSVersionMajor.$envOSVersionMinor"
		}
				$exitCode = Execute-Process -Path "$dirSupportFiles\Uninstall\AdobeCCUninstaller.exe" -WindowStyle "Hidden" -IgnoreExitCodes '33,135' -PassThru
				If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
		#>

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>
        #Set Registry Keys for current user
		Set-RegistryKey -Key 'HKCU\SOFTWARE\Adobe\Adobe Acrobat\DC\Accessibility' -Name 'iWizardRun' -Value 1 -Type DWord
		Set-RegistryKey -Key 'HKCU\SOFTWARE\Adobe\Adobe Acrobat\DC\AVAlert\cCheckbox' -Name 'iAppDoNotTakePDFOwnershipAtLaunchWin10' -Value 1 -Type DWord
		Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown' -Name 'bAcroSuppressUpsell' -Value 1 -Type DWord
		Set-RegistryKey -Key 'HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown' -Name 'bToggleFTE' -Value 1 -Type DWord


		# Set registry keys for all users
		 $suppressAccessibility = 'Acrobat-Suppress-Accessibility-62CF0597','reg add "HKCU\SOFTWARE\Adobe\Adobe Acrobat\DC\Accessibility" /v iWizardRun /t REG_DWORD /d 1 /f'
		 $suppressDefaultPDF = 'Acrobat-Suppress-Default-PDF-62CF0597','reg add "HKCU\SOFTWARE\Adobe\Adobe Acrobat\DC\AVAlert\cCheckbox" /v iAppDoNotTakePDFOwnershipAtLaunchWin10 /t REG_DWORD /d 1 /f'
		 $suppressBlueButton = 'Acrobat-Suppress-Blue-Button-62CF0597','reg add "HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown" /v bAcroSuppressUpsell /t REG_DWORD /d 1 /f'
		 $suppressWelcomeScreen = 'Acrobat-Suppress-Welcome-Screen-62CF0597','reg add "HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown" /v bToggleFTE /t REG_DWORD /d 1 /f'
		 $ActiveSetupValues = $suppressAccessibility,$suppressDefaultPDF,$suppressBlueButton,$suppressWelcomeScreen
		 ForEach ($ActiveSetupValue in $ActiveSetupValues) {
            $regKey = $ActiveSetupValue[0]
            $ActiveSetupRegParentPath = 'HKLM:\Software\Microsoft\Active Setup\Installed Components'
            $ActiveSetupRegPath = "HKLM:\Software\Microsoft\Active Setup\Installed Components\$regKey"
			If(-Not(Test-Path -Path $ActiveSetupRegPath)){
				New-Item -Path $ActiveSetupRegParentPath -Name $regKey -Force | Out-Null
			}
			Set-ItemProperty -Path $ActiveSetupRegPath -Name '(Default)' -Value 'Users Settings for Adobe' -Force
			Set-ItemProperty -Path $ActiveSetupRegPath -Name 'Version' -Value '1' -Force
			Set-ItemProperty -Path $ActiveSetupRegPath -Name 'StubPath' -Value $ActiveSetupValue[1] -Force
		}


		Get-InstalledApplication -Name 'Adobe'
		$exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/i $dirFiles\AcroPro.msi EULA_ACCEPT=YES DISABLEDESKTOPSHORTCUT=1 /qn" -WindowStyle "Hidden" -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }

		$exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/p $dirFiles\AcroRdrDCx64Upd2200120169_MUI.msp /qn" -WindowStyle "Hidden" -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        $ProcessActive = Get-Process explorer -ErrorAction SilentlyContinue
        if(!$ProcessActive){
            Execute-ProcessAsUser -Path "$envSystemRoot\explorer.exe"
            Write-Log "Restarting Explorer"
        }
        Else{
            Write-Log "No restart of explorer needed"
        }


        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {}
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'acrobat,acrocef,acrodist,acrotray,adobe audition cc,adobe cef helper,adobe desktop service,adobe qt32 server,adobearm,adobecollabsync,adobegcclient,adobeipcbroker,adobeupdateservice,afterfx,agsservice,animate,armsvc,cclibrary,ccxprocess,cephtmlengine,coresync,creative cloud,dynamiclinkmanager,illustrator,indesign,node,pdapp,photoshop,firefox,chrome,excel,groove,iexplore,infopath,lync,onedrive,onenote,onenotem,outlook,mspub,powerpnt,winword,winproj,visio' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>
        $exitCode = Execute-Process -Path "MsiExec.exe" -Parameters "/x {AC76BA86-1033-FF00-7760-BC15014EA700} /qn" -WindowStyle "Hidden" -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>
        If(Test-Path -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Accessibility-62CF0597"){
			Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Accessibility-62CF0597" -Force
		}
		If(Test-Path -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Default-PDF-62CF0597"){
			Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Default-PDF-62CF0597" -Force
		}
		If(Test-Path -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Blue-Button-62CF0597"){
			Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Blue-Button-62CF0597" -Force
		}
		If(Test-Path -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Welcome-Screen-62CF0597"){
			Remove-Item -Path "HKLM:\Software\Microsoft\Active Setup\Installed Components\Acrobat-Suppress-Welcome-Screen-62CF0597" -Force
		}


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
