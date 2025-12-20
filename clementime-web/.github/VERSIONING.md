# Versioning and Release Process

This repository uses automated semantic versioning with GitHub Actions.

## How It Works

Every push to the `main` branch automatically:
1. Creates a new GitHub release with an incremented version number
2. Builds and pushes a Docker image to Docker Hub
3. Tags the image with both the version number and `latest`

## Version Bumping

By default, every push increments the **patch** version (e.g., v1.0.0 → v1.0.1).

To increment a different version component, edit the `.version-bump` file before pushing:

### Patch Release (Default)
```bash
echo "patch" > .version-bump
git add .version-bump
git commit -m "fix: bug fix or minor change"
git push
```
Result: v1.0.0 → v1.0.1

### Minor Release
```bash
echo "minor" > .version-bump
git add .version-bump
git commit -m "feat: new feature"
git push
```
Result: v1.0.0 → v1.1.0

### Major Release
```bash
echo "major" > .version-bump
git add .version-bump
git commit -m "feat!: breaking change"
git push
```
Result: v1.0.0 → v2.0.0

## Docker Images

After each release, the following Docker images are available:

```bash
# Specific version
docker pull shawnschwartz/clementime:1.0.0

# Latest version
docker pull shawnschwartz/clementime:latest
```

## GitHub Secrets Required

For the workflow to run successfully, you need to set up the following secrets in your GitHub repository:

1. **DOCKER_USERNAME**: Your Docker Hub username
2. **DOCKER_PASSWORD**: Your Docker Hub password or access token

To add these secrets:
1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret with the corresponding value

## Notes

- The `.version-bump` file is automatically reset to `patch` after each release
- The workflow skips CI when resetting the version bump file with `[skip ci]`
- First release will be v1.0.0 if no tags exist
- Multi-platform Docker images are built (linux/amd64, linux/arm64)
