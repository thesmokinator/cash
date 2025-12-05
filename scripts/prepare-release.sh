#!/bin/bash
# Script to convert Developer ID certificate to base64 for GitHub Secrets

set -e

echo "=== Developer ID Certificate Preparation for GitHub Secrets ==="
echo ""
echo "This script converts your Developer ID certificate to base64"
echo "to use as a GitHub Secret."
echo ""

# Check for Developer ID Installer P12 certificate file
CERT_FILE="developer-id-installer.p12"
if [ ! -f "$CERT_FILE" ]; then
    echo "Error: $CERT_FILE not found in project root"
    echo ""
    echo "To generate it, run:"
    echo "  security export -k login.keychain -t identities -f pkcs12 -o $CERT_FILE \"Developer ID Installer: Michele Broggi (932KJJ3UZK)\""
    exit 1
fi

echo "Found certificate file: $CERT_FILE"

# Convert to base64
echo ""
echo "Converting certificate to base64..."
CERT_BASE64=$(base64 < "$CERT_FILE")

echo ""
echo "=== Secrets to add to GitHub ==="
echo ""
echo "1. Go to https://github.com/michelebroggi/cash/settings/secrets/actions"
echo ""
echo "2. Add the following secrets:"
echo ""
echo "Name: BUILD_CERTIFICATE_BASE64"
echo "Value:"
echo "$CERT_BASE64"
echo ""
echo "Name: P12_PASSWORD"
echo "Value: (your P12 certificate password)"
echo ""
echo "Name: KEYCHAIN_PASSWORD"
echo "Value: (arbitrary password for temporary keychain, e.g., 'build123')"
echo ""
echo "Name: APPLE_ID"
echo "Value: (your Apple ID for notarization)"
echo ""
echo "Name: APPLE_ID_PASSWORD"
echo "Value: (Apple ID password or app-specific password)"
echo ""
echo "Name: TEAM_ID"
echo "Value: 932KJJ3UZK"
echo ""
echo "Name: DEVELOPER_ID"
echo "Value: Developer ID Installer: Michele Broggi (932KJJ3UZK)"
echo ""


echo ""
echo "After adding the secrets, you can:"
echo ""
echo "1. Create a release by pushing a tag:"
echo "   git tag v1.0.0"
echo "   git push origin v1.0.0"
echo ""
echo "2. Or manually run the workflow from GitHub Actions"
