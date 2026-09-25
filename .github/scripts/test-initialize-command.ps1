# test-initialize-command.ps1 - Run a devcontainer.json's initializeCommand the way VS Code does
#
# Uses the real devcontainers CLI (`devcontainer up`), so the command goes through the same
# path as for a user: on Windows the CLI runs it with `cmd.exe /c` (devcontainers/cli
# src/spec-node/utils.ts, runInitializeCommand). The CLI runs initializeCommand before it pulls
# the image, so on a runner that cannot run Linux containers `up` still fails later - that is
# expected. Only the initializeCommand outcome is judged.
#
# Usage: test-initialize-command.ps1 -Config <devcontainer.json> -Expect pass|fail

param(
    [Parameter(Mandatory = $true)][string]$Config,
    [Parameter(Mandatory = $true)][ValidateSet('pass', 'fail')][string]$Expect
)

$ErrorActionPreference = 'Stop'

$ranMarker    = 'Running the initializeCommand from devcontainer.json'
$failedMarker = 'The initializeCommand in the devcontainer.json failed'

# GitHub's Windows runners put Git for Windows' Unix tools (C:\Program Files\Git\usr\bin, with
# true.exe, sh.exe, ...) on PATH. An ordinary office PC does not: Git's default install does not
# add them, and most users have no Git at all. With them on PATH the old bash-only command ends in
# a real `true` and "succeeds", so the check proves nothing. Remove them so cmd.exe sees what a
# normal PC sees, and verify it.
$env:Path = (($env:Path -split ';') | Where-Object {
    $_ -and ($_ -notmatch '\\Git\\(usr\\)?bin\\?$') -and ($_ -notmatch '\\Git\\mingw64\\bin\\?$') -and ($_ -notmatch '(msys|cygwin)')
}) -join ';'
$unixTrue = Get-Command true -ErrorAction SilentlyContinue
if ($unixTrue) {
    Write-Host "ERROR: a Unix 'true' is still on PATH ($($unixTrue.Source)), so this run would not match a normal PC."
    exit 1
}

$workspace = Join-Path ([IO.Path]::GetTempPath()) ("dct-ic-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $workspace '.devcontainer') -Force | Out-Null
Copy-Item -LiteralPath $Config -Destination (Join-Path $workspace '.devcontainer\devcontainer.json')

Write-Host "Config:    $Config"
Write-Host "Expect:    $Expect"
Write-Host "Workspace: $workspace"
Write-Host ""

$ErrorActionPreference = 'Continue'
$output = (& devcontainer up --workspace-folder $workspace 2>&1 | Out-String)
$ErrorActionPreference = 'Stop'

$ran    = $output -match [regex]::Escape($ranMarker)
$failed = $output -match [regex]::Escape($failedMarker)

Write-Host "initializeCommand ran:    $ran"
Write-Host "initializeCommand failed: $failed"

$ok = $false
if (-not $ran) {
    Write-Host "ERROR: the CLI never reached initializeCommand, so this run proves nothing."
} elseif ($Expect -eq 'pass' -and -not $failed) {
    $ok = $true
} elseif ($Expect -eq 'fail' -and $failed) {
    $ok = $true
}

if (-not $ok) {
    Write-Host ""
    Write-Host "----- devcontainer up output -----"
    Write-Host $output
    Write-Host "----------------------------------"
    Write-Host "RESULT: FAIL (expected initializeCommand to $Expect)"
    exit 1
}

Write-Host "RESULT: OK (initializeCommand did $Expect, as expected)"
exit 0
