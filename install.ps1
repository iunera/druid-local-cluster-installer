<#
.SYNOPSIS
    Installs and starts the Druid local cluster.
.DESCRIPTION
    This script downloads the necessary configuration files for the Druid local cluster,
    checks for dependencies, and starts the services using Docker Compose.
#>

$GREEN = "`e[32m"
$RED = "`e[31m"
$BOLD = "`e[1m"
$NC = "`e[0m"

function Write-Log {
    param([string]$Message)
    Write-Host -ForegroundColor Green $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host -ForegroundColor Red $Message
}

function Die {
    param([string]$Message)
    Write-Err $Message
    exit 1
}

# Defaults
$DRUID_DIR = "$HOME\.druid-local-cluster"
$BASE_URL = "https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main"
$DOCKER_COMPOSE_URL = "$BASE_URL/docker-compose.yaml"
$COMMON_ENV_TEMPLATE_URL = "$BASE_URL/common.env_template"
$BASICAUTH_ENV_TEMPLATE_URL = "$BASE_URL/basicauth.env_template"
$ENVIRONMENT_URL = "$BASE_URL/environment"

Write-Host "

 ▄▄▄▄▄▄
 ██▀▀▀▀▀█   ▄▄▄     ▄▄▄    ▄▄▄▄▄▄   ▄█████▄   ███████
 ██        ████    ████   ██▀▀▀▀██  ▀ ▄▄▄██     ██
 ██▄▄▄▄▄█  ██ ██  ██ ██   ██    ██ ▄██▀▀▀██     ██
 ██        ██  ▀▄▀  ██   ██    ██ ██▄▄▄███     ██
 ▀▀▀▀▀▀▀   ▀▀       ▀▀   ▀▀▀▀▀▀▀▀  ▀▀▀▀ ▀▀      ▀▀

"

Write-Log "🚀 Welcome to the Druid Local Cluster Installer! 🚀"
Write-Info "This script will guide you through the setup process."



function Configure-EnvFile {
    param(
        [string]$TemplateFile,
        [string]$EnvFile
    )

    if (Test-Path -Path $EnvFile) {
        Write-Info "$EnvFile already exists, skipping configuration."
        return
    }

    Write-Info "Configuring $EnvFile..."
    $TempEnv = New-TemporaryFile
    $CommentBlock = ""

    Get-Content $TemplateFile | ForEach-Object {
        $Line = $_
        if ($Line -match "^\s*$") {
            Add-Content -Path $TempEnv -Value ""
            $CommentBlock = ""
        }
        elseif ($Line -match "^\#") {
            Add-Content -Path $TempEnv -Value $Line
            $CommentBlock += "$Line`n"
        }
        elseif ($Line -match "=") {
            $Key = $Line.Split("=")[0]
            $Value = $Line.Substring($Key.Length + 1)

            if (-not $Value) {
                $EnvValue = (Get-Item -Path "Env:$Key" -ErrorAction SilentlyContinue).Value
                if ($EnvValue) {
                    Add-Content -Path $TempEnv -Value "$Key=$EnvValue"
                }
                else {
                    if ($CommentBlock) {
                        Write-Host ""
                        $CommentBlock.Trim() -split "`n" | ForEach-Object {
                            $Rest = $_.Substring(1).Trim()
                            Write-Host "$BOLD#$NC$Rest"
                        }
                    }

                    while ($true) {
                        $UserValue = Read-Host -Prompt "$Key"

                        if ($UserValue) {
                            Add-Content -Path $TempEnv -Value "$Key=$UserValue"
                            break
                        }
                        else {
                            $Confirm = Read-Host -Prompt "Empty value — really save? (y/n)"
                            if ($Confirm -eq "y") {
                                Add-Content -Path $TempEnv -Value "$Key="
                                break
                            }
                        }
                    }
                }
            }
            else {
                Add-Content -Path $TempEnv -Value $Line
            }
            $CommentBlock = ""
        }
        else {
            Add-Content -Path $TempEnv -Value $Line
        }
    }

    Move-Item -Path $TempEnv -Destination $EnvFile -Force
    Write-Log "$EnvFile configured."
}


# Step 1: create directory
Write-Log "🔧 Step 1: Creating directory..."
Write-Info "We will create the $DRUID_DIR directory to store the configuration files."
if (-not (Test-Path -Path $DRUID_DIR)) {
    New-Item -ItemType Directory -Path $DRUID_DIR | Out-Null
}
Set-Location -Path $DRUID_DIR

