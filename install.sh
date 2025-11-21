DRUID_DIR="$HOME/.druid-local-cluster"
BASE_URL="https://raw.githubusercontent.com/iunera/druid-local-cluster-installer/main"
DOCKER_COMPOSE_URL="$BASE_URL/docker-compose.yaml"
COMMON_ENV_TEMPLATE_URL="$BASE_URL/common.env_template"
BASICAUTH_ENV_TEMPLATE_URL="$BASE_URL/basicauth.env_template"
ENVIRONMENT_URL="$BASE_URL/environment"
TMP_FILES=""
CREATED_ENV_FILES=""
INSTALL_OK=0
EXISTING_ENV_FILES=""

log() { printf "%b\n" "${GREEN}$*${NC}"; }
info() { printf "%b\n" "$*"; }
err() { printf "%b\n" "${RED}$*${NC}" 1>&2; }
die() { err "$*"; exit 1; }

# Cleanup temporary files on exit and remove created env files on cancellation
cleanup() {
    # remove temp files
    for f in $TMP_FILES; do
        [ -n "$f" ] && [ -f "$f" ] && rm -f "$f" || true
    done

    # if installation didn't complete successfully, remove any env files we created
    if [ "$INSTALL_OK" -ne 1 ]; then
        for ef in $CREATED_ENV_FILES; do
            if [ -n "$ef" ] && [ -f "$ef" ]; then
                # only remove if it did NOT exist before the script started
                found=0
                for ex in $EXISTING_ENV_FILES; do
                    if [ "$ex" = "$ef" ]; then
                        found=1
                        break
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    info "Installation canceled — removing $ef"
                    rm -f "$ef" || true
                else
                    info "Installation canceled — leaving pre-existing $ef"
                fi
            fi
        done
    fi
}

cleanup_and_exit() {
    # accept optional exit code
    code=${1:-1}
    # disable EXIT trap to avoid double-running cleanup
    trap - EXIT
    cleanup
    exit $code
}

# Traps: on INT/TERM do cleanup_and_exit with appropriate codes; on EXIT do cleanup
trap 'cleanup_and_exit 130' INT
trap 'cleanup_and_exit 143' TERM
trap cleanup EXIT

# Parse args
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

usage() {
    info "Usage: $0"
    info "This script installs and starts the Druid local cluster."
}

log "🚀 Welcome to the Druid Local Cluster Installer! 🚀"
info "This script will guide you through the setup process."

# portable download helper: curl preferred, fallback to wget
download_file() {
    url=$1
    dest=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
        return $?
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
        return $?
    else
        return 2
    fi
}

ensure_dir() {
    dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}



