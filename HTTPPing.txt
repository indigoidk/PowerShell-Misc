# HTTP Get ping tool with minimal reporting code with Claude
# No Warranty expressed
# Enhanced HTTP Ping Script with Live Summary Updates
param(
    [string]$Target,
    [string]$Tries = "",
    [int]$Delay = 0,
    [int]$TimeoutSec = 10
)

function Show-LiveSummary {
    param(
        [int]$Success,
        [int]$Fail,
        [array]$ResponseTimes,
        [string]$Uri,
        [int]$CurrentAttempt,
        [string]$Mode
    )
    
    $totalAttempts = $Success + $Fail
    
    if ($totalAttempts -eq 0) {
        return
    }
    
    # Calculate statistics
    $avgResponse = 0
    $minResponse = 0
    $maxResponse = 0
    if ($ResponseTimes.Count -gt 0) {
        $avgResponse = [math]::Round(($ResponseTimes | Measure-Object -Average).Average, 2)
        $minResponse = ($ResponseTimes | Measure-Object -Minimum).Minimum
        $maxResponse = ($ResponseTimes | Measure-Object -Maximum).Maximum
    }
    
    # Clear previous summary and show updated one
    Write-Host "`n" + ("="*70) -ForegroundColor Cyan
    Write-Host "HTTP Ping Statistics for $Uri" -ForegroundColor Cyan
    Write-Host ("="*70) -ForegroundColor Cyan
    
    if ($Mode -eq "infinite") {
        Write-Host "Mode: INFINITE (running continuously...)" -ForegroundColor Yellow
    } else {
        Write-Host "Progress: $CurrentAttempt of $Mode attempts" -ForegroundColor Green
    }
    
    Write-Host "Requests: Sent = $totalAttempts, Successful = $Success, Failed = $Fail ($([math]::Round(($Fail / $totalAttempts) * 100, 1))% loss)" -ForegroundColor White
    
    if ($ResponseTimes.Count -gt 0) {
        Write-Host "Response Times: Min = ${minResponse}ms, Max = ${maxResponse}ms, Avg = ${avgResponse}ms" -ForegroundColor White
    }
    
    Write-Host ("="*70) -ForegroundColor Cyan
    
    if ($Mode -eq "infinite") {
        Write-Host "Press Ctrl+C to stop (summary will remain visible)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Test-HttpEndpoint {
    param(
        [string]$Uri,
        [string]$Attempts,
        [int]$DelaySeconds,
        [int]$Timeout
    )
    
    # Initialize counters
    $success = 0
    $fail = 0
    $responseTimes = @()
    
    $isInfinite = $Attempts -eq "infinite"
    
    Write-Host "`nStarting HTTP GET ping to $Uri`n" -ForegroundColor Cyan
    Write-Host "Timeout: $Timeout seconds | Delay: $DelaySeconds seconds" -ForegroundColor White
    
    if ($isInfinite) {
        Write-Host "Mode: INFINITE - Will update summary after each attempt" -ForegroundColor Yellow
        Write-Host "Press Ctrl+C anytime to stop (final summary will be visible)`n" -ForegroundColor Yellow
    } else {
        Write-Host "Mode: FINITE - $Attempts attempts total`n" -ForegroundColor Green
    }
    
    try {
        $i = 1
        while ($true) {
            # Exit condition for finite attempts
            if (-not $isInfinite -and $i -gt [int]$Attempts) {
                break
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            try {
                $response = Invoke-WebRequest -Uri $Uri -Method GET -TimeoutSec $Timeout -ErrorAction Stop
                $stopwatch.Stop()
                $responseTime = $stopwatch.ElapsedMilliseconds
                $responseTimes += $responseTime
                
                if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                    Write-Host "Attempt $i`: SUCCESS - HTTP $($response.StatusCode) - ${responseTime}ms" -ForegroundColor Green
                    $success++
                } else {
                    Write-Host "Attempt $i`: FAIL - HTTP $($response.StatusCode) - ${responseTime}ms" -ForegroundColor Yellow
                    $fail++
                }
            } catch {
                $stopwatch.Stop()
                $errorMsg = $_.Exception.Message
                # Clean up common error messages for better readability
                if ($errorMsg -match "The operation has timed out") {
                    $errorMsg = "Request timed out (>${Timeout}s)"
                } elseif ($errorMsg -match "No such host is known") {
                    $errorMsg = "Host not found (DNS resolution failed)"
                }
                
                Write-Host "Attempt $i`: ERROR - $errorMsg" -ForegroundColor Red
                $fail++
            }
            
            # Show live summary after every attempt
            Show-LiveSummary -Success $success -Fail $fail -ResponseTimes $responseTimes -Uri $Uri -CurrentAttempt $i -Mode $Attempts
            
            # Sleep between attempts (except for the last one in finite mode)
            if ($isInfinite -or $i -lt [int]$Attempts) {
                if ($DelaySeconds -gt 0) {
                    Write-Host "Waiting $DelaySeconds seconds..." -ForegroundColor Gray
                    Start-Sleep -Seconds $DelaySeconds
                }
            }
            
            $i++
        }
    } catch {
        # This will catch Ctrl+C and other interruptions
        Write-Host "`n`nSession interrupted!" -ForegroundColor Yellow
    } finally {
        # Always show final summary
        Write-Host "`n" + ("="*70) -ForegroundColor Red
        Write-Host "FINAL SUMMARY" -ForegroundColor Red
        Write-Host ("="*70) -ForegroundColor Red
        
        $totalAttempts = $success + $fail
        if ($totalAttempts -gt 0) {
            if ($responseTimes.Count -gt 0) {
                $avgResponse = [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
                $minResponse = ($responseTimes | Measure-Object -Minimum).Minimum
                $maxResponse = ($responseTimes | Measure-Object -Maximum).Maximum
            }
            
            Write-Host "Target: $Uri" -ForegroundColor White
            Write-Host "Total Requests: $totalAttempts" -ForegroundColor White
            Write-Host "Successful: $success" -ForegroundColor Green
            Write-Host "Failed: $fail" -ForegroundColor Red
            Write-Host "Success Rate: $([math]::Round(($success / $totalAttempts) * 100, 1))%" -ForegroundColor White
            
            if ($responseTimes.Count -gt 0) {
                Write-Host "`nResponse Time Statistics:" -ForegroundColor Cyan
                Write-Host "  Minimum: ${minResponse}ms" -ForegroundColor White
                Write-Host "  Maximum: ${maxResponse}ms" -ForegroundColor White
                Write-Host "  Average: ${avgResponse}ms" -ForegroundColor White
            }
        } else {
            Write-Host "No requests completed." -ForegroundColor Yellow
        }
        
        Write-Host ("="*70) -ForegroundColor Red
        Write-Host ""
    }
}

# Main execution
if (-not $Target) {
    do {
        $Target = Read-Host "Enter the IP address or URL (e.g., https://example.com)"
        if ([string]::IsNullOrWhiteSpace($Target)) {
            Write-Host "Target cannot be empty. Please try again." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($Target))
}

# Add protocol if missing
if ($Target -notmatch "^https?://") {
    $Target = "http://$Target"
    Write-Host "Added http:// prefix to target: $Target" -ForegroundColor Yellow
}

# Validate and get other parameters if not provided
if ([string]::IsNullOrWhiteSpace($Tries)) {
    do {
        $inputTries = Read-Host "Enter number of attempts (or 'infinite' for continuous ping, default: 5)"
        if ([string]::IsNullOrWhiteSpace($inputTries)) { 
            $Tries = "5" 
            break
        }
        if ($inputTries.ToLower() -eq "infinite" -or $inputTries.ToLower() -eq "inf" -or $inputTries.ToLower() -eq "∞") {
            $Tries = "infinite"
            break
        }
        try {
            [int]$numTries = [int]$inputTries
            if ($numTries -lt 1) {
                Write-Host "Number of attempts must be at least 1, or 'infinite'." -ForegroundColor Red
                continue
            }
            $Tries = $inputTries
            break
        } catch {
            Write-Host "Please enter a valid number or 'infinite'." -ForegroundColor Red
        }
    } while ($true)
}

if ($Delay -eq 0) {
    do {
        try {
            $inputDelay = Read-Host "Enter delay in seconds between attempts (default: 1)"
            if ([string]::IsNullOrWhiteSpace($inputDelay)) { 
                $Delay = 1 
                break
            }
            [int]$Delay = [int]$inputDelay
            if ($Delay -lt 0) {
                Write-Host "Delay cannot be negative." -ForegroundColor Red
                $Delay = 0
                continue
            }
            break
        } catch {
            Write-Host "Please enter a valid number." -ForegroundColor Red
            $Delay = 0
        }
    } while ($Delay -eq 0)
}

# Run the test

Test-HttpEndpoint -Uri $Target -Attempts $Tries -DelaySeconds $Delay -Timeout $TimeoutSec
