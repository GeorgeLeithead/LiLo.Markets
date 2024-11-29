$Lilo = Get-Content -path .\Markets1.4.json | ConvertFrom-Json
$Lilo = $Lilo.Markets | Sort-Object Rank

$BinanceMarkets = Invoke-RestMethod "https://api.binance.com/api/v3/exchangeInfo"
$BinanceMarketsFiltered = $BinanceMarkets.symbols | Where-Object quoteAsset -eq "USDT" | Where-Object status -eq "TRADING"

$OutToLiLo = @()

foreach($Symbol in $LiLo)
{
    $SymbolString = $Symbol.SymbolString
    $BinanceMatch = $BinanceMarketsFiltered | Where-Object baseAsset -eq $SymbolString
	$Tick = $BinanceMatch | Select-Object @{n = "tickSize"; e = { $_.filters.tickSize[0]}}
	[int]$TickSize = $Tick.tickSize.split('1')[0].Length -1
	if ($TickSize -lt 0)
	{
		$TickSize = 0
	}

	$NewMarket = [PsCustomObject]@{
		SymbolString = $Symbol.SymbolString
		DecimalPlaces = $TickSize
		Rank = $Symbol.Rank
		DisplayName = $Symbol.DisplayName
	}
	$OutToLiLo += $NewMarket
}

$OutToLiLo | ConvertTo-Json

