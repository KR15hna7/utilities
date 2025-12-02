<#
.SYNOPSIS
Gathers current system resource usage (CPU and Memory) and identifies the top 10 applications/services consuming the most resources.

.DESCRIPTION
This script collects process metrics including CPU time, memory usage, and page file usage from all running processes.
It calculates a composite resource score (60% memory + 40% CPU) and exports the top 10 processes to a timestamped CSV file.
No external dependencies required - uses only built-in PowerShell cmdlets.

.PARAMETER OutputPath
The directory where the CSV report will be saved. If the directory doesn't exist, it will be created.
Default: ./Logs

.PARAMETER ExcludeSystem
Switch parameter. When specified, filters out common system processes (System, svchost, smss, csrss, wininit, services, lsass).

.PARAMETER ExcludeProcesses
Array of process names to exclude from the report. Case-insensitive.
Example: -ExcludeProcesses @('notepad', 'calc')

.EXAMPLE
# Basic usage - top 10 processes, saved to ./Logs
.\Get-SystemResources.ps1

.EXAMPLE
# Exclude system processes
.\Get-SystemResources.ps1 -ExcludeSystem

.EXAMPLE
# Custom output path and excluded processes
.\Get-SystemResources.ps1 -OutputPath "C:\Reports\SystemMonitoring" -ExcludeProcesses @('dwm', 'explorer') -ExcludeSystem

.NOTES
Author: System Resource Monitor
Created: 2025-12-02
Compatibility: Windows 7+
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "./Logs",
    [switch]$ExcludeSystem,
    [string[]]$ExcludeProcesses = @()
)

# Define system processes to exclude if -ExcludeSystem flag is used
$SystemProcesses = @(
    'System',
    'svchost',
    'smss',
    'csrss',
    'wininit',
    'services',
    'lsass',
    'services.exe'
)

# Combine excluded processes
$AllExcluded = $ExcludeProcesses
if ($ExcludeSystem) {
    $AllExcluded = $ExcludeProcesses + $SystemProcesses
}

try {
    # Create output directory if it doesn't exist
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Verbose "Created output directory: $OutputPath"
    }

    # Generate timestamped filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $csvFileName = "systemresources_$timestamp.csv"
    $csvFilePath = Join-Path -Path $OutputPath -ChildPath $csvFileName

    # Get CPU core count for percentage calculation
    $cpuCoreCount = (Get-CimInstance -ClassName Win32_Processor).NumberOfCores
    $systemBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $elapsedTime = (Get-Date) - $systemBootTime
    
    # Get system-level thread queue data
    $processorQueueLength = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_System).ProcessorQueueLength

    # Collect process metrics
    Write-Verbose "Gathering process metrics..."
    $processes = Get-Process | Where-Object {
        # Filter out excluded processes
        $_.Name -notin $AllExcluded
    } | Select-Object -Property @(
        'Name',
        'Id',
        @{Name='CPU_Seconds';Expression={[math]::Round($_.CPU, 2)}},
        @{Name='CPU_Percent';Expression={
            if ($elapsedTime.TotalSeconds -gt 0) {
                [math]::Round(($_.TotalProcessorTime.TotalSeconds / ($elapsedTime.TotalSeconds * $cpuCoreCount)) * 100, 2)
            } else {
                0
            }
        }},
        @{Name='Memory_MB';Expression={[math]::Round($_.WorkingSet / 1MB, 2)}},
        @{Name='PageFile_MB';Expression={[math]::Round($_.PagedMemorySize / 1MB, 2)}},
        @{Name='ThreadCount';Expression={$_.Threads.Count}}
    )

    # Calculate composite score and add ranking
    Write-Verbose "Calculating composite resource scores..."
    $processesWithScore = $processes | ForEach-Object {
        $memoryScore = $_.Memory_MB / 100  # Normalize memory
        $cpuScore = $_.CPU_Percent / 10     # Normalize CPU percentage
        $compositeScore = ($memoryScore * 0.60) + ($cpuScore * 0.40)
        
        $_ | Add-Member -NotePropertyName 'CompositeScore' -NotePropertyValue ([math]::Round($compositeScore, 2)) -PassThru
    }

    # Sort by composite score and select top 10
    Write-Verbose "Sorting and selecting top 10 processes..."
    $top10 = $processesWithScore | Sort-Object -Property CompositeScore -Descending | Select-Object -First 10

    # Add rank and timestamp columns
    $topProcessesForExport = $top10 | ForEach-Object -Begin { $rank = 1 } -Process {
        $_ | Add-Member -NotePropertyName 'Rank' -NotePropertyValue $rank -PassThru
        $_ | Add-Member -NotePropertyName 'Timestamp' -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -PassThru
        $rank++
    }

    # Export to CSV with proper column ordering
    $topProcessesForExport | Select-Object -Property @(
        'Timestamp',
        'Rank',
        'Name',
        'Id',
        'CPU_Percent',
        'CPU_Seconds',
        'Memory_MB',
        'PageFile_MB',
        'ThreadCount',
        'CompositeScore'
    ) | Export-Csv -Path $csvFilePath -NoTypeInformation -Force

    Write-Host "Successfully exported report to: $csvFilePath" -ForegroundColor Green
    Write-Host "`n=== System Resource Summary ===" -ForegroundColor Cyan
    Write-Host "CPU Cores: $cpuCoreCount" -ForegroundColor White
    Write-Host "Processor Queue Length: $processorQueueLength (threads waiting for CPU time)" -ForegroundColor White
    Write-Host "`nTop 10 Processes by Resource Usage:" -ForegroundColor Cyan
    $topProcessesForExport | Select-Object -Property 'Rank', 'Name', 'Id', 'CPU_Percent', 'CPU_Seconds', 'Memory_MB', 'CompositeScore', 'ThreadCount' | Format-Table -AutoSize

}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
