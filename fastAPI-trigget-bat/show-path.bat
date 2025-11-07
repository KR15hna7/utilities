@echo off
REM Self-contained batch file that displays current PATH environment variable values
REM This script can be run by double-clicking - no external files needed

echo Starting PATH display script...
echo.

REM Execute PowerShell commands directly within the batch file
powershell.exe -ExecutionPolicy Bypass -Command "& {Write-Host 'Current PATH Environment Variable Values:' -ForegroundColor Green; Write-Host '=========================================' -ForegroundColor Green; Write-Host ''; $pathEntries = $env:PATH -split ';'; $counter = 1; foreach ($path in $pathEntries) { if ($path.Trim() -ne '') { Write-Host \"$counter. $path\" -ForegroundColor Cyan; $counter++ } }; Write-Host ''; Write-Host \"Total PATH entries: $($counter - 1)\" -ForegroundColor Yellow; Write-Host ''; Write-Host 'Press any key to exit...' -ForegroundColor Magenta; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')}"