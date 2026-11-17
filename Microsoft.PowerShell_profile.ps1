function prompt {
    # Change these RGB numbers (0 to 255) to customize your colors
    $bgR  = 128; $bgG = 128; $bgB = 128    # Background color
    $txtR = 15; $txtG = 15; $txtB = 15    # Text color inside the block
    
    $ESC = [char]0x1b
    $arrow = [char]0x276F
    
    # Bulletproof string concatenation
    $bgBlock = "$ESC[48;2;" + $bgR + ";" + $bgG + ";" + $bgB + ";38;2;" + $txtR + ";" + $txtG + ";" + $txtB + "m"
    $arrowColor = "$ESC[38;2;" + $bgR + ";" + $bgG + ";" + $bgB + "m"
    $reset = "$ESC[0m"

    "$bgBlock $(Get-Location) $reset$arrowColor $arrow $reset"
}

function weather ($location = "") {
    if ($location) {
        irm "wttr.in/$location"
    } else {
        irm wttr.in
	}
}

function search {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string]$Query,
        [int]$MaxResults = 4
    )

    process {
        $uri = "https://html.duckduckgo.com/html/"
        
        try {
            $html = & curl.exe -s -L -X POST -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" -d "q=$Query" $uri
            
            if (-not $html) {
                Write-Error "Search failed: Empty response received."
                return
            }

            $linkMatches = [regex]::Matches($html, '<a rel="nofollow" class="result__a" href="([^"]+)">(.*?)</a>')
            $snippetMatches = [regex]::Matches($html, '<a class="result__snippet"[^>]*>(.*?)</a>')

            $count = [Math]::Min($MaxResults, $linkMatches.Count)
            if ($count -eq 0) {
                Write-Host "No results found for '$Query'." -ForegroundColor Red
                return
            }

            $topTitle = [System.Net.WebUtility]::HtmlDecode(($linkMatches[0].Groups[2].Value -replace '<[^>]+>', ''))
            $topSnippet = if ($snippetMatches.Count -gt 0) {
                [System.Net.WebUtility]::HtmlDecode(($snippetMatches[0].Groups[1].Value -replace '<[^>]+>', ''))
            } else { 
                "No summary available." 
            }

            $topRawUrl = $linkMatches[0].Groups[1].Value
            $topUrl = if ($topRawUrl -match 'uddg=([^&]+)') { 
                [System.Net.WebUtility]::UrlDecode($Matches[1]) 
            } else { 
                $topRawUrl 
            }

            Write-Host "`n+-------------------------------------------------------+" -ForegroundColor Green
            Write-Host "| SUMMARY: $Query" -ForegroundColor Green
            Write-Host "+-------------------------------------------------------+" -ForegroundColor Green
            Write-Host "| $topSnippet" -ForegroundColor White
            Write-Host "|" -ForegroundColor Green
            Write-Host "| Source: $topTitle" -ForegroundColor DarkGray
            Write-Host "+-------------------------------------------------------+" -ForegroundColor Green

            Write-Host "`n[ Top Web Links ]" -ForegroundColor Cyan
            for ($i = 0; $i -lt $count; $i++) {
                $rawUrl = $linkMatches[$i].Groups[1].Value
                $title  = [System.Net.WebUtility]::HtmlDecode(($linkMatches[$i].Groups[2].Value -replace '<[^>]+>', ''))
                $cleanUrl = if ($rawUrl -match 'uddg=([^&]+)') { 
                    [System.Net.WebUtility]::UrlDecode($Matches[1]) 
                } else { 
                    $rawUrl 
                }

                Write-Host "  $($i + 1). $title" -ForegroundColor Yellow
                Write-Host "     $cleanUrl" -ForegroundColor DarkCyan
            }
            Write-Host ""
        }
        catch {
            Write-Error "Search failed: $_"
        }
    }
}

