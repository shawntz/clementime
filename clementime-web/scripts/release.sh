#!/usr/bin/env bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [BUMP_TYPE]

Create and push a new release tag using year-based semantic versioning (YY.MAJOR.MINOR).

Version format: YY.MAJOR.MINOR (e.g., 25.1.0 for 2025, version 1.0)
  - YY: 2-digit year (automatically determined from current date)
  - MAJOR: Second number, incremented for new features or significant changes
  - MINOR: Third number, incremented for bug fixes and minor updates

BUMP_TYPE:
    major    - Increment major version, reset minor (YY.X.0)
    minor    - Increment minor version (YY.M.X) [default]
    patch    - Alias for minor (kept for compatibility)

Examples:
    $0              # Create minor release (25.1.0 -> 25.1.1)
    $0 minor        # Same as above
    $0 major        # Create major release (25.1.5 -> 25.2.0)

Note: Year is automatically set to current year. If the latest tag uses a
different year, the script will update to the current year and reset to X.1.0.

The script will:
  1. Get the latest version tag
  2. Calculate the new version using current year
  3. Show you what will be released
  4. Ask for confirmation
  5. Create and push the tag
  6. Trigger the GitHub Actions release workflow

EOF
    exit 1
}

# Parse arguments
BUMP_TYPE="${1:-minor}"

# Normalize patch to minor (kept for backward compatibility)
if [ "$BUMP_TYPE" = "patch" ]; then
    BUMP_TYPE="minor"
fi

if [[ ! "$BUMP_TYPE" =~ ^(major|minor)$ ]]; then
    print_error "Invalid bump type: $BUMP_TYPE"
    usage
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_error "You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

# Get the latest tag
print_info "Fetching latest tags..."
git fetch --tags

LATEST_TAG=$(git tag -l "v[0-9]*.[0-9]*.[0-9]*" | sort -V | tail -n 1)

if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="v0.0.0"
    print_warning "No previous tags found, starting from $LATEST_TAG"
else
    print_info "Latest tag: $LATEST_TAG"
fi

# Get current year as 2-digit number
CURRENT_YEAR=$(date +%y)

# Parse version (YY.MAJOR.MINOR)
VERSION=${LATEST_TAG#v}
IFS='.' read -ra VERSION_PARTS <<< "$VERSION"

YEAR=${VERSION_PARTS[0]:-0}
MAJOR=${VERSION_PARTS[1]:-0}
MINOR=${VERSION_PARTS[2]:-0}

# Check if year has changed
if [ "$YEAR" != "$CURRENT_YEAR" ]; then
    print_warning "Year has changed from $YEAR to $CURRENT_YEAR"
    print_info "Resetting version to ${CURRENT_YEAR}.1.0 (new year)"
    YEAR=$CURRENT_YEAR
    MAJOR=1
    MINOR=0
else
    # Calculate new version based on bump type
    case $BUMP_TYPE in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            ;;
    esac
fi

NEW_VERSION="v${YEAR}.${MAJOR}.${MINOR}"

# Show changes since last tag
print_info "Changes since $LATEST_TAG:"
echo ""
if [ "$LATEST_TAG" = "v0.0.0" ]; then
    git log --oneline -10
else
    git log ${LATEST_TAG}..HEAD --oneline
fi
echo ""

# Confirm release
print_warning "About to create release:"
echo "  Current version: $LATEST_TAG"
echo "  New version:     $NEW_VERSION"
echo "  Bump type:       $BUMP_TYPE"
echo ""
echo "This will:"
echo "  1. Create tag $NEW_VERSION"
echo "  2. Push to remote"
echo "  3. Trigger GitHub Actions workflow"
echo "  4. Build Docker image (web)"
echo "  5. Build macOS app"
echo "  6. Build static web assets"
echo "  7. Create GitHub release with all assets"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Release cancelled"
    exit 0
fi

# Create and push tag
print_info "Creating tag $NEW_VERSION..."
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"

print_info "Pushing tag to remote..."
git push origin "$NEW_VERSION"

print_success "Tag $NEW_VERSION created and pushed!"
print_info "GitHub Actions workflow triggered."
print_info "View progress at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"

echo ""
print_success "Release $NEW_VERSION is being built!"
echo ""
echo "Once the workflow completes, the release will include:"
echo "  • Docker image: shawnschwartz/clementime:${YEAR}.${MAJOR}.${MINOR}"
echo "  • macOS app: Clementime-${NEW_VERSION}-macOS.dmg"
echo "  • Web assets: clementime-web-${NEW_VERSION}.zip"
