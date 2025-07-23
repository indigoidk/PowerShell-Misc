# Rclone Log Parser, Email Summary, and Rotation Script
# Version 1.0
# No Warranty Expressed
# Coded with Claude Sonnet v4
# Test and verified working 7/22/2025 with Office.com (SMTP Relay)
#
# Example Json used
#{
#    "EmailSettings":  {
#                          "UseTLS":  true,
#                         "Username":  "example@company.com",
#                         "SMTPPort":  25,
#                          "Password":  "not used with IP auth",
#                         "FromEmail":  "example@company.com",
#                          "Subject":  "Rclone Stage 2/2 Summary - {STATUS}",
#                          "SMTPServer":  "company-com.mail.protection.outlook.com",
#                          "UseStartTLS":  false,
#                          "ToEmail":  "example@company.com"
#                      },
#    "LogSettings":  {
#                        "DateFormat":  "yyyyMMdd",
#                        "ArchivePattern":  "rclone{DATE}.log",
#                        "ArchiveCount":  30,
#                        "LogFile":  ".\\rclone.log"
#                   }
# }
#


param(
    [string]$ConfigFile = ".\rclone-log-config.json",
    [string]$LogFile = ".\rclone.log"
)

# Default configuration - will be created if config file doesn't exist
$DefaultConfig = @{
    EmailSettings = @{
        SMTPServer = "smtp.gmail.com"
        SMTPPort = 587
        UseTLS = $true
        UseStartTLS = $false
        FromEmail = "sender@example.com"
        ToEmail = "recipient@example.com"
        Username = "sender@example.com"
        Password = ""  # Will be prompted if empty
        Subject = "Rclone Summary - {STATUS}"
    }
    LogSettings = @{
        LogFile = ".\rclone.log"
        ArchiveCount = 30
        ArchivePattern = "rclone{DATE}.log"
        DateFormat = "yyyyMMdd"
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Load-Configuration {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Config file not found. Creating default configuration at: $ConfigPath" "WARN"
        $DefaultConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-Log "Please edit the configuration file and run the script again." "INFO"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Convert PSCustomObject to hashtable for easier access
        $configHash = @{}
        $config.PSObject.Properties | ForEach-Object {
            $configHash[$_.Name] = $_.Value
        }
        
        Write-Log "Configuration loaded successfully from: $ConfigPath"
        return $config
    }
    catch {
        Write-Log "Failed to load configuration: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Parse-RcloneLog {
    param([string]$LogPath)
    
    if (-not (Test-Path $LogPath)) {
        Write-Log "Log file not found: $LogPath" "ERROR"
        return $null
    }
    
    $logContent = Get-Content $LogPath -ErrorAction SilentlyContinue
    
    # Empty log = Success
    if (-not $logContent -or $logContent.Count -eq 0) {
        Write-Log "Log file is empty - indicating successful operation" "INFO"
        return @{
            Status = "Success"
            ErrorCount = 0
            NoticeCount = 0
            Events = @()
            Summary = "Log file is empty - rclone operation completed successfully"
        }
    }
    
    # Any content in log = Failure
    Write-Log "Log file contains $($logContent.Count) lines - indicating failure" "WARN"
    
    $events = @()
    $errorCount = 0
    $noticeCount = 0
    
    foreach ($line in $logContent) {
        if ($line -match '^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})\s+(ERROR|NOTICE):\s*(.*)$') {
            $timestamp = $matches[1]
            $level = $matches[2]
            $message = $matches[3].Trim()
            
            $event = @{
                Timestamp = $timestamp
                Level = $level
                Message = $message
            }
            
            $events += $event
            
            if ($level -eq "ERROR") {
                $errorCount++
            } elseif ($level -eq "NOTICE") {
                $noticeCount++
            }
        } else {
            # Handle non-standard log lines
            $event = @{
                Timestamp = "Unknown"
                Level = "LOG"
                Message = $line.Trim()
            }
            $events += $event
            $errorCount++
        }
    }
    
    return @{
        Status = "Failure"
        ErrorCount = $errorCount
        NoticeCount = $noticeCount
        Events = $events
        Summary = "Log file contains $($logContent.Count) lines indicating rclone encountered issues. Found $errorCount errors and $noticeCount notices."
    }
}

function Send-EmailSummary {
    param(
        $Config,
        $LogData
    )
    
    try {
        # Get credentials
        if ([string]::IsNullOrEmpty($Config.EmailSettings.Password)) {
            $credential = Get-Credential -UserName $Config.EmailSettings.Username -Message "Enter email password"
        } else {
            $securePassword = ConvertTo-SecureString $Config.EmailSettings.Password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($Config.EmailSettings.Username, $securePassword)
        }
        
        # Prepare email content
        $subject = $Config.EmailSettings.Subject -replace "{STATUS}", $LogData.Status
        
        $body = @"
Rclone Log Summary - $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")

Status: $($LogData.Status)
$($LogData.Summary)

Event Summary:
- Errors: $($LogData.ErrorCount)
- Notices: $($LogData.NoticeCount)
- Total Events: $($LogData.Events.Count)

"@

        if ($LogData.Events.Count -gt 0) {
            $body += "`nDetailed Events:`n"
            $body += "=" * 50 + "`n"
            
            foreach ($event in $LogData.Events) {
                $body += "[$($event.Timestamp)] $($event.Level): $($event.Message)`n"
            }
        }
        
        # Configure SMTP parameters
        $smtpParams = @{
            SmtpServer = $Config.EmailSettings.SMTPServer
            Port = $Config.EmailSettings.SMTPPort
            From = $Config.EmailSettings.FromEmail
            To = $Config.EmailSettings.ToEmail
            Subject = $subject
            Body = $body
            Credential = $credential
        }
        
        if ($Config.EmailSettings.UseTLS) {
            $smtpParams.UseSsl = $true
        }
        
        Send-MailMessage @smtpParams
        Write-Log "Email summary sent successfully to: $($Config.EmailSettings.ToEmail)"
        return $true
        
    } catch {
        Write-Log "Failed to send email: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Rotate-LogFile {
    param(
        $Config,
        [string]$LogPath
    )
    
    try {
        if (-not (Test-Path $LogPath)) {
            Write-Log "Log file does not exist, skipping rotation: $LogPath" "WARN"
            return $true
        }
        
        # Generate archive filename
        $dateStr = Get-Date -Format $Config.LogSettings.DateFormat
        $archiveName = $Config.LogSettings.ArchivePattern -replace "{DATE}", $dateStr
        $archivePath = Join-Path (Split-Path $LogPath -Parent) $archiveName
        
        # Handle duplicate archive names
        $counter = 1
        $originalArchivePath = $archivePath
        while (Test-Path $archivePath) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($originalArchivePath)
            $extension = [System.IO.Path]::GetExtension($originalArchivePath)
            $archivePath = Join-Path (Split-Path $originalArchivePath -Parent) "$baseName-$counter$extension"
            $counter++
        }
        
        # Move current log to archive
        Move-Item $LogPath $archivePath -Force
        Write-Log "Log file rotated to: $archivePath"
        
        # Clean up old archives
        $logDirectory = Split-Path $LogPath -Parent
        $archivePattern = $Config.LogSettings.ArchivePattern -replace "{DATE}", "*"
        $oldArchives = Get-ChildItem -Path $logDirectory -Filter $archivePattern | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -Skip $Config.LogSettings.ArchiveCount
        
        foreach ($oldArchive in $oldArchives) {
            Remove-Item $oldArchive.FullName -Force
            Write-Log "Removed old archive: $($oldArchive.Name)"
        }
        
        Write-Log "Log rotation completed. Keeping $($Config.LogSettings.ArchiveCount) archives."
        return $true
        
    } catch {
        Write-Log "Failed to rotate log file: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
function Main {
    Write-Log "Starting Rclone Log Parser"
    
    # Load configuration
    $config = Load-Configuration -ConfigPath $ConfigFile
    if (-not $config) {
        exit 1
    }
    
    # Use command line log file if specified, otherwise use config
    $logFileToProcess = if ($LogFile -ne ".\rclone.log") { $LogFile } else { $config.LogSettings.LogFile }
    
    Write-Log "Processing log file: $logFileToProcess"
    
    # Parse the log file
    $logData = Parse-RcloneLog -LogPath $logFileToProcess
    if (-not $logData) {
        Write-Log "Failed to parse log file" "ERROR"
        exit 1
    }
    
    Write-Log "Log parsing completed. Status: $($logData.Status)"
    Write-Log "$($logData.Summary)"
    
    # Send email summary
    Write-Log "Sending email summary..."
    $emailSent = Send-EmailSummary -Config $config -LogData $logData
    
    # Rotate log file only if email was sent successfully
    if ($emailSent) {
        Write-Log "Rotating log file..."
        $rotated = Rotate-LogFile -Config $config -LogPath $logFileToProcess
        
        if ($rotated) {
            Write-Log "Rclone log processing completed successfully"
        } else {
            Write-Log "Log processing completed but rotation failed" "WARN"
        }
    } else {
        Write-Log "Skipping log rotation due to email failure" "WARN"
    }
}

# Run the main function
Main
