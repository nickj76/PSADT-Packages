<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
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
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Jetbrains'
	[string]$appName = 'PyCharm'
	[string]$appVersion = '2022.2'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '15/08/2022'
	[string]$appScriptAuthor = 'Nick Jenkins'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.4'
	[string]$deployAppScriptDate = '26/01/2021'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
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
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'PyCharm,PyCharm64' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		## Remove Any Existing Versions of PyCharm Community Edition 2022
		$AppList = Get-InstalledApplication -Name 'PyCharm Community Edition 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''        
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }
		## Remove Any Existing Versions of PyCharm Educational Edition 2022
        $AppList = Get-InstalledApplication -Name 'PyCharm Edu 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''       
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }
        ## Remove Any Existing Versions of PyCharm Professional Edition 2022
        $AppList = Get-InstalledApplication -Name 'PyCharm 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''       
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }
		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'
        $PyCharmCom = Get-ChildItem -Path "$dirFiles" -Include pycharm-community-2022*.exe -File -Recurse -ErrorAction SilentlyContinue
        $PyCharmEdu = Get-ChildItem -Path "$dirFiles" -Include pycharm-edu-2022*.exe -File -Recurse -ErrorAction SilentlyContinue
        $PyCharmPro = Get-ChildItem -Path "$dirFiles" -Include pycharm-professional-2022*.exe -File -Recurse -ErrorAction SilentlyContinue
        If($PyCharmCom.Exists)
        {
        ## Install PyCharm Community Edition 2022
        		Write-Log -Message "Found $($PyCharmCom.FullName), now attempting to install IntelliJ IDEA Community Edition 2022."
        Show-InstallationProgress "Installing PyCharm Community Edition 2022. This may take some time. Please wait..."
        Execute-Process -Path "$PyCharmCom" -Parameters "/S /CONFIG=""$dirFiles\silent.config""" -WindowStyle Hidden -IgnoreExitCodes '1223'
        Start-Sleep -Seconds 5
        
		## Suppress PyCharm Community Edition 2022 EULA
        Write-Log -Message "Suppressing PyCharm Community Edition 2022 EULA."
        [scriptblock]$HKCURegistrySettings = {
        Set-RegistryKey -Key 'HKCU\Software\JavaSoft\Prefs\jetbrains\privacy_policy' -Name 'euacommunity_accepted_version' -Value '1.0' -Type String -SID $UserProfile.SID
        }
        Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings -ErrorAction SilentlyContinue
        
		## Disable Data Sharing (Usage Statistics) Prompt 
        Write-Log -Message "Disabling Data Sharing (Usage Statistics) Prompt."
        $UserProfiles = Get-WmiObject Win32_UserProfile | Select-Object -ExpandProperty LocalPath
        ForEach ($Profile in $UserProfiles) {
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\" -ItemType Directory -Force
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\accepted" -ItemType File -Value "rsch.send.usage.stat:1.1:0:1111111111111" -Force
        }
              
        }
        ElseIf ($PyCharmEdu.Exists)
        {
        
		## Install PyCharm Edu 2022
        Write-Log -Message "Found $($PyCharmEdu.FullName), now attempting to install IntelliJ IDEA Educational Edition 2022."
        Show-InstallationProgress "Installing PyCharm Edu 2022. This may take some time. Please wait..."
        Execute-Process -Path "$PyCharmEdu" -Parameters "/S /CONFIG=""$dirFiles\silent.config""" -WindowStyle Hidden -IgnoreExitCodes '1223'
        Start-Sleep -Seconds 5
        
		## Suppress PyCharm Edu 2022 EULA
        Write-Log -Message "Suppressing PyCharm Edu 2022 EULA."
        [scriptblock]$HKCURegistrySettings = {
        Set-RegistryKey -Key 'HKCU\Software\JavaSoft\Prefs\jetbrains\privacy_policy' -Name 'accepted_version' -Value '2.5' -Type String -SID $UserProfile.SID
        }
        Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings -ErrorAction SilentlyContinue
        
		## Disable Data Sharing (Usage Statistics) Prompt 
        Write-Log -Message "Disabling Data Sharing (Usage Statistics) Prompt."
        $UserProfiles = Get-WmiObject Win32_UserProfile | Select-Object -ExpandProperty LocalPath
        ForEach ($Profile in $UserProfiles) {
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\" -ItemType Directory -Force
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\accepted" -ItemType File -Value "rsch.send.usage.stat:1.1:0:1111111111111" -Force
        }
        }
        ElseIf ($PyCharmPro.Exists)
        {
        
			## Install PyCharm Professional Edition 2022
        Write-Log -Message "Found $($PyCharmPro.FullName), now attempting to install IntelliJ IDEA Ultimate Edition 2022."
        Show-InstallationProgress "Installing PyCharm Professional Edition 2022. This may take some time. Please wait..."
        Execute-Process -Path "$PyCharmPro" -Parameters "/S /CONFIG=""$dirFiles\silent.config""" -WindowStyle Hidden -IgnoreExitCodes '1223'
        Start-Sleep -Seconds 5
        
		## Suppress PyCharm Professional Edition 2022 EULA
        Write-Log -Message "Suppressing PyCharm Professional Edition 2022 EULA."
        [scriptblock]$HKCURegistrySettings = {
        Set-RegistryKey -Key 'HKCU\Software\JavaSoft\Prefs\jetbrains\privacy_policy' -Name 'eua_accepted_version' -Value '1.4' -Type String -SID $UserProfile.SID
        }
        Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings -ErrorAction SilentlyContinue
        
		## Disable Data Sharing (Usage Statistics) Prompt 
        Write-Log -Message "Disabling Data Sharing (Usage Statistics) Prompt."
        $UserProfiles = Get-WmiObject Win32_UserProfile | Select-Object -ExpandProperty LocalPath
        ForEach ($Profile in $UserProfiles) {
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\" -ItemType Directory -Force
        New-Item "$Profile\AppData\Roaming\JetBrains\consentOptions\accepted" -ItemType File -Value "rsch.send.usage.stat:1.1:0:1111111111111" -Force
        }
        }

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		Set-RegistryKey -Key HKEY_LOCAL_MACHINE\SOFTWARE\Intune_Installations -Name 'pycharm-community-2022.2.3' -Value '"Installed"' -Type String

		## Display a message at the end of the install
		If (-not $useDefaultMsi) {}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, Close PyCharm With a 60 Second Countdown Before Automatically Closing
        Show-InstallationWelcome -CloseApps 'PyCharm,PyCharm64' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>



		##*===============================================
		##* UNINSTALLATION
		##*===============================================
 		
		## Remove Any Existing Versions of PyCharm Community Edition 2022
        $AppList = Get-InstalledApplication -Name 'PyCharm Community Edition 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''        
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }

        ## Remove Any Existing Versions of PyCharm Educational Edition 2022
        $AppList = Get-InstalledApplication -Name 'PyCharm Edu 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''       
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }
        
		## Remove Any Existing Versions of PyCharm Professional Edition 2022
        $AppList = Get-InstalledApplication -Name 'PyCharm 2022'        
        ForEach ($App in $AppList)
        {
        If($App.UninstallString)
        {
        $UninstPath = $App.UninstallString -replace '"', ''        
        If(Test-Path -Path $UninstPath)
        {
        Write-log -Message "Found $($App.DisplayName) ($($App.DisplayVersion)) and a valid uninstall string, now attempting to uninstall."
        Execute-Process -Path $UninstPath -Parameters '/S'
        Start-Sleep -Seconds 5
        }
        }
        }


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
		Remove-RegistryKey -Key HKEY_LOCAL_MACHINE\SOFTWARE\Intune_Installations -Name 'pycharm-community-2022.2.3'

	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
