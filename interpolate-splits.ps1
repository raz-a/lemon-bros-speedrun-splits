Param(
    [Parameter(Mandatory = $false)]
    [int]$Hours = 0,
    [Parameter(Mandatory = $false)]
    [int]$Minutes = 0,
    [Parameter(Mandatory = $false)]
    [double]$Seconds = 0,
    [Parameter(Mandatory = $true)]
    [int]$StarCount
)

if ($StarCount -gt 120 -or $StarCount -lt 0) {
    Write-Output "Invalid number of stars (must be between 0 and 120)"
    exit 1
}

$totalMinutes = ($Hours * 60) + $Minutes
$totalSeconds = ($totalMinutes * 60) + $Seconds
$totalFrames = ($totalSeconds * 30)

$numSplits = $StarCount + 1

$packedSplits = "", "", "", ""
$packSize = 32

$framesPerSplit = $totalFrames / $numSplits

$packIndex = 0
for ($i = 1; $i -le $numSplits; $i++) {
    $frames = [int]($i * $framesPerSplit)
    $packedSplits[$packIndex] = $packedSplits[$packIndex] + $frames
    if ($i % $packSize -ne 0 -and $i -ne $numSplits) {
        $packedSplits[$packIndex] = $packedSplits[$packIndex] + "_"
    }
    else {
        $packIndex++
    }
}

for ($i = 0; $i -lt $packedSplits.Count; $i++) {
    Write-Output $packedSplits[$i]
}