configure_env_file() {
    TEMPLATE_FILE=$1
    ENV_FILE=$2

    if [ -f "$ENV_FILE" ]; then
        info "$ENV_FILE already exists, skipping configuration."
        return 0
    fi

    info "Configuring $ENV_FILE..."
    # We'll write to a temp file first
    TMP_ENV=$(mktemp)
    TMP_FILES="$TMP_FILES $TMP_ENV"

    comment_block=""
    while IFS= read -r line || [ -n "$line" ]; do
        # Preserve comment lines and accumulate contiguous comment lines to show before the next var prompt
        case "$line" in
            "" )
                # blank line
                printf "%s\n" "" >> "$TMP_ENV"
                comment_block=""
                ;;
            \#*)
                printf "%s\n" "$line" >> "$TMP_ENV"
                # append this comment line (strip trailing whitespace)
                clean=$(printf "%s" "$line" | sed 's/[[:space:]]*$//')
                comment_block="${comment_block}${clean}\n"
                ;;
            *"="*)
                # split on first '='
                key=$(printf "%s" "$line" | sed 's/=.*$//')
                value=$(printf "%s" "$line" | sed 's/^[^=]*=//')
                if [ -z "$value" ]; then
                    # If an environment variable with this key already exists, use it
                    env_value=$(printenv "$key" 2>/dev/null || true)
                     if [ -n "$env_value" ]; then
                        printf "%s=%s\n" "$key" "$env_value" >> "$TMP_ENV"
                    else
                        # interactive: show accumulated comment block (if any)
                        if [ -n "$comment_block" ]; then
                            printf "\n"
                            printf "%s" "$comment_block" | while IFS= read -r cline || [ -n "$cline" ]; do
                                # remove leading '# ' for rest part
                                rest=$(printf "%s" "$cline" | sed 's/^#[[:space:]]*//;s/[[:space:]]*$//')
                                printf "%b\n" "${BOLD}#${NC}${rest}"
                            done
                        fi

                        # prompt loop that trims input and confirms empty values
                        while :; do
                            printf "%s: " "$key"
                            read -r user_value < /dev/tty || user_value=""
                            # trim leading/trailing whitespace
                            user_value=$(printf "%s" "$user_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                            if [ -n "$user_value" ]; then
                                printf "%s=%s\n" "$key" "$user_value" >> "$TMP_ENV"
                                break
                            fi

                            # empty after trim -> ask for confirmation
                            printf "Empty value — really save? (y/n): "
                            # read confirm, trim and default to 'n' if empty
                            read -r confirm < /dev/tty || confirm=""
                            confirm=$(printf "%s" "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                            confirm=${confirm:-n}
                            if [ "$confirm" = "y" ]; then
                                printf "%s=\n" "$key" >> "$TMP_ENV"
                                break
                            fi
                            # otherwise, re-display comment block (if any) and prompt again
                            if [ -n "$comment_block" ]; then
                                printf "%s" "$comment_block" | while IFS= read -r cline || [ -n "$cline" ]; do
                                    rest=$(printf "%s" "$cline" | sed 's/^#[[:space:]]*//;s/[[:space:]]*$//')
                                    printf "%b\n" "${BOLD}#${NC}${rest}"
                                done
                            fi
                        done
                    fi
                else
                    # preserve the existing assignment line
                    printf "%s\n" "$line" >> "$TMP_ENV"
                fi
                comment_block=""
                ;;
            *)
                # unknown line, preserve
                printf "%s\n" "$line" >> "$TMP_ENV"
                ;;
        esac
    done < "$TEMPLATE_FILE"

    mv "$TMP_ENV" "$ENV_FILE"
    # remove from TMP_FILES list since moved to final location
    TMP_FILES=$(printf "%s" "$TMP_FILES" | sed "s# $TMP_ENV##g")
    CREATED_ENV_FILES="$CREATED_ENV_FILES $ENV_FILE"
    log "$ENV_FILE configured."
}


# Step 1: create directory
log "🔧 Step 1: Creating directory..."
info "We will create the $DRUID_DIR directory to store the configuration files."
ensure_dir "$DRUID_DIR"
cd "$DRUID_DIR" || die "Failed to enter directory $DRUID_DIR"

# Record which env files already existed before we start creating any
for f in common.env basicauth.env; do
    if [ -f "$f" ]; then
        EXISTING_ENV_FILES="$EXISTING_ENV_FILES $f"
        # Ask user whether to recreate (overwrite) or keep the existing file
        while :; do
            printf "Found existing %s. Do you want to recreate (overwrite) it? [y/N]: " "$f"
            # read resp, trim and default to 'n' when empty
            read -r resp < /dev/tty || resp=""
            # trim whitespace
            resp=$(printf "%s" "$resp" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            resp=${resp:-n}
            case "$resp" in
                y|Y)
                    info "User chose to recreate $f — it will be overwritten."
                    # remove the existing file so configure_env_file will create a fresh one
                    rm -f "$f" || true
                    break
                    ;;
                *)
                    info "Keeping existing $f — installer will skip configuring it."
                    break
                    ;;
            esac
        done
    fi
done


# Step 2: Check dependencies
log "🔧 Step 2: Checking dependencies..."
if ! command -v docker >/dev/null 2>&1; then
    die "docker could not be found, please install it first."
fi

DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    info "Could not connect to Docker as current user. Attempting to use 'sudo' for Docker commands (you may be prompted)."
    if ! sudo docker ps >/dev/null 2>&1; then
        die "Failed to run docker (even with sudo). Please check your docker installation and permissions."
    fi
    DOCKER_CMD="sudo docker"
fi

if ! $DOCKER_CMD compose version >/dev/null 2>&1; then
    die "'docker compose' could not be found. It is required to run this script. Please ensure you have a recent Docker installation."
