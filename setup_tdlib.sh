#!/bin/bash

# Setup script for TDLib on Linux

echo "Setting up TDLib for Linux..."

# Create lib directory
mkdir -p linux/lib

# Download TDLib binary for Linux
# Note: You'll need to get this from the official TDLib builds or compile yourself
# For demo purposes, we'll create a placeholder script

echo "=== TDLib Setup Instructions ==="
echo ""
echo "To complete the setup, you need to obtain the TDLib binary (libtdjson.so)"
echo "for Linux. Here are your options:"
echo ""
echo "1. Download from official TDLib releases:"
echo "   https://github.com/tdlib/td"
echo ""
echo "2. Build from source following TDLib documentation:"
echo "   https://tdlib.github.io/td/build.html"
echo ""
echo "3. For testing, you can download prebuilt binaries from:"
echo "   https://core.telegram.org/tdlib/getting-started"
echo ""
echo "Once you have libtdjson.so, place it in: linux/lib/libtdjson.so"
echo ""
echo "=== Required API Credentials ==="
echo ""
echo "You'll also need to obtain your own API credentials:"
echo "1. Go to https://my.telegram.org/apps"
echo "2. Create a new application"
echo "3. Note down your api_id and api_hash"
echo "4. Update the values in lib/core/tdlib_client.dart:"
echo "   - Replace the test API ID (94575) with your api_id"
echo "   - Replace the test API hash with your api_hash"
echo ""
echo "=== Important Notes ==="
echo "- The current test credentials are for development only"
echo "- Use Gateway API for production to get codes via Telegram instead of SMS"
echo "- Make sure to keep your API credentials secure"
echo ""

# Check if the binary exists
if [ -f "linux/lib/libtdjson.so" ]; then
    echo "✓ TDLib binary found at linux/lib/libtdjson.so"
else
    echo "⚠ TDLib binary not found. Please follow the instructions above."
    echo ""
    echo "For quick testing, you can try downloading a prebuilt version:"
    echo "curl -L -o linux/lib/libtdjson.so 'https://example.com/libtdjson.so'"
    echo "(Replace the URL with an actual TDLib download link)"
fi

echo ""
echo "Setup complete! Run 'flutter run -d linux' to test the application."