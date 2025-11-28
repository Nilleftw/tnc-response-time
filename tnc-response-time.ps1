<#
.SYNOPSIS
Continuously monitors a TCP connection to a specified server and port.

.DESCRIPTION
This script repeatedly attempts to establish a TCP connection to a target
server and port, measuring the connection time. It prints the result
to the console and optionally logs the output to a text file using
the -LogFile parameter.

.PARAMETER Server
The hostname or IP address of the target server.

.PARAMETER Port
The TCP port number to connect to.

.PARAMETER IntervalSeconds
The time (in seconds) to wait between connection attempts. Defaults to 5.

.PARAMETER LogFile
Optional file path where the output will be continuously appended.
If this parameter is omitted, output is only written to the console.

.EXAMPLE
# Run the monitor for Google's HTTP port, logging only to the console
.\monitor_connection.ps1 -Server "www.google.com" -Port 80

.EXAMPLE
# Run the monitor for a specific server and port, logging output to a file
.\monitor_connection.ps1 -Server "your.api.endpoint" -Port 443 -LogFile "C:\Logs\monitor.log" -IntervalSeconds 10
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Server,

    [Parameter(Mandatory=$true)]
    [int]$Port,

    [int]$IntervalSeconds = 5,

    [string]$LogFile = $null
)

function Test-TcpConnection {
    # Initialize the StopWatch to measure latency
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $outputMessage = ""
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        # Attempt to connect with a short timeout to prevent hanging
        $connectTask = $tcpClient.ConnectAsync($Server, $Port)
        
        # Wait for the task to complete or timeout (e.g., 3 seconds max)
        if ($connectTask.Wait(3000)) {
            if ($tcpClient.Connected) {
                $sw.Stop()
                # FIX: Delimit variable names with {} when immediately followed by a colon
                $outputMessage = "$timestamp [SUCCESS] Connected to ${Server}:${Port} in $($sw.ElapsedMilliseconds) ms"
            } else {
                # This path is generally hard to hit with ConnectAsync unless connection is immediately rejected
                $sw.Stop()
                # FIX: Delimit variable names with {} when immediately followed by a colon
                $outputMessage = "$timestamp [FAILED] Connection to ${Server}:${Port} failed immediately. Time taken: $($sw.ElapsedMilliseconds) ms"
            }
        } else {
            # Handle timeout
            $sw.Stop()
            # FIX: Delimit variable names with {} when immediately followed by a colon
            $outputMessage = "$timestamp [TIMEOUT] Connection to ${Server}:${Port} timed out after 3000 ms. Time taken: $($sw.ElapsedMilliseconds) ms"
        }
    } catch {
        # Handle general connection exceptions (e.g., DNS failure, connection refused)
        $sw.Stop()
        $errorMessage = $_.Exception.Message -replace "`n|`r", " " # Clean up multi-line errors
        # FIX: Delimit variable names with {} when immediately followed by a colon
        $outputMessage = "$timestamp [FAILED] Connection to ${Server}:${Port} failed. Time taken: $($sw.ElapsedMilliseconds) ms. Error: $errorMessage"
    } finally {
        # Ensure the client is closed/disposed of
        if ($tcpClient -ne $null) {
            $tcpClient.Close()
            $tcpClient.Dispose()
        }
    }

    return $outputMessage
}

Write-Host "--- Starting continuous connection monitor ---"
# FIX: Delimit variable names with {} when immediately followed by a colon
Write-Host "Target: ${Server}:${Port}"
Write-Host "Interval: $IntervalSeconds seconds"
if ($LogFile) {
    Write-Host "Logging output to: $LogFile"
}
Write-Host "Press Ctrl+C to stop the script."
Write-Host "--------------------------------------------"

# Main loop
while ($true) {
    $result = Test-TcpConnection

    # Check if a log file path was provided
    if ($LogFile) {
        # Tee-Object writes to both the console (default stream) and the specified file
        $result | Out-String -Stream | Tee-Object -FilePath $LogFile -Append
    } else {
        # If no log file, just write to the console
        Write-Output $result
    }

    # Wait for the specified interval before running again
    Start-Sleep -Seconds $IntervalSeconds
}
