$Markets = Invoke-RestMethod "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=300&page=1&sparkline=false"
$Lilo = Get-Content -path .\Markets1.4.json | ConvertFrom-Json
$SymbolsToIgnore = @(
	"usdt", # Stable Coin
	"usdc", # Stable coin
	"miota", # AKA IOTA
	"cro", # Not on binance
	"ust",
	"busd", #Stable coin
	"tusd", #Stable coin
	"usdp", #stable coin
	"any",
	"luna", # Luna is dead, long live Luna
	"hnt", # Helium (HNT) is dead,
	"ftt", #FTT has faked the markets and stolen everyones money!
	"btg", # Gone and forgotten
	"poly" # Doesn't want a cracker'
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

		$Rank = $Markets | Where-Object {$_.symbol -eq $Symbol} | Select-Object market_cap_rank
		$DisplayName = $Markets | Where-Object {$_.symbol -eq $Symbol} | Select-Object name

		$NewMarket = [PsCustomObject]@{
			SymbolString = $Symbol.ToUpper()
			DecimalPlaces = $TickSize
			Rank = $Rank.market_cap_rank
			DisplayName = $DisplayName.name + " (" + $Symbol.ToUpper() + ")"
		}
		$MissingFromLiLo += $NewMarket
	}
}

$MissingFromLiLo | Sort-Object Rank
exit 0
# Only do the below when you have the SVG images
$SymbolsWithIcons = @('APE')

# This is the JSON to add to Markets.json
$MissingFromLiLo | Where-Object SymbolString -in $SymbolsWithIcons | Sort-Object Rank | ConvertTo-Json

# This copies the generated images to the hosting site.
$ImagesCopyFrom = "..\LiLo.CryptoImages\LiLo.CryptoImages\LiLo.CryptoImages\LiLo.CryptoImages.Android\obj\Debug\120\resizetize\r\drawable-xxxhdpi"
$OneInchRenameFrom = "\oneinch.png"
$OneInchRenameTo = "1inch.png"
Rename-Item -path $($ImagesCopyFrom + $OneInchRenameFrom) -newname $OneInchRenameTo
$ImagesCopyTo = "..\InternetWideWorldStatic\Client\wwwroot\Images\Droid\drawable-xxxhdpi"
Copy-Item -path $($ImagesCopyFrom + "\*") -Destination $ImagesCopyTo
