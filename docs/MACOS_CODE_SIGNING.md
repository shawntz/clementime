# macOS Code Signing & Notarization Guide

This guide explains how to obtain the credentials needed for macOS app distribution and GitHub Actions automated builds.

## Prerequisites

1. **Apple Developer Account** ($99/year)
   - Enroll at: https://developer.apple.com/programs/enroll/

2. **Xcode installed** on your Mac
   - Download from Mac App Store

3. **Access to a Mac** running macOS 15.0+

---

## Required Credentials

These environment variables are needed for GitHub Actions to build, sign, and notarize the macOS app:

| Variable | Description | Used For |
|----------|-------------|----------|
| `MACOS_CERTIFICATE` | Base64-encoded .p12 certificate | Code signing the app |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the .p12 certificate | Unlocking the certificate |
| `MACOS_SIGNING_IDENTITY` | Developer ID Application identity | Signing the .app bundle |
| `MACOS_INSTALLER_IDENTITY` | Developer ID Installer identity | Signing the .pkg installer |
| `MACOS_NOTARIZATION_APPLE_ID` | Apple ID email | Notarization authentication |
| `MACOS_NOTARIZATION_PASSWORD` | App-specific password | Notarization authentication |
| `APPLE_TEAM_ID` | 10-character team identifier | App identification |

---

## Step-by-Step Guide

### 1. Get Your Apple Team ID

**Where to find it**:
1. Go to https://developer.apple.com/account
2. Sign in with your Apple ID
3. Click **Membership** in the sidebar
4. Your **Team ID** is listed (10-character alphanumeric, e.g., `A1B2C3D4E5`)

**Set in GitHub**:
```
APPLE_TEAM_ID=A1B2C3D4E5
```

---

### 2. Create Developer ID Certificates

You need **two** certificates:
- **Developer ID Application** (for signing the .app)
- **Developer ID Installer** (for signing the .pkg)

#### Create Certificates in Xcode

1. **Open Xcode** → **Settings** (⌘,)
2. Go to **Accounts** tab
3. Click your Apple ID → Click **Manage Certificates...**
4. Click the **+** button → Select **Developer ID Application**
5. Click **+** again → Select **Developer ID Installer**
6. Close the window (certificates are now in your Keychain)

#### Alternative: Create via Apple Developer Portal

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click **+** to create a new certificate
3. Select **Developer ID Application** → Continue
4. Upload a Certificate Signing Request (CSR):
   - Open **Keychain Access** on your Mac
   - Menu: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
   - Enter your email, name, select "Saved to disk"
   - Upload the CSR file to Apple Developer portal
5. Download the certificate and double-click to install
6. Repeat for **Developer ID Installer**

---

### 3. Export Certificate as .p12 File

#### Export from Keychain Access

1. Open **Keychain Access** on your Mac
2. In the sidebar, select **login** keychain → **My Certificates**
3. Find **Developer ID Application: Your Name (TEAMID)**
4. **Expand the certificate** (click the triangle) to show the private key
5. **Select both** the certificate AND the private key
6. Right-click → **Export 2 items...**
7. Save as: `Certificates.p12`
8. **Set a password** (you'll need this for `MACOS_CERTIFICATE_PASSWORD`)
9. Enter your Mac password to allow the export

**Important**: Make sure you export BOTH the certificate and private key together!

---

### 4. Convert .p12 to Base64

#### On macOS/Linux:

```bash
# Convert the .p12 file to base64
base64 -i Certificates.p12 -o certificate.txt

# Copy the contents of certificate.txt
cat certificate.txt | pbcopy
```

#### On Windows (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Certificates.p12")) | Out-File certificate.txt
```

**Set in GitHub**:
```
MACOS_CERTIFICATE=<paste the entire base64 string here>
```

This will be a very long string (several thousand characters).

---

### 5. Set Certificate Password

Use the password you chose when exporting the .p12 file in Step 3.

**Set in GitHub**:
```
MACOS_CERTIFICATE_PASSWORD=your_chosen_password
```

---

### 6. Get Signing Identity Names

The signing identities are the full names of your certificates as they appear in Keychain.

#### Find Identity Names:

```bash
# List all Developer ID Application certificates
security find-identity -v -p codesigning | grep "Developer ID Application"

# List all Developer ID Installer certificates
security find-identity -v -p codesigning | grep "Developer ID Installer"
```

**Example output**:
```
1) A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0 "Developer ID Application: John Doe (A1B2C3D4E5)"
2) Z9Y8X7W6V5U4T3S2R1Q0P9O8N7M6L5K4J3I2H1G0 "Developer ID Installer: John Doe (A1B2C3D4E5)"
```

**Set in GitHub**:
```
MACOS_SIGNING_IDENTITY=Developer ID Application: John Doe (A1B2C3D4E5)
MACOS_INSTALLER_IDENTITY=Developer ID Installer: John Doe (A1B2C3D4E5)
```

**Copy the ENTIRE string** including "Developer ID Application: ..." exactly as shown.

---

### 7. Create App-Specific Password for Notarization

App-specific passwords are required for automated notarization (instead of your main Apple ID password).

#### Create App-Specific Password:

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Navigate to **Security** section
4. Under **App-Specific Passwords**, click **Generate Password...**
5. Enter a label: `Clementime Notarization` (or similar)
6. Click **Create**
7. **Copy the generated password** (format: `xxxx-xxxx-xxxx-xxxx`)

**Important**: Save this password immediately - you can't view it again!

**Set in GitHub**:
```
MACOS_NOTARIZATION_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

