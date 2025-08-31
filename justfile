# Variables
flutter_bin := "flutter"
tdlib_path := "linux/lib/libtdjson.so"

# Default recipe
default:
    @just --list

# === Setup Commands ===

# Complete project setup (dependencies + TDLib)
setup: deps setup-tdlib-auto
    @echo "✓ Project setup complete!"
    @echo "You can now run: just run"

# Install Flutter dependencies
deps:
    @echo "📦 Installing Flutter dependencies..."
    {{flutter_bin}} pub get

# Automatically download and setup TDLib (recommended)
setup-tdlib-auto:
    @echo "🔧 Automatically setting up TDLib..."
    @just download-tdlib-npm

# Run original TDLib setup script (manual instructions)
setup-tdlib-manual:
    @echo "🔧 Running manual TDLib setup..."
    chmod +x setup_tdlib.sh
    ./setup_tdlib.sh

# Download TDLib using npm prebuilt-tdlib (recommended)
download-tdlib-npm:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📦 Downloading TDLib using npm prebuilt-tdlib..."
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo "❌ npm not found. Please install Node.js/npm first"
        echo "💡 Alternative: run 'just download-tdlib-direct' for direct download"
        exit 1
    fi
    
    # Create temporary directory
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    cd "$temp_dir"
    
    # Initialize npm project and install prebuilt-tdlib
    echo '{"name": "temp", "private": true}' > package.json
    npm install prebuilt-tdlib
    
    # Find the libtdjson.so file
    tdlib_file=$(find node_modules -name "libtdjson.so" | head -1)
    
    if [ -z "$tdlib_file" ]; then
        echo "❌ Could not find libtdjson.so in npm package"
        exit 1
    fi
    
    # Ensure target directory exists
    mkdir -p "{{justfile_directory()}}/linux/lib"
    
    # Copy the library
    cp "$tdlib_file" "{{justfile_directory()}}/{{tdlib_path}}"
    
    echo "✓ TDLib successfully downloaded to {{tdlib_path}}"
    echo "📋 Version info:"
    strings "{{justfile_directory()}}/{{tdlib_path}}" | grep -i "tdlib\|version" | head -3 || echo "  (version info not available)"

# Download TDLib directly from GitHub releases
download-tdlib-direct:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📦 Downloading TDLib directly from GitHub..."
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "❌ curl not found. Please install curl first"
        exit 1
    fi
    
    # Ensure target directory exists
    mkdir -p "{{justfile_directory()}}/linux/lib"
    
    # Try multiple sources
    echo "🔍 Trying tdlib-binaries (legacy)..."
    
    # Try Dropbox link first (more reliable)
    if curl -L -f -o "{{justfile_directory()}}/{{tdlib_path}}" \
        "https://www.dropbox.com/s/abyepz5ak48uecw/libtdjson.so?dl=1"; then
        echo "✓ TDLib downloaded from Dropbox"
        echo "⚠️  Note: This is TDLib v1.2.0 (older version)"
    else
        echo "❌ Direct download failed"
        echo "💡 Try: just download-tdlib-npm (recommended)"
        echo "💡 Or: just setup-tdlib-manual (manual instructions)"
        exit 1
    fi

# Build TDLib from source (advanced users)
build-tdlib-source:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔨 Building TDLib from source..."
    echo "⚠️  This will take 10-30 minutes and requires build tools"
    
    # Check for required tools
    missing_tools=()
    for tool in git cmake make gcc g++; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "❌ Missing required tools: ${missing_tools[*]}"
        echo "💡 Install with: sudo apt update && sudo apt install git cmake make build-essential"
        exit 1
    fi
    
    # Create build directory
    build_dir="{{justfile_directory()}}/tdlib_build"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Clone TDLib if not exists
    if [ ! -d "td" ]; then
        echo "📡 Cloning TDLib repository..."
        git clone https://github.com/tdlib/td.git
    fi
    
    cd td
    git pull
    
    # Build
    echo "🔨 Building TDLib..."
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    cmake --build . -j$(nproc)
    
    # Copy the built library
    mkdir -p "{{justfile_directory()}}/linux/lib"
    cp libtdjson.so "{{justfile_directory()}}/{{tdlib_path}}"
    
    echo "✓ TDLib built and installed successfully!"
    
    # Cleanup
    read -p "Remove build directory? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$build_dir"
        echo "🧹 Build directory cleaned"
    fi

# === Run Commands ===

