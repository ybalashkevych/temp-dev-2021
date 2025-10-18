#!/bin/bash

# Fix GitHub Actions workflows
echo "Fixing GitHub Actions workflows..."

# Fix ci.yml
sed -i '' 's/macos-26/macos-latest/g' .github/workflows/ci.yml
echo "Fixed ci.yml"

# Fix pr-checks.yml
sed -i '' 's/macos-26/macos-latest/g' .github/workflows/pr-checks.yml
echo "Fixed pr-checks.yml"

# Fix release.yml
sed -i '' 's/macos-26/macos-latest/g' .github/workflows/release.yml
echo "Fixed release.yml"

echo "All workflows fixed!"