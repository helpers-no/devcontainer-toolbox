# File: host-tools/dct-init.ps1
# Installed to: %LOCALAPPDATA%\devcontainer-toolbox\bin\dct-init.ps1 (by install.ps1),
# started through dct-init.cmd, which is on the user's PATH.
#
# Purpose:
#   Set up a project folder for DevContainer Toolbox: write .devcontainer\devcontainer.json,
#   recommend and install the VS Code Dev Containers extension, and download the image.
#   After the first install, a user sets up any new project folder by typing `dct-init` in it.
#
# Usage:
#   dct-init                     set up the current folder
#   dct-init -TargetDir <path>   set up another folder
#
# Contract (agreed with client-provisioning, urb-agents #1505): no prompts, never needs admin,
# safe to run twice. Exit codes:
#   0  done
#   1  a prerequisite is missing (Rancher Desktop not installed or not running, no VS Code)
#   2  download or network failure
#   3  target folder problem (missing, a system folder, or a backup already exists)
# Every error line carries an ERRnnn code. Nothing is written while a prerequisite is missing.
#
# Keep this file plain ASCII: Windows PowerShell 5.1 reads a BOM-less .ps1 in the ANSI code page.

param(
    [string]$TargetDir = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "helpers-no/devcontainer-toolbox"
$image = "ghcr.io/${repo}:latest"
$templateUrl = "https://raw.githubusercontent.com/$repo/main/devcontainer-user-template.json"
$extId = "ms-vscode-remote.remote-containers"

function Exit-DctInit([int]$Code, [string]$Err, [string[]]$Lines) {
    Write-Host ""
    Write-Host "${Err}: $($Lines[0])" -ForegroundColor Yellow
    foreach ($line in ($Lines | Select-Object -Skip 1)) { Write-Host $line }
    exit $Code
}

# Native commands write progress to stderr; with "Stop" that would be treated as a script error.
function Invoke-Native([scriptblock]$Block) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $Block } finally { $ErrorActionPreference = $prev }
}

Write-Host "Setting up DevContainer Toolbox in: $TargetDir"

$isAdmin = $false
try {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isAdmin = $false   # not Windows (tests run on Linux pwsh)
}
if ($isAdmin) {
    Write-Host ""
    Write-Host "Note: this window runs as administrator. DevContainer Toolbox does not need that;" -ForegroundColor Yellow
    Write-Host "a normal PowerShell window is enough."
}

# --- 1. Prerequisites (nothing is written before these pass) -----------------------

$rancherExe = @(
    "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe",
    "$env:ProgramFiles\Rancher Desktop\Rancher Desktop.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    if ($rancherExe) {
        Exit-DctInit 1 "ERR002" @(
            "Rancher Desktop is installed, but this PowerShell window cannot see it yet.",
            "",
            "Close this window, open a new PowerShell window, and run the same command again.")
    }
    Exit-DctInit 1 "ERR001" @(
        "Rancher Desktop is not installed on this PC. DevContainer Toolbox needs it.",
        "",
        "On a work PC: install Rancher Desktop from Company Portal, or ask your IT department.",
        "On your own PC: download it from https://rancherdesktop.io/",
        "Then run this command again.")
}

Invoke-Native { docker info *> $null }
if ($LASTEXITCODE -ne 0) {
    Exit-DctInit 1 "ERR003" @(
        "Rancher Desktop is not running.",
        "",
        "1. Start Rancher Desktop from the Start menu.",
        "2. Wait until it says it is ready. The first start can take a few minutes.",
        "3. Then run this command again.")
}

# VS Code usually comes from Intune (Company Portal) or the user installer, so `code` may not
# be on PATH yet: also look in the user and system install folders.
$codeCmd = $null
$codeOnPath = Get-Command code -ErrorAction SilentlyContinue
if ($codeOnPath) {
    $codeCmd = $codeOnPath.Source
} else {
    $codeCmd = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $codeCmd) {
    Exit-DctInit 1 "ERR004" @(
        "VS Code was not found on this PC.",
        "",
        "Install VS Code (on a work PC: from Company Portal), then run this command again.")
}

# --- 2. Target folder -----------------------------------------------------------------

if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    Exit-DctInit 3 "ERR010" @("The folder does not exist: $TargetDir")
}
$target = (Resolve-Path -LiteralPath $TargetDir).ProviderPath.TrimEnd('\')

$mkdirHint = @(
    "",
    "Create a folder for your project and run this command in it, for example:",
    "    mkdir `$HOME\my-project; cd `$HOME\my-project; dct-init")

$systemFolders = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) |
    Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
