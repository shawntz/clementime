# 🔑 GitHub Secrets Setup for ClemenTime CI/CD

This guide explains how to configure GitHub Secrets for automated Docker Hub deployment and CI/CD pipeline.

## 📋 Required Secrets

### 🐳 Docker Hub Configuration

1. **Navigate to Repository Settings**
   - Go to your ClemenTime repository on GitHub
   - Click **Settings** → **Secrets and variables** → **Actions**

2. **Add Docker Hub Secrets**

   **DOCKER_USERNAME**
   ```
   Name: DOCKER_USERNAME
   Value: your-dockerhub-username
   ```

   **DOCKER_PASSWORD**
   ```
   Name: DOCKER_PASSWORD
   Value: your-dockerhub-access-token
   ```

### 🔐 How to Get Docker Hub Access Token

1. **Login to Docker Hub**
   - Visit https://hub.docker.com
   - Sign in to your account

2. **Create Access Token**
   - Click your username → **Account Settings**
   - Go to **Security** tab
   - Click **New Access Token**
   - Name: `ClemenTime-GitHub-Actions`
   - Permissions: **Read, Write, Delete**
   - Click **Generate**
   - **Copy the token immediately** (you won't see it again)

3. **Create Docker Hub Repository**
   - Go to **Repositories** → **Create Repository**
   - Name: `clementime`
   - Visibility: **Public** (recommended for open source)
   - Click **Create**

## 🚀 Environment Setup (Optional)

### Production Environment

1. **Create Production Environment**
   - Repository Settings → **Environments**
   - Click **New environment**
   - Name: `production`
   - **Protection rules**:
     - ✅ Required reviewers (add yourself)
     - ✅ Restrict pushes to protected branches
   - Click **Configure environment**

2. **Add Production Secrets**
   ```
   # Example production secrets (if needed)
   PROD_GOOGLE_SERVICE_ACCOUNT_KEY
   PROD_SLACK_BOT_TOKEN
   PROD_DOCKER_REGISTRY_URL
   ```

### Staging Environment

1. **Create Staging Environment**
   - Name: `staging`
   - **Protection rules**: None (auto-deploy)

2. **Add Staging Secrets**
   ```
   # Example staging secrets (if needed)
   STAGING_GOOGLE_SERVICE_ACCOUNT_KEY
   STAGING_SLACK_BOT_TOKEN
   ```

## 🔧 GitHub Token Permissions

The default `GITHUB_TOKEN` is automatically available and has the required permissions for:
- ✅ Creating releases
- ✅ Uploading artifacts
- ✅ Posting comments
- ✅ Security scanning

No additional configuration needed for `GITHUB_TOKEN`.

## 🚀 Deployment Workflow

### Automatic Triggers

The CI/CD pipeline automatically triggers on:

1. **Main Branch Push** → Production deployment
2. **Develop Branch Push** → Staging deployment
3. **Version Tags** → Release + Production deployment
4. **Pull Requests** → Testing only (no deployment)

### Manual Triggers

You can also manually trigger deployments:

1. **GitHub Actions Tab**
2. **Select "🍊 ClemenTime CI/CD Pipeline"**
3. **Click "Run workflow"**
4. **Choose branch and options**

## 📊 CI/CD Pipeline Features

### 🧪 Testing & Validation
- TypeScript compilation
- ESLint code quality checks
- Unit tests execution
- Configuration validation

### 🐳 Docker Operations
- Multi-platform builds (AMD64, ARM64)
- Automated image tagging
- Docker Hub pushing
- Image caching for faster builds

### 🔒 Security
- Trivy vulnerability scanning
- SARIF security report upload
- Dependency security checks

### 📦 Release Management
- Automatic GitHub releases on version tags
- Changelog generation
- Asset attachment

## 🏷️ Version Tagging

To create a new release:

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0

# This will trigger:
# 1. Full CI/CD pipeline
# 2. Docker image with v1.0.0 tag
# 3. GitHub release creation
# 4. Production deployment
```

### Tagging Strategy

- **v1.0.0** - Major releases
- **v1.1.0** - Minor feature releases
- **v1.1.1** - Patch/bugfix releases

## 🚨 Troubleshooting

### Docker Push Fails
```
Error: denied: requested access to the resource is denied
```
**Solution**: Check DOCKER_USERNAME and DOCKER_PASSWORD secrets

### Build Fails on Architecture
```
Error: failed to solve: process "/bin/sh -c npm install" did not complete successfully
```
**Solution**: Multi-platform build might have issues. Check Dockerfile

### Release Creation Fails
```
Error: Resource not accessible by integration
```
**Solution**: Ensure GITHUB_TOKEN has necessary permissions (should be automatic)

### Environment Deployment Blocked
```
Error: Environment protection rules prevent deployment
```
**Solution**: Check environment protection settings and approve manually if required

## ✅ Verification Checklist

After setup, verify:

- [ ] Secrets are configured correctly
- [ ] Docker Hub repository exists
- [ ] CI/CD pipeline runs on push
- [ ] Docker images are pushed successfully
- [ ] Security scans complete
- [ ] Releases are created for tags
- [ ] Environment deployments work

## 📞 Support

If you encounter issues:

1. **Check Actions Tab**: View detailed logs for each step
2. **Verify Secrets**: Ensure all required secrets are set correctly
3. **Docker Hub**: Confirm repository exists and token is valid
4. **GitHub Issues**: Open an issue if problems persist

---

**Next Steps**: After configuring secrets, push to main branch to trigger your first automated deployment! 🚀

*Made with ❤️ by [@shawntz](https://github.com/shawntz)*