---

### 8. Set Notarization Apple ID

This is simply the email address associated with your Apple Developer account.

**Set in GitHub**:
```
MACOS_NOTARIZATION_APPLE_ID=your.email@example.com
```

---

## Setting Up GitHub Secrets

Once you have all the values, add them to your GitHub repository:

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret one by one:

| Secret Name | Value |
|-------------|-------|
| `MACOS_CERTIFICATE` | Base64-encoded .p12 file content |
| `MACOS_CERTIFICATE_PASSWORD` | Password you set when exporting .p12 |
| `MACOS_SIGNING_IDENTITY` | `Developer ID Application: Your Name (TEAMID)` |
| `MACOS_INSTALLER_IDENTITY` | `Developer ID Installer: Your Name (TEAMID)` |
| `MACOS_NOTARIZATION_APPLE_ID` | Your Apple ID email |
| `MACOS_NOTARIZATION_PASSWORD` | App-specific password |
| `APPLE_TEAM_ID` | 10-character team ID |

---

## Verification

### Test Code Signing Locally

Before relying on GitHub Actions, test signing locally:

```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" \
  /path/to/Clementime.app

# Verify the signature
codesign --verify --deep --strict --verbose=2 /path/to/Clementime.app

# Check what identity was used
codesign -dv /path/to/Clementime.app
```

### Test Notarization Locally

```bash
# Create a ZIP of the app
ditto -c -k --keepParent Clementime.app Clementime.zip

# Submit for notarization
xcrun notarytool submit Clementime.zip \
  --apple-id "your.email@example.com" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --team-id "A1B2C3D4E5" \
  --wait

# Check notarization status
xcrun notarytool history \
  --apple-id "your.email@example.com" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --team-id "A1B2C3D4E5"
```

---

## Troubleshooting

### "No identity found" Error

**Problem**: Certificate not found in keychain.

**Solution**:
- Ensure you've installed both Developer ID certificates
- Run `security find-identity -v -p codesigning` to verify they're present
- Make sure the certificate includes the private key

### "Invalid Password" Error

**Problem**: Wrong certificate password.

**Solution**:
- Double-check the password you used when exporting the .p12
- Try exporting a new .p12 file with a fresh password

### Notarization Fails with "Invalid Credentials"

**Problem**: Wrong Apple ID or app-specific password.

**Solution**:
- Verify the Apple ID email is correct
- Generate a new app-specific password at https://appleid.apple.com
- Ensure you're using the app-specific password, NOT your main Apple ID password

### "Certificate has expired" Error

**Problem**: Developer ID certificates expired.

**Solution**:
- Certificates are valid for 5 years
- Renew at https://developer.apple.com/account/resources/certificates/list
- Export the new certificate and update GitHub secrets

### Base64 Encoding Issues

**Problem**: Certificate fails to import in GitHub Actions.

**Solution**:
- Ensure you exported BOTH certificate and private key together
- Make sure the base64 string has no newlines or extra spaces
- Try using `base64 -i Certificates.p12` without line breaks:
  ```bash
  base64 -i Certificates.p12 | tr -d '\n' > certificate.txt
  ```

---

## Security Best Practices

### Keep Your Credentials Safe

- ✅ **DO**: Store credentials only in GitHub Secrets (encrypted)
- ✅ **DO**: Use app-specific passwords (not your main Apple ID password)
- ✅ **DO**: Rotate app-specific passwords periodically
- ✅ **DO**: Keep your .p12 file in a secure location (encrypted disk)

- ❌ **DON'T**: Commit certificates or passwords to git
- ❌ **DON'T**: Share your .p12 file or passwords publicly
- ❌ **DON'T**: Use your main Apple ID password for automation
- ❌ **DON'T**: Store credentials in plaintext files

### Revoke Compromised Credentials

If credentials are compromised:

1. **Revoke app-specific password**: https://appleid.apple.com → Security → Delete password
2. **Revoke certificate**: https://developer.apple.com/account/resources/certificates/list → Revoke
3. **Create new credentials** following this guide
4. **Update GitHub Secrets** with new values

---

## Additional Resources

- [Apple Code Signing Guide](https://developer.apple.com/documentation/security/code_signing_services)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App-Specific Passwords](https://support.apple.com/en-us/HT204397)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

## Quick Reference

### All Required Values Checklist

- [ ] `APPLE_TEAM_ID` - From developer.apple.com/account
- [ ] Created Developer ID Application certificate
- [ ] Created Developer ID Installer certificate
- [ ] Exported .p12 file with both certificate and private key
- [ ] `MACOS_CERTIFICATE` - Base64-encoded .p12 content
- [ ] `MACOS_CERTIFICATE_PASSWORD` - Password for .p12 file
- [ ] `MACOS_SIGNING_IDENTITY` - Full certificate name from Keychain
- [ ] `MACOS_INSTALLER_IDENTITY` - Full installer cert name from Keychain
- [ ] `MACOS_NOTARIZATION_APPLE_ID` - Apple ID email
- [ ] `MACOS_NOTARIZATION_PASSWORD` - App-specific password from appleid.apple.com
- [ ] All secrets added to GitHub repository

### Time Required

- **First-time setup**: 30-45 minutes
- **With existing developer account**: 15-20 minutes
- **Renewal (every 5 years)**: 10-15 minutes

---

Need help? Check the [Troubleshooting](#troubleshooting) section or open an issue on GitHub.
