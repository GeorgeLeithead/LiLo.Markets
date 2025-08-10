Import-Module posh-git
git pull origin main
[bool]$CommitNeeded = $false

# Define symbol fixes to pass to the update script
$SymbolFixes = @(
    @{ type = 'name'; value = 'Bridged Ether (StarkGate)'; symbol = 'STGT' },
    @{ type = 'name'; value = 'Binance-Peg Dogecoin'; symbol = 'BDOG' },
    @{ type = 'id'; value = 'department-of-government-efficiency'; symbol = 'DOGE.gov' }
)

# Call the shared update logic with symbol fixes
. $PSScriptRoot\Update-Markets-GHA.ps1 -SymbolFixes $SymbolFixes

# Only handle git commit/push if needed
if ($CommitNeeded)
{
    Write-Host "*** Market Repository ***"
    git commit -m "Updated" -a
    git push
}

Write-Host "***DONE***"