fi

# Step 3: Download configuration files
log "🔧 Step 3: Downloading configuration files..."
info "Downloading docker-compose.yaml"
if ! download_file "$DOCKER_COMPOSE_URL" "docker-compose.yaml"; then
    die "Failed to download docker-compose.yaml from $DOCKER_COMPOSE_URL"
fi
info "Downloading common.env_template"
if ! download_file "$COMMON_ENV_TEMPLATE_URL" "common.env_template"; then
    die "Failed to download common.env_template from $COMMON_ENV_TEMPLATE_URL"
fi
info "Downloading basicauth.env_template"
if ! download_file "$BASICAUTH_ENV_TEMPLATE_URL" "basicauth.env_template"; then
    die "Failed to download basicauth.env_template from $BASICAUTH_ENV_TEMPLATE_URL"
fi
info "Downloading environment"
if ! download_file "$ENVIRONMENT_URL" "environment"; then
    die "Failed to download environment from $ENVIRONMENT_URL"
fi

# Step 4: Configure environment files
log "🔧 Step 4: Configuring environment files..."
configure_env_file common.env_template common.env

# Ask about basic auth
if [ ! -f "basicauth.env" ]; then
    # File doesn't exist (it was never there, or user chose to recreate it).
    # Ask the user if they want to enable basic auth.
    printf "Enable basic authentication? [y/N]: "
    read -r resp < /dev/tty || resp=""
    resp=$(printf "%s" "$resp" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    use_basic_auth=${resp:-n}

    case "$use_basic_auth" in
        y|Y)
            configure_env_file basicauth.env_template basicauth.env
            ;;
        *)
            info "Basic authentication disabled. Creating empty basicauth.env."
            touch basicauth.env || true
            CREATED_ENV_FILES="$CREATED_ENV_FILES basicauth.env"
            ;;
    esac
else
    # File exists, so user must have chosen to keep it.
    # Let configure_env_file handle it (it will just skip).
    configure_env_file basicauth.env_template basicauth.env
fi

# remove templates
rm -f common.env_template basicauth.env_template

# Step 5: Start services
log "🔧 Step 5: Starting services..."
$DOCKER_CMD compose up -d

log "Services started in the background."
info "You can check the status with '$DOCKER_CMD ps'."

log "✅ Installation complete!"
info "You can now access the Druid console at http://localhost:8888"

open_browser() {
    URL=$1

    # Wait for backend to be ready before opening the browser
    # Try for up to 120 seconds
    WAIT_TIMEOUT=120
    WAIT_INTERVAL=2
    waited=0

    info "Waiting for Druid to become available at $URL (timeout: ${WAIT_TIMEOUT}s)..."
    while [ $waited -lt $WAIT_TIMEOUT ]; do
        if command -v curl >/dev/null 2>&1; then
            if curl -fsS -o /dev/null "$URL/status/health" >/dev/null 2>&1; then
                log "Druid is up!"
                break
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --spider "$URL/status/health" >/dev/null 2>&1; then
                log "Druid is up!"
                break
            fi
        else
            # Neither curl nor wget available; do a simple grace wait once
            if [ $waited -eq 0 ]; then
                info "curl/wget not found — waiting 10s before opening the browser..."
            fi
            sleep 10 || true
            waited=$((waited + 10))
            break
        fi
        sleep $WAIT_INTERVAL || true
        waited=$((waited + WAIT_INTERVAL))
    done

    if [ $waited -ge $WAIT_TIMEOUT ]; then
        err "Druid did not become ready within ${WAIT_TIMEOUT}s. You may need to wait a bit longer."
    fi

    OS=$(uname -s)
    case "$OS" in
        Linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL" >/dev/null 2>&1 &
                log "Opening $URL in your default browser..."
            else
                info "Could not find xdg-open. Please open $URL manually."
            fi
            ;;
        Darwin)
            open "$URL" >/dev/null 2>&1 &
            log "Opening $URL in your default browser..."
            ;;
        *)
            info "Unsupported OS for automatic browser opening. Please open $URL manually."
            ;;
    esac
}

open_browser "http://localhost:8888"

INSTALL_OK=1
