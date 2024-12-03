#!/bin/bash

# Configuration
DESKTOP_FILE_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$DESKTOP_FILE_DIR/bice-box.desktop"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_DESKTOP_FILE="$SCRIPT_DIR/autostart/bice-box.desktop"

# Create autostart directory if it doesn't exist
mkdir -p "$DESKTOP_FILE_DIR"

# Copy the desktop file
cp "$SOURCE_DESKTOP_FILE" "$DESKTOP_FILE"

# Make the desktop file executable
chmod +x "$DESKTOP_FILE"

echo ">> Autostart entry installed at: $DESKTOP_FILE" 