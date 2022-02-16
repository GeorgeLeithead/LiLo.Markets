$Markets = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=300&page=1&sparkline=false"
$Lilo = Get-Content -path .\Markets1.3.json | ConvertFrom-Json
$SymbolsToIgnore = @(
	"usdt", # Stable Coin
	"usdc", # Stable coin
	"miota", # AKA IOTA
	"cro" # Not on binance
)
$MissingMarketsInLiLo = @()
foreach($Market in $Markets)
{
	if ($Lilo.Markets.SymbolString -notcontains $Market.symbol)
	{
		if ($SymbolsToIgnore -notcontains $($Market.Symbol))
		{
			$MissingMarketsInLiLo += $Market
		}
	}
}

$BinanceMarkets = Invoke-RestMethod "https://api.binance.com/api/v3/exchangeInfo"
$BinanceMarketsUsdt = $BinanceMarkets.symbols | Where-Object quoteAsset -eq "USDT" | Where-Object status -eq "TRADING" | Where-Object permissions -contains "SPOT"
$MissingFromLiLo = @()

foreach($BinanceSymbol in $BinanceMarketsUsdt)
{
	[string]$Symbol = $BinanceSymbol.baseAsset.ToLower()
	if ($MissingMarketsInLiLo.symbol -contains $Symbol)
	{
		$Tick = $BinanceSymbol | Select-Object @{n = "tickSize"; e = { $_.filters.tickSize[0]}}
		[int]$TickSize = $Tick.tickSize.split('1')[0].Length -1
		if ($TickSize -lt 0)
		{
			$TickSize = 0
		}

		$Rank = $Markets | Where-Object {$_.symbol -eq $Symbol} | select market_cap_rank

		$NewMarket = [PsCustomObject]@{
			SymbolString = $Symbol.ToUpper()
			DecimalPlaces = $TickSize
			Rank = $Rank.market_cap_rank
		}
		$MissingFromLiLo += $NewMarket
	}
}

$SymbolsWithIcons = @('GALA', 'FXS', 'CVX', 'ROSE', 'SCRT', 'USDP', 'SLP', 'MINA', '1INCH', 'WAXP')

# This is the JSON to add to Markets.json
$MissingFromLiLo | Where-Object SymbolString -in $SymbolsWithIcons | Sort-Object Rank | ConvertTo-Json