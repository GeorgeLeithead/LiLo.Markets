<#
.SYNOPSIS
    Updates local market data files using CoinGecko API and applies symbol fixes.
.DESCRIPTION
    Fetches market data from CoinGecko, applies custom symbol fixes, and updates the latest JSON market file with new rankings.
.PARAMETER SymbolFixes
    An array of hashtables specifying symbol overrides by name or id.
.EXAMPLE
    .\Update-Markets-GHA.ps1 -SymbolFixes @(@{type='name';value='Bridged Ether (StarkGate)';symbol='STGT'})
#>
param(
    [Parameter(Mandatory=$false)]
    [array]$SymbolFixes = @(
        @{ type = 'name'; value = 'Bridged Ether (StarkGate)'; symbol = 'STGT' },
        @{ type = 'name'; value = 'Binance-Peg Dogecoin'; symbol = 'BDOG' },
        @{ type = 'id'; value = 'department-of-government-efficiency'; symbol = 'DOGE.gov' }
    )
)

function Invoke-CoingeckoApiWithRetry {
    <#
    .SYNOPSIS
        Calls CoinGecko API with retry logic.
    .PARAMETER Url
        The API endpoint to call.
    .PARAMETER MaxRetries
        Maximum number of retry attempts.
    .PARAMETER DelaySeconds
        Delay between retries in seconds.
    .OUTPUTS
        The result of Invoke-RestMethod or $null on failure.
    #>
    param(
        [string]$Url,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            return Invoke-RestMethod -Uri $Url -TimeoutSec 30
        } catch {
            $attempt++
            if ($attempt -ge $MaxRetries) {
                Write-Host "Failed to fetch: $Url after $MaxRetries attempts. Error: $_"
                return $null
            }
            Write-Host "Retrying $Url in $DelaySeconds seconds... ($attempt/$MaxRetries)"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# --- Main Script Logic ---

Write-Host "Getting CoinGecko feed..."
$Markets = @()
for ($page = 1; $page -le 3; $page++) {
    Write-Host "Page $page"
    $url = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=$page&sparkline=false"
    $result = Invoke-CoingeckoApiWithRetry -Url $url
    if ($null -eq $result) {
        Write-Host "Skipping page $page due to repeated errors."
        continue
    }
    $Markets += $result
}
if ($Markets.Count -eq 0) {
    Write-Host "No market data retrieved. Exiting."
    exit 1
}

# Apply symbol fixes
foreach ($fix in $SymbolFixes) {
    # $fix.type: 'name' or 'id', $fix.value: value to match, $fix.symbol: new symbol
    if ($fix.type -eq 'name') {
        $item = $Markets | Where-Object { $_.name -eq $fix.value }
    } elseif ($fix.type -eq 'id') {
        $item = $Markets | Where-Object { $_.id -eq $fix.value }
    } else {
        $item = $null
    }
    if ($null -ne $item) {
        $item.symbol = $fix.symbol
    }
}

# Find latest market file
$MarketFile = Get-ChildItem -Path .\ -File -Filter *.json | Sort-Object Name -Descending | Select-Object -First 1
if ($null -eq $MarketFile) {
    Write-Host "No JSON market files found. Exiting."
    exit 1
}

[bool]$Changes = $false
Write-Host "*** Getting local $($MarketFile.Name) ***"
try {
    $Lilo = Get-Content -path $MarketFile | ConvertFrom-Json
} catch {
    Write-Host "Failed to parse $($MarketFile.Name) as JSON. Skipping."
    exit 1
}

# IOTA has a weird symbol on CoinGeko, so lets match
$Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "iota"}
if ($null -ne $Miota) { $Miota.SymbolString = "MIOTA" }
$matchingMarkets = $Markets | Where-Object {$_.symbol -in $Lilo.Markets.SymbolString }
# Print table header
$header = "{0,-6} {1,6} {2,6} {3,6}" -f 'Coin', 'Old', 'New', 'U/D'
Write-Host $header
Write-Host ('-' * $header.Length)
foreach ($Market in $matchingMarkets) {
    $LiloItem = $Lilo.Markets | Where-Object {$_.SymbolString -eq $Market.symbol}
    if ($LiloItem.Rank -ne $Market.market_cap_rank) {
        $Changes = $true
        $diff = $Market.market_cap_rank - $LiloItem.Rank
        if ($diff -gt 0) {
            $ud = "+$diff"
        } elseif ($diff -lt 0) {
            $ud = "$diff"
        } else {
            $ud = "0"
        }
        $row = "{0,-6} {1,6} {2,6} {3,6}" -f $LiloItem.SymbolString, $LiloItem.Rank, $Market.market_cap_rank, $ud
        Write-Host $row
        $LiloItem.Rank = $Market.market_cap_rank
    }
}

if (-not $Changes) {
    Write-Host "No changes detected in market rankings."
} else {
    Write-Host "Changes detected, updating $($MarketFile.Name)..."
    # Undo the IOTA change
    $Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "miota"}
    if ($null -ne $Miota) { $Miota.SymbolString = "IOTA" }
    $Lilo | ConvertTo-Json | Out-File $MarketFile
    Write-Host "Updated $($MarketFile.Name) with new rankings."
}

Write-Host "***DONE***"
