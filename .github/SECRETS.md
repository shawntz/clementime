# GitHub Secrets Configuration

## Required Secrets

```
Required:
- DOCKER_USERNAME
- DOCKER_PASSWORD
- MACOS_CERTIFICATE
- MACOS_CERTIFICATE_PASSWORD
- MACOS_SIGNING_IDENTITY
- MACOS_INSTALLER_IDENTITY
- MACOS_NOTARIZATION_APPLE_ID
- MACOS_NOTARIZATION_PASSWORD
- APPLE_TEAM_ID
```

## Exporting macOS Certificates

### Export Developer ID Application Certificate

1. Open **Keychain Access** on macOS
2. Find "Developer ID Application" certificate
3. Right-click and select **Export**
4. Save as `.p12` file with a strong password
5. Convert to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
6. Paste into `MACOS_CERTIFICATE` secret
7. Use the password as `MACOS_CERTIFICATE_PASSWORD`

### Export Developer ID Installer Certificate

1. Same process as above
2. Look for "Developer ID Installer" certificate
3. Use for PKG signing

## Getting Apple App-Specific Password

1. Go to https://appleid.apple.com/account/manage
2. Use as `MACOS_NOTARIZATION_PASSWORD`

## Testing Workflows Without Secrets

The workflows are designed to work without signing secrets:
- **Without signing**: Builds will be unsigned but functional for testing
- **With signing**: Builds will be properly signed and notarized for distribution