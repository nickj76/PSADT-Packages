$ProgramPath = "C:\Program Files\Python310\python.exe"
$ProgramVersion_target = "3.10.6" 
$ProgramVersion_current = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ProgramPath).FileVersion

if($ProgramVersion_current -eq $ProgramVersion_target){
    Write-Host "Found it!"
}