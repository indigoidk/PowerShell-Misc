# HTTP "Ping" in PowerShell
# Prompts for IP:Port and interval, then sends HTTP GET requests repeatedly
# Created with CHATGPT5 080825
# Prompt: Can you write a PowerShell script that prompts for an IP:Port and seconds, and then attempts an HTTP GET, displaying an output similar to the ping command?
# Answer: Got it — you want a PowerShell script that works like ping, but for HTTP requests.
#It should:
#
#   Prompt for an IP:Port and a seconds interval.
#
#   Continuously send HTTP GET requests.
#
#   Display results similar to ping (success/fail, response time, etc.).
#
#   Continue until stopped with Ctrl+C
# No Warranty Expressed



$Target = Read-Host "Enter IP:Port (e.g., 192.168.1.10:8080)"
$Interval = Read-Host "Enter interval between requests (seconds)"

if (-not $Target) { Write-Host "No target provided. Exiting."; exit }
if (-not $Interval -or $Interval -as [int] -le 0) { $Interval = 1 }

$Uri = "http://$Target"
$SuccessCount = 0
$FailCount = 0
$Times = @()

Write-Host "`nPinging HTTP service at $Uri every $Interval seconds. Press Ctrl+C to stop.`n"

try {
    while ($true) {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $Response = Invoke-WebRequest -Uri $Uri -Method GET -UseBasicParsing -TimeoutSec 10
            $Stopwatch.Stop()
            $TimeTaken = [math]::Round($Stopwatch.Elapsed.TotalMilliseconds, 2)
            $StatusCode = $Response.StatusCode
            $SuccessCount++
            $Times += $TimeTaken
            Write-Host ("Reply from {0}: status={1} time={2}ms" -f $Target, $StatusCode, $TimeTaken) -ForegroundColor Green
        }
        catch {
            $Stopwatch.Stop()
            $FailCount++
            Write-Host ("Request to {0} failed: {1}" -f $Target, $_.Exception.Message) -ForegroundColor Red
        }
        Start-Sleep -Seconds $Interval
    }
}
finally {
    Write-Host "`n--- HTTP Ping statistics for $Target ---"
    $Total = $SuccessCount + $FailCount
    Write-Host ("Requests: Sent = {0}, Success = {1}, Failed = {2}" -f $Total, $SuccessCount, $FailCount)
    if ($Times.Count -gt 0) {
        $Avg = [math]::Round(($Times | Measure-Object -Average).Average, 2)
        $Min = ($Times | Measure-Object -Minimum).Minimum
        $Max = ($Times | Measure-Object -Maximum).Maximum
        Write-Host ("Approximate round trip times in milli-seconds:`nMinimum = {0}ms, Maximum = {1}ms, Average = {2}ms" -f $Min, $Max, $Avg)
    }
}1