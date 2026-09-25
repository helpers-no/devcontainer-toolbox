# install.ps1 - First-time install of devcontainer-toolbox (image mode)
# Run with: irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex
# If blocked: powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex"
#
# Installs the DCT host command `dct-init` for this user (no admin) and then runs it in the
# current folder. dct-init writes .devcontainer\devcontainer.json, installs the VS Code Dev
# Containers extension and downloads the image. Every dct-* command is installed by this script.
# Afterwards, set up any new project folder by typing `dct-init` in it.
#
#   %LOCALAPPDATA%\devcontainer-toolbox\bin\dct-init.ps1   the logic
#   %LOCALAPPDATA%\devcontainer-toolbox\bin\dct-init.cmd   what the user types; on the user PATH
#
# Testing: $env:DCT_INSTALL_SOURCE = <repo checkout> installs host-tools\ from that folder
# instead of downloading them from GitHub; $env:DCT_INSTALL_REF = <branch> downloads them from
# that branch instead of main (to test a branch before it is merged).

# Everything runs inside a script block. With `irm | iex` this script runs in the user's own
# PowerShell session, so `exit` would close their window before they could read the message, and
# preference changes would leak into their session. Inside the block, `return` stops the script
# and leaves the window open.
& {

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "helpers-no/devcontainer-toolbox"
$ref = if ($env:DCT_INSTALL_REF) { $env:DCT_INSTALL_REF } else { "main" }
$files = @("dct-init.ps1", "dct-init.cmd")

Write-Host "Installing DevContainer Toolbox from $repo ($ref)..."
Write-Host ""

# --- 1. Can this PC run the dct-init script at all? ---------------------------------
# dct-init.cmd starts dct-init.ps1 with -ExecutionPolicy Bypass. That overrides the PC's default
# policy, but not a policy the organisation enforces (Group Policy / Intune). If one of those
# requires signed scripts, say so plainly instead of working around it.

$enforced = @()
foreach ($scope in "MachinePolicy", "UserPolicy") {
    try {
        $policy = Get-ExecutionPolicy -Scope $scope
        if ($policy -in @("AllSigned", "Restricted")) { $enforced += "$scope=$policy" }
    } catch { $null = $_ }   # scope not available: treat as not enforced
}
if ($enforced.Count -gt 0) {
    Write-Host "ERR006: Your organisation's PowerShell policy does not allow the DevContainer Toolbox" -ForegroundColor Yellow
    Write-Host "script to run on this PC ($($enforced -join ', '))."
    Write-Host ""
    Write-Host "Ask your IT department whether DevContainer Toolbox can be allowed, and show them this message."
    return
}

# --- 2. Install dct-init for this user ------------------------------------------------

$bin = Join-Path $env:LOCALAPPDATA "devcontainer-toolbox\bin"
New-Item -ItemType Directory -Path $bin -Force | Out-Null
Write-Host "Installing the dct-init command to $bin..."

# PowerShell 5.1 may default to TLS 1.0, which GitHub rejects
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($name in $files) {
    $dest = Join-Path $bin $name
    try {
        if ($env:DCT_INSTALL_SOURCE) {
            Copy-Item (Join-Path (Join-Path $env:DCT_INSTALL_SOURCE "host-tools") $name) $dest -Force
        } else {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$repo/$ref/host-tools/$name" -OutFile $dest -UseBasicParsing -TimeoutSec 30
        }
        # A downloaded file may carry the "from the internet" mark, which a RemoteSigned policy blocks.
        try { Unblock-File -Path $dest } catch { $null = $_ }   # not fatal; unsupported off Windows
    } catch {
        Write-Host ""
        Write-Host "ERR020: Could not download $name." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Check that this PC is connected to the internet, then run this command again."
        return
    }
}
Write-Host "  Installed dct-init"

# Put the folder on the user's PATH (no admin), and on this window's PATH so it works right away.
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not (($userPath -split ";") -contains $bin)) {
        $newPath = (@($userPath -split ";" | Where-Object { $_ }) + $bin) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }
} catch {
    Write-Host "  Warning: could not add $bin to your PATH; 'dct-init' will not be found by name." -ForegroundColor Yellow
}
if (-not (($env:Path -split ";") -contains $bin)) { $env:Path = "$env:Path;$bin" }

# --- 3. Set up the current folder -----------------------------------------------------

$ps = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $ps) { $ps = (Get-Process -Id $PID).Path }   # not Windows (tests run on Linux pwsh)

Write-Host ""
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bin "dct-init.ps1") -TargetDir (Get-Location).Path
$rc = $LASTEXITCODE
$ErrorActionPreference = $prevPref

# --- 4. How to use it next time -------------------------------------------------------

Write-Host ""
if ($rc -eq 0) {
    Write-Host "Next time, set up a new project folder by typing 'dct-init' in it."
} else {
    Write-Host "When the problem above is fixed, type 'dct-init' in this folder."
}
Write-Host "('dct-init' works in this window now, and in every new PowerShell window.)"

}
