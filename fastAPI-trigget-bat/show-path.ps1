Write-Host "Current PATH Environment Variable Values:" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

$pathEntries = $env:PATH -split ';'

$counter = 1
foreach ($path in $pathEntries) {
    if ($path.Trim() -ne "") {
        Write-Host "$counter. $path" -ForegroundColor Cyan
        $counter++
    }
}

Write-Host ""
Write-Host "Total PATH entries: $($counter - 1)" -ForegroundColor Yellow
Write-Host ""


Write-Host "Press any key to exit..." -ForegroundColor Magenta
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")