[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RuntimeDirectory,
      [string]$OutputDirectory = 'artifacts/windows/calendar-session9')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility') -Force
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtime = [IO.Path]::GetFullPath($RuntimeDirectory)
$allowed = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')).TrimEnd('\') + '\'
if (-not $runtime.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Use a fresh isolated runtime under this workspace .tools directory.'
}
$executable = Join-Path $runtime 'poma.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw 'Complete isolated runtime required.' }
if (@(Get-Process -Name poma -ErrorAction SilentlyContinue).Count) {
  throw 'Close Poma normally before measuring the isolated review runtime.'
}
$profile = Join-Path $runtime 'fictional-review-profile'
if (Test-Path -LiteralPath $profile) { throw 'Use a fresh review profile; existing data is preserved.' }
$output = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
New-Item -ItemType Directory -Path $output -Force | Out-Null
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Session9Window {
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr window);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
}
'@
$environmentRecord = [ordered]@{
  utc=[DateTime]::UtcNow.ToString('o'); os=[Environment]::OSVersion.VersionString;
  x64=[Environment]::Is64BitOperatingSystem; processorCount=[Environment]::ProcessorCount;
  highContrast=[Windows.Forms.SystemInformation]::HighContrast;
  monitors=@([Windows.Forms.Screen]::AllScreens | ForEach-Object {
    [ordered]@{ device=$_.DeviceName; primary=$_.Primary;
      bounds=$_.Bounds.ToString(); workArea=$_.WorkingArea.ToString() }
  });
  packageCount=@(Get-AppxPackage -Name JyotirmaySingh.Poma.Desktop -ErrorAction Stop).Count
}
$environmentRecord | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'environment.json') -Encoding UTF8
$owner = Start-Process -FilePath $executable -ArgumentList '--startup' -WorkingDirectory $runtime -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput (Join-Path $output 'runtime-stdout.log') -RedirectStandardError (Join-Path $output 'runtime-stderr.log')
# Retain the started process handle before Refresh so Windows can report its exit.
$ownerHandle = $owner.Handle
$started = $owner.StartTime
$rows = @()
$seen = @{}
$relayResults = @()
$phaseFile = Join-Path $profile 'session9-phase.json'
$deadline = [DateTime]::UtcNow.AddMinutes(22)
try {
  while (-not $owner.HasExited) {
    if ([DateTime]::UtcNow -gt $deadline) { throw 'Review runtime exceeded its bounded measurement period.' }
    if (-not (Test-Path -LiteralPath $phaseFile)) { Start-Sleep -Milliseconds 250; $owner.Refresh(); continue }
    $phase = Get-Content -LiteralPath $phaseFile -Raw | ConvertFrom-Json
    if ($phase.phase -eq 0 -and $relayResults.Count -eq 0) {
      foreach ($index in 1..5) {
        $relay = Start-Process -FilePath $executable -ArgumentList '--startup' -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
        if (-not $relay.WaitForExit(10000)) { throw 'Secondary activation did not exit.' }
        $relayResults += [ordered]@{ index=$index; exitCode=$relay.ExitCode }
      }
      $owners = @(Get-Process -Name poma -ErrorAction Stop)
      if ($owners.Count -ne 1 -or $owners[0].Id -ne $owner.Id) { throw 'Secondary activation changed the sole owner.' }
    }
    if ($phase.state -ne 'sampling' -or $seen.ContainsKey([string]$phase.phase)) {
      Start-Sleep -Milliseconds 250; $owner.Refresh(); continue
    }
    $seen[[string]$phase.phase] = $true
    foreach ($index in 1..$phase.samples) {
      $current = Get-Process -Id $owner.Id -ErrorAction Stop
      if ($current.StartTime -ne $started -or $current.Path -ne $executable) { throw 'Review process identity changed.' }
      $cpuBefore = $current.TotalProcessorTime.TotalSeconds
      $watch = [Diagnostics.Stopwatch]::StartNew()
      Start-Sleep -Seconds $phase.seconds
      $current.Refresh(); $watch.Stop()
      $rows += [ordered]@{
        utc=[DateTime]::UtcNow.ToString('o'); condition=$phase.condition; sample=$index;
        seconds=$watch.Elapsed.TotalSeconds; cpuSeconds=$current.TotalProcessorTime.TotalSeconds - $cpuBefore;
        cpuPercentOfOneCore=100 * ($current.TotalProcessorTime.TotalSeconds - $cpuBefore) / $watch.Elapsed.TotalSeconds;
        workingSetBytes=$current.WorkingSet64; privateBytes=$current.PrivateMemorySize64;
        handles=$current.HandleCount; threads=$current.Threads.Count;
        mainWindowVisible=[Session9Window]::IsWindowVisible($current.MainWindowHandle);
        mainWindowDpi=[Session9Window]::GetDpiForWindow($current.MainWindowHandle)
      }
      $rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'resource-samples.json') -Encoding UTF8
    }
    [IO.File]::WriteAllText((Join-Path $profile "session9-phase-$($phase.phase).done"), 'measured')
    $owner.Refresh()
  }
  $owner.WaitForExit()
  $runtimeRecord = Join-Path $profile 'session9-runtime.json'
  if (-not (Test-Path -LiteralPath $runtimeRecord)) { throw 'Runtime exited without its result.' }
  Copy-Item -LiteralPath $runtimeRecord -Destination (Join-Path $output 'runtime-observations.json')
  $result = Get-Content -LiteralPath $runtimeRecord -Raw | ConvertFrom-Json
  [ordered]@{
    processId=$owner.Id; executable=$executable; exitCode=$owner.ExitCode;
    processExitObserved=$owner.HasExited; exitCodeCaptured=($null -ne $owner.ExitCode);
    secondaryActivations=$relayResults; conditionCount=$seen.Count; sampleCount=$rows.Count;
    passed=($result.passed -and $owner.HasExited -and ($null -eq $owner.ExitCode -or $owner.ExitCode -eq 0) -and $seen.Count -eq 5 -and $rows.Count -eq 24);
    limitations=@('Synthetic review target; not installed production acceptance.',
      'Instrumentation includes a one-second file acknowledgement probe equally across conditions.',
      'CPU is percent of one core, not a calibrated performance/battery budget.',
      'No network transport is constructed; counters do not constitute packet-capture evidence.',
      'Actual Explorer restart, scale changes, Narrator, startup, sleep and toast delivery remain owner checks.')
  } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'runtime-summary.json') -Encoding UTF8
  if (-not $result.passed) { throw 'Hidden runtime invariants failed; inspect preserved evidence.' }
  Write-Output "Observed $($rows.Count) resource samples, five relay exits and hidden completion; owner profile untouched."
} finally {
  $owner.Refresh()
  if (-not $owner.HasExited) {
    $current = Get-Process -Id $owner.Id -ErrorAction SilentlyContinue
    if ($current -and $current.StartTime -eq $started -and $current.Path -eq $executable) {
      Stop-Process -Id $owner.Id -ErrorAction Stop
    }
  }
}