function whatismyip {
    [CmdletBinding()]
    param()

    # Get system identifiers
    $serverName = $env:COMPUTERNAME

    Write-Host "`n[ Server Identity ]" -ForegroundColor Cyan
    Write-Host "  ID / Hostname : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$serverName" -ForegroundColor Yellow

    Write-Host "`n[ Local & Virtual Network Interfaces ]" -ForegroundColor Cyan

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

    foreach ($adapter in $adapters) {
        $ipObj = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if (-not $ipObj) { continue }

        $ip = $ipObj.IPAddress
        $name = $adapter.Name
        $desc = $adapter.InterfaceDescription

        # Find the Default Gateway / Server IP for this specific interface
        $route = Get-NetRoute -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | 
                 Select-Object -First 1
        
        $gateway = if ($route.NextHop) { $route.NextHop } else { "N/A (Peer/Direct)" }

        # Categorize the interface for clean terminal output
        $tag = "OTHER"
        $color = "White"

        if ($desc -match "Wi-Fi|Wireless|WLAN") {
            $tag = "WI-FI"
            $color = "Green"
        }
        elseif ($desc -match "Ethernet|Gigabit|PCIe") {
            $tag = "ETHERNET"
            $color = "Green"
        }
        elseif ($desc -match "Tailscale") {
            $tag = "TAILSCALE"
            $color = "Magenta"
            $gateway = "Tailscale Mesh (100.64.0.0/10)"
        }
        elseif ($desc -match "Radmin") {
            $tag = "RADMIN VPN"
            $color = "Yellow"
            $gateway = "Radmin Hub"
        }
        elseif ($desc -match "Mobile Hotspot|Hosted Network|Virtual Wi-Fi") {
            $tag = "HOTSPOT"
            $color = "Cyan"
            $gateway = "This PC (DHCP Server)"
        }

        Write-Host "  [$tag]" -NoNewline -ForegroundColor $color
        Write-Host " $name" -ForegroundColor White
        Write-Host "    Client IP : $ip" -ForegroundColor DarkGray
        Write-Host "    Server/GW : $gateway" -ForegroundColor DarkGray
    }

    # Get Public IP via free JSON API
    Write-Host "`n[ Public IP Address ]" -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 3
        Write-Host "  [PUBLIC]   " -NoNewline -ForegroundColor Blue
        Write-Host "$($response.ip) ($($response.city), $($response.region))" -ForegroundColor White
        Write-Host "             ISP: $($response.org)" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [PUBLIC]   Could not fetch public IP (offline or timeout)." -ForegroundColor Red
    }
    Write-Host ""
}

function speedtest {
    [CmdletBinding()]
    param(
        [int]$Runs = 3
    )

    Write-Host "`n[ Network Speed & Stability Test ($Runs Runs) ]" -ForegroundColor Cyan

    $results = @()
    $wc = New-Object System.Net.WebClient

    for ($i = 1; $i -le $Runs; $i++) {
        Write-Host "  Run $i/$Runs..." -NoNewline -ForegroundColor DarkGray

        # 1. Latency (Ping)
        $ping = Test-Connection -ComputerName "1.1.1.1" -Count 3 -ErrorAction SilentlyContinue
        if (-not $ping) {
            Write-Host " [!] Ping failed." -ForegroundColor Red
            continue
        }
        $lat = [Math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 1)

        # 2. Download test (10 MB payload)
        $downSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $downData = $wc.DownloadData("https://speed.cloudflare.com/__down?bytes=10000000")
            $downSw.Stop()
            $downMbps = [Math]::Round(($downData.Length * 8) / $downSw.Elapsed.TotalSeconds / 1000000, 2)
        } catch { $downMbps = 0 }

        # 3. Upload test (5 MB payload)
        $upSw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $upData = New-Object byte[] (5000000)
            (New-Object System.Random).NextBytes($upData)
            $null = $wc.UploadData("https://speed.cloudflare.com/__up", "POST", $upData)
            $upSw.Stop()
            $upMbps = [Math]::Round(($upData.Length * 8) / $upSw.Elapsed.TotalSeconds / 1000000, 2)
        } catch { $upMbps = 0 }

        Write-Host " Ping: ${lat}ms | Down: ${downMbps}Mbps | Up: ${upMbps}Mbps" -ForegroundColor White

        $results += [PSCustomObject]@{
            Run      = $i
            Latency  = $lat
            Download = $downMbps
            Upload   = $upMbps
        }
        
        # Brief pause between runs
        if ($i -lt $Runs) { Start-Sleep -Milliseconds 500 }
    }
    $wc.Dispose()

    if ($results.Count -eq 0) {
        Write-Host "  [!] All test runs failed." -ForegroundColor Red
        return
    }

    # Calculate Averages
    $avgLat  = [Math]::Round(($results | Measure-Object -Property Latency -Average).Average, 1)
    $avgDown = [Math]::Round(($results | Measure-Object -Property Download -Average).Average, 2)
    $avgUp   = [Math]::Round(($results | Measure-Object -Property Upload -Average).Average, 2)

    # Stability Analysis (Download Variance)
    $maxDown = ($results | Measure-Object -Property Download -Maximum).Maximum
    $minDown = ($results | Measure-Object -Property Download -Minimum).Minimum
    $downSpread = [Math]::Round($maxDown - $minDown, 2)

    $stabilityRating = if ($downSpread -lt 5) { "Rock Solid (Very Stable)" } elseif ($downSpread -lt 15) { "Good (Minor Fluctuation)" } else { "Unstable (High Variance / Jitter)" }
    $stabColor       = if ($downSpread -lt 5) { "Green" } elseif ($downSpread -lt 15) { "Yellow" } else { "Red" }

    # Display Summary Averages
    Write-Host "`n[ Average Results ]" -ForegroundColor Cyan
    Write-Host "  Avg Latency    : $avgLat ms" -ForegroundColor Yellow
    Write-Host "  Avg Download   : $avgDown Mbps" -ForegroundColor Green
    Write-Host "  Avg Upload     : $avgUp Mbps" -ForegroundColor Green

    # Stability & Ookla-Style Ratings
    Write-Host "`n[ Stability & Performance Ratings ]" -ForegroundColor Cyan
    Write-Host "  Stability            : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$stabilityRating (Spread: ±$([Math]::Round($downSpread/2, 1)) Mbps)" -ForegroundColor $stabColor

    $gamingRating  = if ($avgLat -lt 30) { "Excellent (Competitive)" } elseif ($avgLat -lt 60) { "Good (Casual)" } else { "Fair / Lag Prone" }
    $streamRating  = if ($avgDown -ge 25) { "Excellent (4K Ultra HD)" } elseif ($avgDown -ge 10) { "Good (1080p HD)" } else { "Fair / Low Quality" }
    $meetingRating = if ($avgUp -ge 10 -and $avgLat -lt 50) { "Excellent (HD Calls)" } else { "Good / Fair" }

    Write-Host "  Gaming Suitability   : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$gamingRating" -ForegroundColor Yellow
    Write-Host "  4K Streaming         : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$streamRating" -ForegroundColor Green
    Write-Host "  Video Meetings       : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$meetingRating" -ForegroundColor Green
    Write-Host ""
}

