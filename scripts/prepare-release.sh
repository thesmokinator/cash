#!/bin/bash
# Script to convert Developer ID certificate to base64 for GitHub Secrets

set -e

echo "=== Developer ID Certificate Preparation for GitHub Secrets ==="
echo ""
echo "This script converts your Developer ID certificate to base64"
echo "to use as a GitHub Secret."
echo ""

# Find Developer ID certificate in Keychain
echo "Looking for Developer ID certificate in Keychain..."
security find-certificate -c "Developer ID Application" -p > /tmp/cert.p12 2>/dev/null || {
    echo "Error: Developer ID certificate not found in Keychain"
    echo ""
    echo "Make sure you have the certificate imported in Keychain."
    exit 1
}

# Convert to base64
echo ""
echo "Converting certificate to base64..."
CERT_BASE64=$(openssl pkcs12 -in /tmp/cert.p12 -clcerts -nokeys -passin pass: 2>/dev/null | base64)

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
echo "Value: (Common Name of the certificate, e.g., 'Developer ID Application: Michele Broggi (932KJJ3UZK)')"
echo ""

# Cleanup
rm -f /tmp/cert.p12

echo "=== Setup Complete ==="
echo ""
echo "After adding the secrets, you can:"
echo ""
echo "1. Create a release by pushing a tag:"
echo "   git tag v1.0.0"
echo "   git push origin v1.0.0"
echo ""
echo "2. Or manually run the workflow from GitHub Actions"
