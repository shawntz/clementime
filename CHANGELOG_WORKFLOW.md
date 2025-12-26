# Release Workflow Migration - Changelog

## Summary

The release workflow has been completely redesigned to use **tag-based releases** with **year-based semantic versioning** (YY.MAJOR.MINOR) instead of automatic releases on every push to `main`. The new workflow properly handles both the **Web** and **macOS** versions with comprehensive build automation including signing and notarization.

**Version Format**: `vYY.MAJOR.MINOR` (e.g., `v25.1.0` for 2025, version 1.0)
- YY: 2-digit year (automatically determined)
- MAJOR: Incremented for new features and significant changes
- MINOR: Incremented for bug fixes and small updates

## What Changed

### Old Workflow (Deprecated)
- ❌ Triggered on every push to `main`
- ❌ Required manual `.version-bump` file editing
- ❌ Only handled web Docker builds
- ❌ No macOS app support
- ❌ No code signing or notarization
- ❌ Auto-committed version bump changes

### New Workflow (Current)
- ✅ Triggered only on version tags (e.g., `v25.1.0`)
- ✅ Simple release script: `./scripts/release.sh`
- ✅ Year-based semantic versioning (YY.MAJOR.MINOR)
- ✅ Automatic year detection and version reset
- ✅ Builds both Web and macOS versions
- ✅ Creates DMG, PKG, and ZIP for macOS
- ✅ Full code signing support (optional)
- ✅ Apple notarization support (optional)
- ✅ Tag message used as build metadata
- ✅ Cleaner git history (no auto-commits)

## New Files Created

### Workflows
- `.github/workflows/release.yml` - Unified release workflow for both platforms
- `.github/workflows/ci.yml` - Moved from web directory, updated paths

### Scripts
- `scripts/release.sh` - Interactive release creation script

### Documentation
- `RELEASE.md` - Comprehensive release guide
- `.github/SECRETS.md` - GitHub secrets setup guide
- `CHANGELOG_WORKFLOW.md` - This file

### Updated Files
- `README.md` - Added releases section
- `clementime-web/.github/workflows/release.yml` - Deprecated with notice
- `clementime-web/.github/RELEASE_GUIDE.md` - Added deprecation notice
- `clementime-web/.github/VERSIONING.md` - Added deprecation notice

## How to Create a Release

### Before (Old Way)
```bash
echo "minor" > .version-bump
git add .version-bump
git commit -m "feat: new feature"
git push origin main
# Wait for automatic release...
```

### Now (New Way)
```bash
git add .
git commit -m "feat: new feature"
git push

# Create and push release tag (uses year-based versioning)
./scripts/release.sh major    # For new features (25.1.0 -> 25.2.0)
./scripts/release.sh minor    # For bug fixes (25.1.0 -> 25.1.1)

# Or manually (use year-based format: YY.MAJOR.MINOR):
git tag -a v25.2.0 -m "Add new feature"
git push origin v25.2.0
```

## Release Artifacts

Each release now includes:

1. **Docker Image** (Web)
   - Multi-platform: `linux/amd64`, `linux/arm64`
   - Tagged with version and `latest`
   - Pushed to Docker Hub: `shawnschwartz/clementime:YY.MAJOR.MINOR` (e.g., `25.1.0`)
   - Includes build number and tag message in env vars

2. **macOS App** (3 formats)
   - **DMG**: `Clementime-vYY.MAJOR.MINOR-macOS.dmg` (recommended installer)
   - **PKG**: `Clementime-vYY.MAJOR.MINOR-macOS.pkg` (alternative installer)
   - **ZIP**: `Clementime-vYY.MAJOR.MINOR-macOS.zip` (fallback/testing)

3. **Web Static Assets**
   - **ZIP**: `clementime-web-vYY.MAJOR.MINOR.zip` (standalone React app)

## Code Signing & Notarization

The workflow supports Apple code signing and notarization:

### Without Signing (Default)
- Builds work but show "unidentified developer" warning
- Good for testing and internal use
- No secrets required

### With Signing (Recommended for Distribution)
- Properly signed with Developer ID
- Notarized by Apple
- No security warnings for users
- Requires GitHub secrets (see `.github/SECRETS.md`)

## Version Metadata

The new workflow extracts metadata from git tags:

- **Version**: From tag name using year-based format (e.g., `v25.1.0`)
  - YY: 2-digit year (automatically set based on current date)
  - MAJOR: Second number (new features, significant changes)
  - MINOR: Third number (bug fixes, small updates)
- **Build Number**: Timestamp (e.g., `202512231430`)
- **Build Message**: Tag annotation/message

This metadata is:
- Embedded in macOS app Info.plist
- Added to web build environment variables
- Displayed in release notes

**Year Handling**: If releasing in a new year, the script automatically resets the version to YY.1.0 (e.g., when going from 2025 to 2026, v25.5.3 → v26.1.0).

## Migration Steps

If you're migrating from the old workflow:

1. ✅ Stop editing `.version-bump` file (no longer used)
2. ✅ Delete old-format local tags if needed: `git tag -d v1.0.69`
3. ✅ Use `./scripts/release.sh` to create new releases with year-based versioning
4. ✅ Configure GitHub secrets for signing (optional)
5. ✅ Test with a minor release: `./scripts/release.sh minor`
6. ✅ Update any documentation or scripts that reference old version format

## Removed/Deprecated

- `.version-bump` file (no longer needed)
- `clementime-web/.github/workflows/release.yml` (deprecated)
- Auto-commit behavior for version bumps
- Automatic releases on every push

## Benefits

1. **Cleaner Git History**: No automatic version bump commits
2. **Explicit Releases**: Tags clearly mark release points
3. **Better Control**: Review changes before releasing
4. **Multi-Platform**: Single workflow builds everything
5. **Professional**: Code signing and notarization support
6. **Flexible**: Works with or without signing secrets
7. **Documented**: Comprehensive guides and inline comments

## Testing

To test the new workflow without creating a real release:

1. Create a test tag (use year-based format):
   ```bash
   git tag -a v25.0.1-test -m "Test release"
   git push origin v25.0.1-test
   ```

2. Watch the workflow run in GitHub Actions

3. Delete test release and tag after verification:
   ```bash
   # Delete remote tag
   git push --delete origin v25.0.1-test

   # Delete local tag
   git tag -d v25.0.1-test
   ```

## Support

For issues or questions:
- See detailed docs in `RELEASE.md`
- Check secrets setup in `.github/SECRETS.md`
- Review workflow at `.github/workflows/release.yml`
- Open an issue on GitHub

---

**Migration Date**: 2025-12-23
**Status**: ✅ Complete and Production Ready
