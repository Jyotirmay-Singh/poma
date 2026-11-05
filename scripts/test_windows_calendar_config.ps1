$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot 'build_windows_release.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Windows release script has syntax errors.' }
# Exercise the actual early guard without invoking Flutter, packaging or signing.
$guard = $ast.EndBlock.Statements | Where-Object {
  $_ -is [Management.Automation.Language.IfStatementAst] -and
  $_.Extent.Text.StartsWith('if ($CalendarDefinesPath)')
} | Select-Object -First 1
if (-not $guard) { throw 'Calendar configuration guard missing.' }
$validate = [scriptblock]::Create('param($CalendarDefinesPath, $SkipBuild) ' + $guard.Extent.Text)
$folder = Join-Path $projectRoot ('.tools/calendar-config-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$checks = 0
try {
  $file = Join-Path $folder 'synthetic-defines.json'
  $valid = '{"POMA_GOOGLE_CLIENT_ID":"123456-synthetic.apps.googleusercontent.com","POMA_GOOGLE_DESKTOP_CLIENT_SECRET":"","POMA_GOOGLE_OAUTH_AUDIENCE":"external_testing"}'
  & $validate '' $false
  $checks++
  [IO.File]::WriteAllText($file, $valid)
  & $validate $file $false
  $checks++
  $cases = @(
    'not json',
    '{"installed":{"client_id":"synthetic"}}',
    $valid.Replace('123456-synthetic', '123456-placeholder'),
    $valid.Replace('external_testing', 'unknown'),
    $valid.Replace('"POMA_GOOGLE_DESKTOP_CLIENT_SECRET":""', '"POMA_GOOGLE_DESKTOP_CLIENT_SECRET":42'),
    $valid.Replace('"POMA_GOOGLE_DESKTOP_CLIENT_SECRET":""', '"POMA_GOOGLE_DESKTOP_CLIENT_SECRET":"line\nbreak"'),
    $valid.Replace('external_testing"}', 'external_testing","refresh_token":"synthetic-test-only"}')
  )
  foreach ($value in $cases) {
    [IO.File]::WriteAllText($file, $value)
    $rejected = $false
    try { & $validate $file $false } catch { $rejected = $true }
    if (-not $rejected) { throw 'Invalid calendar build configuration accepted.' }
    $checks++
  }
  [IO.File]::WriteAllText($file, $valid)
  $rejected = $false
  try { & $validate $file $true } catch { $rejected = $true }
  if (-not $rejected) { throw 'SkipBuild accepted incompatible configuration.' }
  $checks++
  $rejected = $false
  try { & $validate (Join-Path $folder 'missing.json') $false } catch { $rejected = $true }
  if (-not $rejected) { throw 'Missing calendar configuration accepted.' }
  $checks++
  Write-Output "$checks calendar build-configuration checks passed. No build, account access or publication performed."
} finally {
  # Exact fresh workspace child; no computed recursive removal.
  if ([IO.File]::Exists($file)) { [IO.File]::Delete($file) }
  [IO.Directory]::Delete($folder)
}