function ask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Query,

        [Parameter(Mandatory=$false)]
        [ValidateSet("basic", "advanced")]
        [string]$SearchDepth = "basic"
    )

    # Automatically load .env from the same directory as $PROFILE if it exists
    $envPath = Join-Path (Split-Path $PROFILE -Parent) ".env"
    if (Test-Path $envPath) {
        Get-Content $envPath | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
            $parts = $_.Split('=', 2)
            $name  = $parts[0].Trim()
            $val   = $parts[1].Trim().Trim('"').Trim("'")
            # Set as a process-level environment variable for the session
            [Environment]::SetEnvironmentVariable($name, $val, "Process")
        }
    }

    # Pull keys from the environment
    $tavilyKey = $env:TAVILY_API_KEY
    $groqKey   = $env:GROQ_API_KEY

    if (-not $tavilyKey -or -not $groqKey) {
        Write-Host "[!] Error: Missing API keys! Check your .env file next to your profile." -ForegroundColor Red
        return
    }

    Write-Host "Thinking [$SearchDepth search]..." -NoNewline -ForegroundColor DarkGray

    # 1. Search via Tavily
    $tavilyBody = @{
        api_key      = $tavilyKey
        query        = $Query
        search_depth = $SearchDepth
        max_results  = 3
    } | ConvertTo-Json

    try {
        $searchRes = Invoke-RestMethod -Uri "https://api.tavily.com/search" -Method Post -Body $tavilyBody -ContentType "application/json"
    } catch {
        Write-Host "`r[!] Tavily API failed: $_" -ForegroundColor Red
        return
    }

    if (-not $searchRes.results -or $searchRes.results.Count -eq 0) {
        Write-Host "`r[!] No relevant web results found." -ForegroundColor Yellow
        return
    }

    $context = ""
    $sources = @()
    foreach ($res in $searchRes.results) {
        $cleanContent = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::Default.GetBytes($res.content))
        $context += "$cleanContent`n`n"
        
        $sources += [PSCustomObject]@{
            Title = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::Default.GetBytes($res.title))
            Url   = $res.url
        }
    }

    # 2. Pass context to Groq
    $groqBody = @{
        model    = "openai/gpt-oss-120b"
        messages = @(
            @{ role = "system"; content = "You are a direct terminal answering machine. Give a concise, straight-to-point answer in a small paragraph based on the provided web context." },
            @{ role = "user"; content = "Question: $Query`n`nContext:`n$context" }
        )
    } | ConvertTo-Json -Depth 5

    try {
        $aiRes = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Body $groqBody -Headers @{ "Authorization" = "Bearer $groqKey" } -ContentType "application/json"
        $answer = $aiRes.choices[0].message.content
        
        $answer = $answer -replace '[â]([\x80-\xff])+', "'" -replace 'â¯', ' '

        Write-Host "`r                                           `r" -NoNewline
        Write-Host "$answer" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[ Sources ]" -ForegroundColor DarkGray
        foreach ($src in $sources) {
            Write-Host "  * $($src.Title)" -ForegroundColor Yellow
            Write-Host "    $($src.Url)" -ForegroundColor DarkCyan
        }
        Write-Host ""
    } 
    catch {
        Write-Host "`r                                           `r" -NoNewline
        $errMessage = $_.Exception.Message
        if ($_.ErrorDetails) {
            $errMessage = $_.ErrorDetails.Message
        } elseif ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $errMessage = $reader.ReadToEnd()
            } catch {}
        }
        Write-Host "[!] Groq API Error: $errMessage" -ForegroundColor Red
    }
}