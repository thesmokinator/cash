# macOS Distribution Outside App Store

This guide explains how to build and distribute the Cash app signed with Developer ID Installer certificate directly from GitHub.

## Prerequisites

- Developer ID Installer certificate on your Mac
- Apple ID with two-factor authentication
- GitHub repository

## Initial Setup

### 1. Prepare GitHub Secrets

Run the preparation script:

```bash
./scripts/prepare-release.sh
```

This script will show you the values to add as GitHub Secrets.

### 2. Add Secrets to Your Repository

Go to: `https://github.com/michelebroggi/cash/settings/secrets/actions`

Add the following secrets:

| Secret | Value | Description |
|--------|-------|-------------|
| `BUILD_CERTIFICATE_BASE64` | Certificate in base64 | Developer ID certificate (see script output) |
| `P12_PASSWORD` | Certificate password | Password for the P12 file |
| `KEYCHAIN_PASSWORD` | Arbitrary password | For the temporary keychain (e.g., build123) |
| `APPLE_ID` | your@email.com | Apple ID for notarization |
| `APPLE_ID_PASSWORD` | Password or app-specific | Apple ID password |
| `TEAM_ID` | 932KJJ3UZK | Apple Team ID |
| `DEVELOPER_ID` | Certificate Common Name | E.g., "Developer ID Application: Michele Broggi (932KJJ3UZK)" |

## How to Release

### Option 1: Using Git Tags (Recommended)

```bash
# Create a tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push the tag
git push origin v1.0.0
```

GitHub Actions will automatically compile and create the release with the DMG.

### Option 2: Manual Workflow Trigger

Go to: `https://github.com/michelebroggi/cash/actions/workflows/build-and-release.yml`

Click "Run workflow" and select the branch.

## Build Process

1. **Compilation**: Xcode compiles the app in Release configuration
2. **Code Signing**: App is signed with Developer ID
3. **DMG Creation**: App is packaged into a DMG
4. **Notarization**: Apple verifies the DMG (requires Apple ID)
5. **Stapling**: Notarization is attached to the DMG
6. **Release**: DMG is uploaded to GitHub Releases

## Configuration Files

- `.github/workflows/build-and-release.yml` - GitHub Actions workflow
- `ExportOptions.plist` - Xcode export configuration

## Troubleshooting

### Error: "Certificate not found"

Make sure:
1. Developer ID certificate is in your local Keychain
2. P12 password is correct
3. Base64 export is complete

### Error: "Notarization failed"

- Verify Apple ID and password
- Use an app-specific password if you have 2FA enabled
- Check that Team ID is correct

### Error: "Code signing failed"

- Verify DEVELOPER_ID is the exact Common Name of the certificate
- Check the Team ID in the certificate

## Verifying Downloads

Users can download the app from GitHub Releases and open it directly:

```bash
# Mount the DMG
hdiutil attach Cash.dmg

# Copy the app to Applications
cp -r /Volumes/Cash/Cash.app ~/Applications/

# Unmount
hdiutil detach /Volumes/Cash
```

The app will be signed and notarized, so it opens without security warnings.