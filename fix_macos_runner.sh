#!/bin/bash

# Fix macOS runner version in GitHub workflows
find .github/workflows -name "*.yml" -exec sed -i '' 's/macos-26/macos-14/g' {} \;

echo "Fixed macOS runner versions in GitHub workflows"