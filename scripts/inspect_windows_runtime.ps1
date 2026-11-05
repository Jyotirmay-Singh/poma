[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputFile,
      [ValidateRange(1,30)][int]$Seconds = 10,
      [string]$Condition = 'operator-recorded')
$ErrorActionPreference = 'Stop'
$owners = @(Get-Process -Name poma -ErrorAction Stop)
if ($owners.Count -ne 1) { throw 'Expected exactly one running Poma process.' }
$owner = $owners[0]
$processId = $owner.Id
$started = $owner.StartTime
$cpuBefore = $owner.TotalProcessorTime.TotalSeconds
$watch = [Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $Seconds
$owner = Get-Process -Id $processId
if ($owner.StartTime -ne $started) { throw 'The process restarted during measurement.' }
$watch.Stop()
$modules = @($owner.Modules | ForEach-Object {
  [ordered]@{ name=$_.ModuleName; path=$_.FileName; version=$_.FileVersionInfo.FileVersion }
})
$result = [ordered]@{
  observedUtc=[DateTime]::UtcNow.ToString('o'); condition=$Condition;
  processId=$processId; processPath=$owner.Path; seconds=$watch.Elapsed.TotalSeconds;
  cpuPercentOfOneCore=100 * ($owner.TotalProcessorTime.TotalSeconds - $cpuBefore) / $watch.Elapsed.TotalSeconds;
  workingSetBytes=$owner.WorkingSet64; privateBytes=$owner.PrivateMemorySize64;
  modules=$modules;
  limitations=@('One short host sample is not a battery/performance guarantee.',
    'Loaded modules establish this process/host only; verify the installed package on a clean profile separately.',
    'This sampler does not measure network traffic, rendering frames or database writes.')
}
$absolute = [IO.Path]::GetFullPath($OutputFile)
New-Item -ItemType Directory -Path (Split-Path -Parent $absolute) -Force | Out-Null
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $absolute -Encoding UTF8
Write-Output "Observed PID $processId for $([math]::Round($watch.Elapsed.TotalSeconds,2)) seconds; CPU $([math]::Round($result.cpuPercentOfOneCore,3))% of one core."
Write-Output "Read-only runtime evidence: $absolute"