# Record which env files already existed before we start creating any
foreach ($f in "common.env", "basicauth.env") {
    if (Test-Path -Path $f) {
        $resp = Read-Host -Prompt "Found existing $f. Do you want to recreate (overwrite) it? [y/N]"
        if ($resp -eq "y") {
            Write-Info "User chose to recreate $f — it will be overwritten."
            Remove-Item -Path $f -Force
        }
        else {
            Write-Info "Keeping existing $f — installer will skip configuring it."
        }
    }
}


# Step 2: Check dependencies
Write-Log "🔧 Step 2: Checking dependencies..."
$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    Die "docker could not be found, please install it first."
}

$dockerComposePath = Get-Command "docker-compose" -ErrorAction SilentlyContinue
if (-not $dockerComposePath) {
    $dockerComposePath = Get-Command "docker compose" -ErrorAction SilentlyContinue
    if (-not $dockerComposePath) {
        Die "'docker-compose' or 'docker compose' could not be found. It is required to run this script. Please ensure you have a recent Docker installation."
    }
}


# Step 3: Download configuration files
Write-Log "🔧 Step 3: Downloading configuration files..."
Write-Info "Downloading docker-compose.yaml"
try {
    Invoke-WebRequest -Uri $DOCKER_COMPOSE_URL -OutFile "docker-compose.yaml" -UseBasicParsing
} catch {
    Die "Failed to download docker-compose.yaml from $DOCKER_COMPOSE_URL"
}

Write-Info "Downloading common.env_template"
try {
    Invoke-WebRequest -Uri $COMMON_ENV_TEMPLATE_URL -OutFile "common.env_template" -UseBasicParsing
} catch {
    Die "Failed to download common.env_template from $COMMON_ENV_TEMPLATE_URL"
}

Write-Info "Downloading basicauth.env_template"
try {
    Invoke-WebRequest -Uri $BASICAUTH_ENV_TEMPLATE_URL -OutFile "basicauth.env_template" -UseBasicParsing
} catch {
    Die "Failed to download basicauth.env_template from $BASICAUTH_ENV_TEMPLATE_URL"
}

Write-Info "Downloading environment"
try {
    Invoke-WebRequest -Uri $ENVIRONMENT_URL -OutFile "environment" -UseBasicParsing
} catch {
    Die "Failed to download environment from $ENVIRONMENT_URL"
}

# Step 4: Configure environment files
Write-Log "🔧 Step 4: Configuring environment files..."
Configure-EnvFile -TemplateFile "common.env_template" -EnvFile "common.env"

# Ask about basic auth
if (-not (Test-Path -Path "basicauth.env")) {
    # File doesn't exist (it was never there, or user chose to recreate it).
    # Ask the user if they want to enable basic auth.
    $use_basic_auth = Read-Host -Prompt "Enable basic authentication? [y/N]"
    if ($use_basic_auth.ToLower() -eq "y") {
        Configure-EnvFile -TemplateFile "basicauth.env_template" -EnvFile "basicauth.env"
    }
    else {
        Write-Info "Basic authentication disabled. Creating empty basicauth.env."
        New-Item -ItemType File -Path "basicauth.env" | Out-Null
    }
}
else {
    # File exists, so user must have chosen to keep it.
    # Let Configure-EnvFile handle it (it will just skip).
    Configure-EnvFile -TemplateFile "basicauth.env_template" -EnvFile "basicauth.env"
}

Remove-Item -Path "common.env_template"
Remove-Item -Path "basicauth.env_template"


# Step 5: Start services
Write-Log "🔧 Step 5: Starting services..."
docker compose up -d

Write-Log "Services started in the background."
Write-Info "You can check the status with 'docker ps'."

Write-Log "✅ Installation complete!"
Write-Info "You can now access the Druid console at http://localhost:8888"

function Open-Browser {
    param([string]$URL)

    $WAIT_TIMEOUT = 120
    $WAIT_INTERVAL = 2
    $waited = 0

    Write-Info "Waiting for Druid to become available at $URL (timeout: $($WAIT_TIMEOUT)s)..."
    while ($waited -lt $WAIT_TIMEOUT) {
        try {
            $response = Invoke-WebRequest -Uri "$URL/status/health" -UseBasicParsing -TimeoutSec 1
            if ($response.StatusCode -eq 200) {
                Write-Log "Druid is up!"
                break
            }
        } catch {
            # Ignore exceptions
        }
        Start-Sleep -Seconds $WAIT_INTERVAL
        $waited += $WAIT_INTERVAL
    }

    if ($waited -ge $WAIT_TIMEOUT) {
        Write-Err "Druid did not become ready within $($WAIT_TIMEOUT)s. You may need to wait a bit longer."
    }

    Start-Process $URL
    Write-Log "Opening $URL in your default browser..."
}

Open-Browser "http://localhost:8888"
