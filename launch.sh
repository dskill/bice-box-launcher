#!/bin/bash

# ASCII Art Banner
echo "
██████╗ ██╗ ██████╗███████╗    ██████╗  ██████╗ ██╗  ██╗
██╔══██╗██║██╔════╝██╔════╝    ██╔══██╗██╔═══██╗╚██╗██╔╝
██████╔╝██║██║     █████╗      ██████╔╝██║   ██║ ╚███╔╝ 
██╔══██╗██║██║     ██╔══╝      ██╔══██╗██║   ██║ ██╔██╗ 
██████╔╝██║╚██████╗███████╗    ██████╔╝╚██████╔╝██╔╝ ██╗
╚═════╝ ╚═╝ ╚═════╝╚══════╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
"

# Add after the ASCII banner
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --update-only    Install/update without running the application"
    echo "  -h, --help           Show this help message"
    exit 0
fi

# Configuration
APP_NAME="bice-box"
GITHUB_REPO="dskill/bice-box"
INSTALL_DIR="$HOME/$APP_NAME"

# Add command line argument parsing
RUN_AFTER_INSTALL=true
while getopts "u-:" flag; do
    case "${flag}" in
        u) RUN_AFTER_INSTALL=false ;;
        -) case "${OPTARG}" in
               update-only) RUN_AFTER_INSTALL=false ;;
               *) echo "Invalid option: --${OPTARG}" >&2; exit 1 ;;
           esac ;;
    esac
done

echo ">> Installing $APP_NAME..."

# Function to check internet connectivity
check_internet() {
    # Try to ping GitHub (or any reliable host)
    if ping -c 1 github.com >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wait for internet connectivity (max 10 seconds)
echo ">> Checking internet connectivity..."
RETRY_COUNT=0
MAX_RETRIES=2  # 2 retries * 5 seconds = 10 seconds total
while ! check_internet; do
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "!! Error: No internet connection after 60 seconds"
        exit 1
    fi
    echo ">> Waiting for internet connection... ($(( MAX_RETRIES - RETRY_COUNT )) attempts remaining)"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

# Add git update check after internet check
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo ">> Checking for script updates..."
    cd "$SCRIPT_DIR"
    
    # Fetch latest changes
    git fetch origin main
    
    # Compare local and remote versions
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo ">> Update available, pulling changes..."
        git pull origin main
        
        # Make launcher executable
        chmod +x "$0"
        
        echo ">> Relaunching updated script..."
        exec "$0" "$@"
        exit 0
    else
        echo ">> Script is up to date"
    fi
fi

# Add effects repo sync
EFFECTS_DIR="$HOME/bice-box-effects"
if [ -d "$EFFECTS_DIR/.git" ]; then
    echo ">> Checking for effects updates..."
    cd "$EFFECTS_DIR"
    git fetch origin main
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo ">> Effects updates available, pulling changes..."
        git pull origin main
    else
        echo ">> Effects are up to date"
    fi
else
    echo ">> Cloning effects repository..."
    git clone https://github.com/dskill/bice-box-effects.git "$EFFECTS_DIR"
fi

# Detect OS and Architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Determine which build to download
case "$OS" in
    "Darwin")
        if [ "$ARCH" = "arm64" ]; then
            echo ">> Detected Mac ARM64 (Apple Silicon)"
            echo "!! Please download the DMG manually from: https://github.com/$GITHUB_REPO/releases"
            exit 1
        else
            echo "!! This application only supports Apple Silicon Macs"
            exit 1
        fi
        ;;
    "Linux")
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            BUILD_SUFFIX="-arm64.zip"
            echo ">> Detected Linux ARM64 (Raspberry Pi)"
        else
            echo "!! This application only supports Raspberry Pi (ARM64)"
            exit 1
        fi
        ;;
    *)
        echo "!! Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Function to compare version strings
