#!/usr/bin/env bash
# ==============================================================================
# WriteScan AI - Android Release Keystore Generator Helper
# This script generates a production JKS keystore and prints the base64 string
# for adding directly into GitHub Repository Secrets (KEYSTORE_BASE64).
# ==============================================================================

set -e

KEYSTORE_DIR="./android/app"
KEYSTORE_FILE="$KEYSTORE_DIR/upload-keystore.jks"
KEY_ALIAS="upload"

echo "========================================================"
echo "  WriteScan AI - Android Release Keystore Generator    "
echo "========================================================"

mkdir -p "$KEYSTORE_DIR"

if [ -f "$KEYSTORE_FILE" ]; then
    echo "Warning: Keystore already exists at $KEYSTORE_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    rm "$KEYSTORE_FILE"
fi

echo "Enter a secure Keystore & Key password (min 6 characters):"
read -s -p "Password: " KEY_PASSWORD
echo
if [ ${#KEY_PASSWORD} -lt 6 ]; then
    echo "Error: Password must be at least 6 characters long."
    exit 1
fi

echo "Generating JKS keystore..."
keytool -genkeypair -v \
  -keystore "$KEYSTORE_FILE" \
  -storepass "$KEY_PASSWORD" \
  -alias "$KEY_ALIAS" \
  -keypass "$KEY_PASSWORD" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=WriteScan AI, OU=Mobile, O=WriteScan, L=Bengaluru, ST=Karnataka, C=IN"

echo "Keystore successfully generated at: $KEYSTORE_FILE"
echo ""

# Write local key.properties
cat <<EOF > ./android/key.properties
storePassword=$KEY_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF

echo "Created ./android/key.properties for local builds."
echo ""
echo "========================================================"
echo "       GitHub Actions Secrets Configuration Guide       "
echo "========================================================"
echo "Go to your GitHub Repository -> Settings -> Secrets and variables -> Actions"
echo "Add the following 4 repository secrets:"
echo ""
echo "1. KEY_ALIAS:"
echo "   $KEY_ALIAS"
echo ""
echo "2. KEY_PASSWORD:"
echo "   $KEY_PASSWORD"
echo ""
echo "3. KEYSTORE_PASSWORD:"
echo "   $KEY_PASSWORD"
echo ""
echo "4. KEYSTORE_BASE64 (Copy the entire base64 string below):"
echo "--------------------------------------------------------"
if command -v base64 >/dev/null 2>&1; then
    base64 -w 0 "$KEYSTORE_FILE" 2>/dev/null || base64 "$KEYSTORE_FILE"
else
    openssl base64 -in "$KEYSTORE_FILE" | tr -d '\n'
fi
echo ""
echo "--------------------------------------------------------"
echo "Setup complete! You can now push to GitHub to trigger automated signed APK builds."