foreach ($sys in $systemFolders) {
    if ($target -eq $sys -or $target.StartsWith("$sys\", [StringComparison]::OrdinalIgnoreCase)) {
        Exit-DctInit 3 "ERR011" (@("This is a Windows system folder, not a project folder: $target") + $mkdirHint)
    }
}
if ($target -eq ([IO.Path]::GetPathRoot("$target\")).TrimEnd('\')) {
    Exit-DctInit 3 "ERR011" (@("This is the root of a drive, not a project folder: $target") + $mkdirHint)
}
if ($target -eq $HOME.TrimEnd('\')) {
    Exit-DctInit 3 "ERR011" (@("This is your home folder, not a project folder.") + $mkdirHint)
}

Set-Location -LiteralPath $target

if (Test-Path ".devcontainer.backup") {
    Exit-DctInit 3 "ERR012" @(
        "A previous backup (.devcontainer.backup\) already exists in this folder.",
        "",
        "Remove or rename it first, so it is not overwritten, e.g.:",
        "    Rename-Item .devcontainer.backup .devcontainer.backup.old")
}

# --- 3. devcontainer.json -------------------------------------------------------------

if (Test-Path ".devcontainer") {
    Write-Host "Found existing .devcontainer\ folder. Backing it up to .devcontainer.backup\..."
    Rename-Item ".devcontainer" ".devcontainer.backup"
}

New-Item -ItemType Directory -Path ".devcontainer" -Force | Out-Null
Write-Host "Downloading devcontainer.json..."

# PowerShell 5.1 may default to TLS 1.0, which GitHub rejects
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$downloaded = $false
try {
    Invoke-WebRequest -Uri $templateUrl -OutFile ".devcontainer\devcontainer.json" -UseBasicParsing -TimeoutSec 30
    $downloaded = ((Get-Item ".devcontainer\devcontainer.json").Length -gt 0)
} catch {
    $downloaded = $false
}
if (-not $downloaded) {
    Remove-Item ".devcontainer\devcontainer.json" -Force -ErrorAction SilentlyContinue
    Exit-DctInit 2 "ERR020" @(
        "Could not download devcontainer.json.",
        "",
        "Check that this PC is connected to the internet, then run this command again.")
}
Write-Host "Created .devcontainer\devcontainer.json"

# --- 4. VS Code: recommend and install the Dev Containers extension -------------------

$extFile = ".vscode\extensions.json"
New-Item -ItemType Directory -Path ".vscode" -Force | Out-Null
if (Test-Path $extFile) {
    $json = Get-Content $extFile -Raw | ConvertFrom-Json
    if (-not $json.recommendations) {
        $json | Add-Member -NotePropertyName recommendations -NotePropertyValue @($extId)
    } elseif ($json.recommendations -notcontains $extId) {
        $json.recommendations += $extId
    } else {
        $json = $null
    }
    if ($json) {
        $json | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
        Write-Host "Added the Dev Containers extension to $extFile"
    }
} else {
    @{ recommendations = @($extId) } | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
    Write-Host "Created $extFile"
}

$installed = Invoke-Native { & $codeCmd --list-extensions 2>$null }
if ($installed -contains $extId) {
    Write-Host "Dev Containers extension is already installed in VS Code"
} else {
    Write-Host "Installing the Dev Containers extension in VS Code..."
    Invoke-Native { & $codeCmd --install-extension $extId | Out-Host }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Dev Containers extension installed"
    } else {
        Write-Host "WARN030: Could not install the Dev Containers extension (code exit $LASTEXITCODE)." -ForegroundColor Yellow
        Write-Host "Open VS Code and accept its offer to install the recommended extensions."
    }
}

# --- 5. Download the image ------------------------------------------------------------

Write-Host ""
Write-Host "Downloading the DevContainer Toolbox image: $image"
Write-Host "(This may take a few minutes the first time...)"
Invoke-Native { docker pull $image }
if ($LASTEXITCODE -ne 0) {
    Exit-DctInit 2 "ERR022" @(
        "The DevContainer Toolbox image could not be downloaded.",
        "",
        "Check that this PC is connected to the internet and that Rancher Desktop is still running,",
        "then run this command again.")
}

# --- 6. Done --------------------------------------------------------------------------

Write-Host ""
Write-Host "This folder is ready for DevContainer Toolbox." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open this folder in VS Code:  code ."
Write-Host "  2. When VS Code asks, click 'Reopen in Container'"
Write-Host "     (or: Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
Write-Host "  3. Inside the container, run: dev-help"
if (Test-Path ".devcontainer.backup") {
    Write-Host ""
    Write-Host "Note: your previous .devcontainer\ was backed up to .devcontainer.backup\"
}
exit 0