version_compare() {
    if [[ $1 == $2 ]]; then
        echo "equal"
    else
        if [[ $1 = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]]; then
            echo "smaller"
        else
            echo "greater"
        fi
    fi
}

# Check if app is already installed and get current version
CURRENT_VERSION=""
if [ -f "$INSTALL_DIR/$APP_NAME" ]; then
    CURRENT_VERSION=$("$INSTALL_DIR/$APP_NAME" --version 2>/dev/null || echo "")
    echo ">> Current version: ${CURRENT_VERSION:-unknown}"
fi

# Get the latest release version
echo ">> Checking for latest version..."
if command -v jq >/dev/null 2>&1; then
    RESPONSE=$(curl -sL https://api.github.com/repos/$GITHUB_REPO/releases/latest)
    if [[ $RESPONSE == *"API rate limit exceeded"* ]]; then
        echo "!! GitHub API rate limit exceeded. Using alternative method..."
        LATEST_VERSION=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/$GITHUB_REPO/releases/latest" | grep -o '[^/]*$')
    else
        LATEST_VERSION=$(echo "$RESPONSE" | jq -r .tag_name)
    fi
else
    LATEST_VERSION=$(curl -sL -o /dev/null -w '%{url_effective}' "https://github.com/$GITHUB_REPO/releases/latest" | grep -o '[^/]*$')
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "!! Error: Could not fetch latest version"
    exit 1
fi

echo ">> Latest version: $LATEST_VERSION"
echo ">> Debug: Version without 'v' prefix: ${LATEST_VERSION#v}"
echo ">> Debug: Build suffix: $BUILD_SUFFIX"

# Compare versions and decide whether to update
if [ ! -z "$CURRENT_VERSION" ]; then
    COMPARE_RESULT=$(version_compare "${CURRENT_VERSION#v}" "${LATEST_VERSION#v}")
    if [ "$COMPARE_RESULT" = "equal" ]; then
        echo ">> You already have the latest version installed!"
        if [ "$RUN_AFTER_INSTALL" = true ]; then
            echo "[INFO] Starting $APP_NAME..."
            "$INSTALL_DIR/$APP_NAME"
        else
            echo "[INFO] Installation complete. Use '$INSTALL_DIR/$APP_NAME' to run the application."
        fi
        exit 0
    elif [ "$COMPARE_RESULT" = "greater" ]; then
        echo "!! Your installed version is newer than the latest release"
        if [ "$RUN_AFTER_INSTALL" = true ]; then
            echo "[INFO] Starting $APP_NAME..."
            "$INSTALL_DIR/$APP_NAME"
        else
            echo "[INFO] Installation complete. Use '$INSTALL_DIR/$APP_NAME' to run the application."
        fi
        exit 0
    fi
    echo ">> Updating to newer version..."
else
    echo ">> Installing new version..."
fi

echo ">> Downloading version $LATEST_VERSION..."

# Download the appropriate file
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_VERSION/$APP_NAME-${LATEST_VERSION#v}$BUILD_SUFFIX"
echo ">> Debug: Download URL: $DOWNLOAD_URL"
TMP_FILE="/tmp/$APP_NAME$BUILD_SUFFIX"

curl -L $DOWNLOAD_URL -o "$TMP_FILE"

if [ ! -f "$TMP_FILE" ]; then
    echo "!! Error: Download failed"
    exit 1
fi

# Create installation directory
echo ">> Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Unzip the application
echo ">> Extracting files..."
unzip -o "$TMP_FILE" -d "$INSTALL_DIR"

# Clean up
echo ">> Cleaning up..."
rm "$TMP_FILE"

echo "[INFO] Installation complete! You can find $APP_NAME in $INSTALL_DIR"
if [ "$RUN_AFTER_INSTALL" = true ]; then
    echo "[INFO] Starting $APP_NAME..."
    "$INSTALL_DIR/$APP_NAME"
else
    echo "[INFO] Installation complete. Use '$INSTALL_DIR/$APP_NAME' to run the application."
fi 