# Run app in debug mode
run:
    @echo "🚀 Running Telegram Flutter Client..."
    {{flutter_bin}} run -d linux

# Run app in release mode
run-release:
    @echo "🚀 Running in release mode..."
    {{flutter_bin}} run -d linux --release

# Run on Linux specifically
run-linux: check-tdlib
    @echo "🐧 Running on Linux..."
    {{flutter_bin}} run -d linux

# === Build Commands ===

# Build for current platform
build:
    @echo "🔨 Building application..."
    {{flutter_bin}} build linux

# Build Linux release
build-linux:
    @echo "🐧 Building Linux release..."
    {{flutter_bin}} build linux --release

# Build Android APK
build-apk:
    @echo "🤖 Building Android APK..."
    {{flutter_bin}} build apk

# Build iOS (macOS only)
build-ios:
    @echo "🍎 Building iOS..."
    {{flutter_bin}} build ios

# === Development Commands ===

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    {{flutter_bin}} clean
    rm -rf build/

# Run Flutter analyzer
analyze:
    @echo "🔍 Running Flutter analyzer..."
    {{flutter_bin}} analyze

# Format code
format:
    @echo "✨ Formatting code..."
    dart format .

# Run tests
test:
    @echo "🧪 Running tests..."
    {{flutter_bin}} test

# Check Flutter environment
doctor:
    @echo "🩺 Checking Flutter environment..."
    {{flutter_bin}} doctor -v

# === Utility Commands ===

# Check if TDLib binary exists
check-tdlib:
    #!/usr/bin/env bash
    if [ ! -f "{{tdlib_path}}" ]; then
        echo "❌ TDLib binary not found at {{tdlib_path}}"
        echo "💡 Available setup options:"
        echo "   just setup-tdlib-auto    (recommended - uses npm)"
        echo "   just download-tdlib-direct (direct download)"
        echo "   just build-tdlib-source    (build from source)"
        echo "   just setup-tdlib-manual    (manual instructions)"
        exit 1
    else
        echo "✓ TDLib binary found at {{tdlib_path}}"
        # Show some info about the binary
        if command -v file &> /dev/null; then
            echo "📋 File info: $(file {{tdlib_path}})"
        fi
        if command -v ls &> /dev/null; then
            echo "📏 File size: $(ls -lh {{tdlib_path}} | awk '{print $5}')"
        fi
    fi

# Remove TDLib binary (for testing different versions)
clean-tdlib:
    @echo "🗑️  Removing TDLib binary..."
    rm -f {{tdlib_path}}
    @echo "✓ TDLib binary removed"

# Just get packages
pub-get:
    @echo "📦 Getting packages..."
    {{flutter_bin}} pub get

# Upgrade packages
pub-upgrade:
    @echo "⬆️  Upgrading packages..."
    {{flutter_bin}} pub upgrade

# Show project info
info:
    @echo "📋 Project Information:"
    @echo "  Name: Telegram Flutter Client"
    @echo "  Platform: Linux (primary)"
    @echo "  Flutter: $({{flutter_bin}} --version | head -1)"
    @echo "  TDLib: $(if [ -f {{tdlib_path}} ]; then echo 'Installed'; else echo 'Not installed'; fi)"

# Show TDLib setup help
help-tdlib:
    @echo "🔧 TDLib Setup Options:"
    @echo ""
    @echo "🚀 Quick Start:"
    @echo "  just setup                 - Complete setup (recommended)"
    @echo ""
    @echo "📦 TDLib Installation Methods:"
    @echo "  just setup-tdlib-auto      - Automatic download via npm (recommended)"
    @echo "  just download-tdlib-direct - Direct download from GitHub"
    @echo "  just build-tdlib-source    - Build from source (advanced)"
    @echo "  just setup-tdlib-manual    - Show manual instructions"
    @echo ""
    @echo "🔍 Utilities:"
    @echo "  just check-tdlib           - Verify TDLib installation"
    @echo "  just clean-tdlib           - Remove current TDLib binary"
    @echo ""
    @echo "💡 Recommended: Run 'just setup' for automatic setup"

# === Quick Development Workflow ===

# Quick check: format, analyze, test
check: format analyze test
    @echo "✅ All checks passed!"

# Development server with hot reload
dev: check-tdlib
    @echo "🔥 Starting development server with hot reload..."
    {{flutter_bin}} run -d linux --hot

# Full clean rebuild
rebuild: clean deps build
    @echo "🔄 Full rebuild complete!"