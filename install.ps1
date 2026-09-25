# install.ps1 - First-time install of devcontainer-toolbox (image mode)
# Run with: irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex
# If blocked: powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/helpers-no/devcontainer-toolbox/main/install.ps1 | iex"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "helpers-no/devcontainer-toolbox"
$image = "ghcr.io/${repo}:latest"
$templateUrl = "https://raw.githubusercontent.com/$repo/main/devcontainer-user-template.json"

Write-Host "Installing devcontainer-toolbox from $repo..."
Write-Host ""

# --- 1. Check Docker is available ------------------------------------------------

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Rancher Desktop from: https://rancherdesktop.io/"
    Write-Host "Then run this script again."
    exit 1
}

# --- 2. Backup existing .devcontainer/ -------------------------------------------

if (Test-Path ".devcontainer") {
    Write-Host "Found existing .devcontainer/ directory."
    Write-Host "Creating backup at .devcontainer.backup/..."
    if (Test-Path ".devcontainer.backup") {
        Remove-Item ".devcontainer.backup" -Recurse -Force
    }
    Rename-Item ".devcontainer" ".devcontainer.backup"
    Write-Host "Backup created."
    Write-Host ""
}

# --- 3. Download devcontainer-user-template.json ----------------------------------

New-Item -ItemType Directory -Path ".devcontainer" -Force | Out-Null

Write-Host "Downloading devcontainer.json from $templateUrl..."

# PowerShell 5.1 may default to TLS 1.0 which GitHub rejects
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Invoke-WebRequest -Uri $templateUrl -OutFile ".devcontainer/devcontainer.json" -UseBasicParsing -TimeoutSec 30
}
catch {
    Write-Host "Error: Failed to download devcontainer-user-template.json" -ForegroundColor Red
    Write-Host "URL: $templateUrl"
    Write-Host "$_"
    exit 1
}

$fileSize = (Get-Item ".devcontainer/devcontainer.json").Length
if ($fileSize -eq 0) {
    Write-Host "Error: Downloaded file is empty" -ForegroundColor Red
    Remove-Item ".devcontainer/devcontainer.json" -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Created .devcontainer/devcontainer.json ($fileSize bytes)"

# --- 4. Ensure .vscode/extensions.json recommends Dev Containers ------------------

$extId = "ms-vscode-remote.remote-containers"
$extFile = ".vscode\extensions.json"

New-Item -ItemType Directory -Path ".vscode" -Force | Out-Null

if (Test-Path $extFile) {
    $json = Get-Content $extFile -Raw | ConvertFrom-Json
    if (-not $json.recommendations) {
        $json | Add-Member -NotePropertyName recommendations -NotePropertyValue @($extId)
    } elseif ($json.recommendations -notcontains $extId) {
        $json.recommendations += $extId
    } else {
        Write-Host "Dev Containers extension already in $extFile"
        $json = $null
    }
    if ($json) {
        $json | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
        Write-Host "Added Dev Containers extension to $extFile"
    }
} else {
    @{ recommendations = @($extId) } | ConvertTo-Json -Depth 10 | Set-Content $extFile -Encoding UTF8
    Write-Host "Created $extFile with Dev Containers extension recommendation"
}

# --- 4b. Install the Dev Containers extension in VS Code ---------------------------
# Per user, no admin. VS Code itself comes from Intune (Company Portal) or the user's own
# install, so `code` may not be on PATH yet: also look in the user and system install folders.

$codeCmd = $null
$codeOnPath = Get-Command code -ErrorAction SilentlyContinue
if ($codeOnPath) {
    $codeCmd = $codeOnPath.Source
} else {
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )) {
        if (Test-Path $candidate) { $codeCmd = $candidate; break }
    }
}

Write-Host ""
if (-not $codeCmd) {
    Write-Host "VS Code was not found on this PC, so the Dev Containers extension could not be installed." -ForegroundColor Yellow
    Write-Host "Install VS Code (on a work PC: from Company Portal), then run this again."
} else {
    # Native commands write progress to stderr; keep that from being treated as a script error.
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $installed = & $codeCmd --list-extensions 2>$null
    if ($installed -contains $extId) {
        Write-Host "Dev Containers extension is already installed in VS Code"
    } else {
        Write-Host "Installing the Dev Containers extension in VS Code..."
        & $codeCmd --install-extension $extId | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Dev Containers extension installed"
        } else {
            Write-Host "Could not install the Dev Containers extension (code exit $LASTEXITCODE)." -ForegroundColor Yellow
            Write-Host "Open VS Code and accept its offer to install the recommended extensions."
        }
    }
    $ErrorActionPreference = $prevPref
}

# --- 5. Pull the Docker image -----------------------------------------------------

Write-Host ""
Write-Host "Pulling container image: $image"
Write-Host "(This may take a few minutes on first install...)"
docker pull $image

# --- 6. Print next steps ----------------------------------------------------------

Write-Host ""
Write-Host "devcontainer-toolbox installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open this folder in VS Code"
Write-Host "  2. When prompted, click 'Reopen in Container'"
Write-Host "     (or run: Cmd/Ctrl+Shift+P > 'Dev Containers: Reopen in Container')"
Write-Host "  3. Inside the container, run: dev-help"
Write-Host ""

if (Test-Path ".devcontainer.backup") {
    Write-Host "Note: Your previous .devcontainer/ was backed up to .devcontainer.backup/"
    Write-Host ""
}
