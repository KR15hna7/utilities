@echo off
REM Non-interactive version for API use - displays PATH without waiting for input

echo Starting PATH display script...
echo.

REM Execute PowerShell commands to display PATH
powershell.exe -ExecutionPolicy Bypass -Command "& {Write-Host 'Current PATH Environment Variable Values:' -ForegroundColor Green; Write-Host '=========================================' -ForegroundColor Green; Write-Host ''; $pathEntries = $env:PATH -split ';'; $counter = 1; foreach ($path in $pathEntries) { if ($path.Trim() -ne '') { Write-Host \"$counter. $path\" -ForegroundColor Cyan; $counter++ } }; Write-Host ''; Write-Host \"Total PATH entries: $($counter - 1)\" -ForegroundColor Yellow}"
