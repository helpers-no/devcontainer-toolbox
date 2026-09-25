# test-dct-init-windows.ps1 - Install dct-init the way the Quick Start does, then use it by name
#
# Runs on a GitHub Windows runner. Uses stub `docker` and `code` commands (the runner cannot run
# Linux containers, and a real image pull would take minutes), so this checks the Windows-only
# parts: install.ps1 under `irm | iex`, the user PATH entry, finding `dct-init` by name in a new
# shell, and exit codes coming through dct-init.cmd.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Runs install.ps1 exactly as the Quick Start does (irm | iex)')]
param()

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$failures = 0
function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Host "PASS  $Name" } else { Write-Host "FAIL  $Name"; $script:failures++ }
}

# Stubs, first on PATH. `docker info` succeeds or fails depending on DCT_STUB_DOCKER.
$stubs = Join-Path ([IO.Path]::GetTempPath()) ("dct-stubs-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stubs | Out-Null
Set-Content (Join-Path $stubs 'docker.cmd') -Encoding ASCII -Value @'
@if "%DCT_STUB_DOCKER%"=="down" exit /b 1
@if "%1"=="pull" echo stub pull %2
@exit /b 0
'@
Set-Content (Join-Path $stubs 'code.cmd') -Encoding ASCII -Value @'
@if "%1"=="--install-extension" echo stub installed %2
@exit /b 0
'@
$env:Path = "$stubs;$env:Path"
$env:DCT_INSTALL_SOURCE = $repo

# 1. Install through install.ps1 exactly as the Quick Start runs it (Invoke-Expression).
$proj1 = Join-Path ([IO.Path]::GetTempPath()) ("dct-proj1-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proj1 | Out-Null
Push-Location $proj1
Get-Content (Join-Path $repo 'install.ps1') -Raw | Invoke-Expression
Pop-Location
Check "install.ps1 wrote .devcontainer\devcontainer.json" (Test-Path (Join-Path $proj1 '.devcontainer\devcontainer.json'))

$bin = Join-Path $env:LOCALAPPDATA 'devcontainer-toolbox\bin'
Check "dct-init.ps1 and dct-init.cmd installed" ((Test-Path "$bin\dct-init.ps1") -and (Test-Path "$bin\dct-init.cmd"))
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
Check "bin folder is on the user PATH (registry)" ((($userPath -split ';') -contains $bin))

# 2. A NEW shell, with PATH built the way a new window builds it (machine + user from the
#    registry, plus the stubs), finds `dct-init` by name and sets up a second folder.
$freshPath = "$stubs;" + [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + $userPath
$proj2 = Join-Path ([IO.Path]::GetTempPath()) ("dct-proj2-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proj2 | Out-Null

$env:Path = $freshPath
$env:DCT_STUB_DOCKER = 'up'
cmd /c "cd /d `"$proj2`" && dct-init"
$rcOk = $LASTEXITCODE
Check "dct-init by name in a new shell exits 0" ($rcOk -eq 0)
Check "dct-init by name wrote the second folder" (Test-Path (Join-Path $proj2 '.devcontainer\devcontainer.json'))

# 3. Exit codes come through dct-init.cmd.
$proj3 = Join-Path ([IO.Path]::GetTempPath()) ("dct-proj3-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $proj3 | Out-Null
$env:DCT_STUB_DOCKER = 'down'
cmd /c "cd /d `"$proj3`" && dct-init"
$rcDown = $LASTEXITCODE
Check "Rancher not running: exit 1 through dct-init.cmd" ($rcDown -eq 1)
Check "Rancher not running: nothing written" (-not (Test-Path (Join-Path $proj3 '.devcontainer')))

$env:DCT_STUB_DOCKER = 'up'
cmd /c "dct-init -TargetDir `"$env:SystemRoot\System32`""
Check "System32 refused: exit 3 through dct-init.cmd" ($LASTEXITCODE -eq 3)
Check "System32 untouched" (-not (Test-Path "$env:SystemRoot\System32\.devcontainer"))

Write-Host ""
if ($failures -gt 0) { Write-Host "RESULT: $failures check(s) failed"; exit 1 }
Write-Host "RESULT: all checks passed"
exit 0
