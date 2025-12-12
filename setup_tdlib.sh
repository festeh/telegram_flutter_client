#!/bin/bash

# Setup script for TDLib on Linux
# TDLib version: 1.8.58 (Dec 2025)

set -e

TDLIB_VERSION="1.8.58"
GITHUB_RELEASE="https://github.com/ForNeVeR/tdlib.native/releases/download/v${TDLIB_VERSION}"

echo "=== TDLib Setup for Linux ==="
echo ""

# Create lib directory
mkdir -p linux/lib

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        DOWNLOAD_URL="${GITHUB_RELEASE}/tdlib.native.linux-x64.${TDLIB_VERSION}.nupkg"
        ;;
    aarch64)
        DOWNLOAD_URL="${GITHUB_RELEASE}/tdlib.native.linux-arm64.${TDLIB_VERSION}.nupkg"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        echo "Please build TDLib from source: https://tdlib.github.io/td/build.html"
        exit 1
        ;;
esac

download_tdlib() {
    echo "Downloading TDLib ${TDLIB_VERSION} for Linux ${ARCH}..."

    # Check for required tools
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "Error: curl or wget is required. Install with: sudo apt install curl"
        exit 1
    fi

    if ! command -v unzip &> /dev/null; then
        echo "Error: unzip is required. Install with: sudo apt install unzip"
        exit 1
    fi

    TEMP_DIR=$(mktemp -d)
    TEMP_FILE="${TEMP_DIR}/tdlib.nupkg"

    echo "Downloading from: ${DOWNLOAD_URL}"

    if command -v curl &> /dev/null; then
        curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL"
    else
        wget -O "$TEMP_FILE" "$DOWNLOAD_URL"
    fi

    # Verify download
    FILE_SIZE=$(stat -c%s "$TEMP_FILE" 2>/dev/null || stat -f%z "$TEMP_FILE" 2>/dev/null)
    if [ "$FILE_SIZE" -lt 1000000 ]; then
        echo "Error: Downloaded file is too small (${FILE_SIZE} bytes). Download may have failed."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    echo "Extracting (${FILE_SIZE} bytes)..."
    # nupkg files are just zip files
    unzip -q "$TEMP_FILE" -d "$TEMP_DIR"

    # Find and copy the library
    FOUND_LIB=""
    for path in \
        "${TEMP_DIR}/runtimes/linux-x64/native/libtdjson.so" \
        "${TEMP_DIR}/runtimes/linux-arm64/native/libtdjson.so" \
        "${TEMP_DIR}/libtdjson.so"; do
        if [ -f "$path" ]; then
            FOUND_LIB="$path"
            break
        fi
    done

    if [ -n "$FOUND_LIB" ]; then
        cp "$FOUND_LIB" linux/lib/
        chmod +x linux/lib/libtdjson.so
        echo "Installed libtdjson.so to linux/lib/"
    else
        echo "Error: Could not find libtdjson.so in archive"
        echo "Archive contents:"
        find "$TEMP_DIR" -name "*.so" -o -name "libtd*" 2>/dev/null || ls -laR "$TEMP_DIR"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    rm -rf "$TEMP_DIR"
    echo ""
    echo "TDLib ${TDLIB_VERSION} installed successfully!"
}

# Check current state
if [ -f "linux/lib/libtdjson.so" ]; then
    CURRENT_SIZE=$(stat -c%s "linux/lib/libtdjson.so" 2>/dev/null || stat -f%z "linux/lib/libtdjson.so" 2>/dev/null)
    echo "Existing TDLib binary found (${CURRENT_SIZE} bytes)"
    echo ""
    read -p "Replace with version ${TDLIB_VERSION}? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        download_tdlib
    else
        echo "Keeping existing binary."
    fi
else
    echo "TDLib binary not found."
    read -p "Download TDLib ${TDLIB_VERSION}? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        download_tdlib
    fi
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Ensure you have a .env file with your API credentials:"
echo "   cp .env.example .env"
echo "   # Edit .env with your credentials from https://my.telegram.org/apps"
echo ""
echo "2. Run the app:"
echo "   flutter run -d linux"
echo ""
