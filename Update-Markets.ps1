Import-Module posh-git
git pull origin main

# Get the feeds
Write-Host "Getting CoinGeco feed..."
$Markets = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=150&page=1&sparkline=false"
Write-Host "Getting local markets.json"
$Lilo = Get-Content -path .\Markets.json | ConvertFrom-Json

# IOTA has a weird symbol on CoinGeko, so lets match
$Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "iota"}
$Miota.SymbolString = "MIOTA"

$matchingMarkets = $Markets | Where-Object {$_.symbol -in $Lilo.Markets.SymbolString }
[bool]$Changes = $false
foreach ($Market in $matchingMarkets)
{
    $LiloItem = $Lilo.Markets | Where-Object {$_.SymbolString -eq $Market.symbol}
    write-host "Found match: $($LiloItem.SymbolString)"
    if ($LiloItem.Rank -ne $Market.market_cap_rank)
    {
        $Changes = $true
        write-host "`tRank: $($LiloItem.Rank) now $($Market.market_cap_rank)"
        $LiloItem.Rank = $Market.market_cap_rank
    }
}

if ($Changes)
{
    # Undo the IOTA change
    $Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "miota"}
    $Miota.SymbolString = "IOTA"
    $Lilo | ConvertTo-Json | Out-File .\Markets.json
    Write-Host "UPDATING Markets.json"
    git push
}

Write-Host "***DONE***"