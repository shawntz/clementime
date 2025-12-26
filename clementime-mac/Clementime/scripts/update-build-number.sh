#!/bin/bash

# Script to update build number based on git commit count
# This runs as a pre-build phase

# Get the git commit count
COMMIT_COUNT=$(git rev-list HEAD --count 2>/dev/null || echo "1")

# Update the project build number using agvtool
cd "${PROJECT_DIR}"
xcrun agvtool new-version -all "${COMMIT_COUNT}"

echo "Updated build number to: ${COMMIT_COUNT}"
