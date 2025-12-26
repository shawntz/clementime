# Quick Release Guide

> **⚠️ DEPRECATED**: This release process has been replaced.
>
> Please use the unified release process at the repository root.
> See [../../RELEASE.md](../../RELEASE.md) for the new workflow.

## New Release Process (Tag-Based)

**Patch Release:**
```bash
./scripts/release.sh patch  # or just ./scripts/release.sh
```

**Minor Release:**
```bash
./scripts/release.sh minor
```

**Major Release:**
```bash
./scripts/release.sh major
```

---

## OLD PROCESS (No Longer Used)

---

## Setup (One-Time)

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `DOCKER_USERNAME`: Your Docker Hub username (shawnschwartz)
- `DOCKER_PASSWORD`: Your Docker Hub password or access token

---

## What Happens Automatically

Every push to `main`:

1. ✅ Reads `.version-bump` file (defaults to "patch")
2. ✅ Increments version number
3. ✅ Creates GitHub release with changelog
4. ✅ Builds multi-platform Docker image (amd64 + arm64)
5. ✅ Pushes to Docker Hub with version tag + latest
6. ✅ Resets `.version-bump` to "patch"

---

## Version Examples

| Current | Bump Type | Result |
|---------|-----------|--------|
| v1.0.0  | patch     | v1.0.1 |
| v1.0.1  | minor     | v1.1.0 |
| v1.1.0  | major     | v2.0.0 |

---

## Docker Usage

```bash
# Pull specific version
docker pull shawnschwartz/clementime:1.0.0

# Pull latest
docker pull shawnschwartz/clementime:latest

# Use in docker-compose.yml
services:
  app:
    image: shawnschwartz/clementime:latest
```

---

## Commit Message Conventions (Optional but Recommended)

- `fix:` → patch version (bug fixes)
- `feat:` → minor version (new features)
- `feat!:` or `BREAKING CHANGE:` → major version (breaking changes)
- `chore:`, `docs:`, `style:`, `refactor:` → patch version

---

## Troubleshooting

**Q: Release failed with "DOCKER_USERNAME not found"**
A: Add Docker Hub credentials to GitHub Secrets

**Q: Want to skip release for a commit?**
A: Add `[skip ci]` to your commit message

**Q: Need to manually trigger a release?**
A: Go to Actions → Release and Publish → Run workflow

**Q: First release not starting at v1.0.0?**
A: Delete all tags and push again, or manually create v0.0.0 tag
