$ProgramPath = "C:\Program Files (x86)\Zoom\bin\Zoom.exe"
$ProgramVersion_target = "5,11,4,7185" 
$ProgramVersion_current = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ProgramPath).FileVersion

if($ProgramVersion_current -eq $ProgramVersion_target){
    Write-Host "Found it!"
}