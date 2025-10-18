#!/bin/bash

# Fix macOS runner in all workflow files
echo "Fixing macOS runner in workflow files..."

# List of workflow files
files=(
  ".github/workflows/ci.yml"
  ".github/workflows/pr-checks.yml"
  ".github/workflows/release.yml"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo "Processing $file..."
    # Use sed to replace macos-26 with macos-latest
    sed -i '' 's/macos-26/macos-latest/g' "$file"
    echo "Updated $file"
  else
    echo "File not found: $file"
  fi
done

echo "Done!"