Import-Module posh-git
git pull origin main
[bool]$CommitNeeded = $false

# Get the feeds
Write-Host "Getting CoinGeco feed..."
Write-Host "Page 1"
$Markets1 = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false"
Write-Host "Page 2"
$Markets2 = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=2&sparkline=false"
Write-Host "Page 3"
$Markets3 = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=3&sparkline=false"
$Markets = $Markets1 + $Markets2 + $Markets3
$MarketFiles = Get-ChildItem -Path .\ -File -Filter *.json | Sort-Object Name -Descending
$MarketFile = $MarketFiles[0] # To target only the latest markets file.
#foreach($MarketFile in $MarketFiles)
#{
    [bool]$Changes = $false
    Write-Host "*** Getting local $($MarketFile.Name) ***"
    $Lilo = Get-Content -path $MarketFile | ConvertFrom-Json

    # IOTA has a weird symbol on CoinGeko, so lets match
    $Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "iota"}
    $Miota.SymbolString = "MIOTA"

    $matchingMarkets = $Markets | Where-Object {$_.symbol -in $Lilo.Markets.SymbolString }
    foreach ($Market in $matchingMarkets)
    {
        $LiloItem = $Lilo.Markets | Where-Object {$_.SymbolString -eq $Market.symbol}
        if ($LiloItem.Rank -ne $Market.market_cap_rank)
        {
            $Changes = $true
            $CommitNeeded = $true
            write-host "$($LiloItem.SymbolString) - Rank: $($LiloItem.Rank) now $($Market.market_cap_rank)"
            $LiloItem.Rank = $Market.market_cap_rank
        }
    }

    if ($Changes)
    {
        # Undo the IOTA change
        $Miota = $Lilo.Markets | Where-Object {$_.SymbolString -eq "miota"}
        $Miota.SymbolString = "IOTA"
        $Lilo | ConvertTo-Json | Out-File $MarketFile
    }
#}

if ($CommitNeeded)
{
    Write-Host "*** Market Repository ***"
    git commit -m "Updated" -a
    git push
}

Write-Host "***DONE***"