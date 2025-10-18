#!/bin/bash

#
# cursor-quality.sh
# LiveAssistant
#
# Quality checks and verification tool
# Usage: ./scripts/cursor-quality.sh [review|verify|test]
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

#
# REVIEW command - Comprehensive self-review before PR
#
cmd_review() {
    echo -e "${BLUE}🔍 Running Self-Review Checks${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    FAILED=false
    
    # 1. SwiftLint Check
    echo -e "${BLUE}1. SwiftLint (Strict Mode)${NC}"
    if command -v swiftlint &> /dev/null; then
        SWIFTLINT_OUTPUT=$(mktemp)
        if swiftlint lint --strict > "$SWIFTLINT_OUTPUT" 2>&1; then
            echo -e "${GREEN}✅ SwiftLint passed (zero warnings)${NC}"
        else
            echo -e "${RED}❌ SwiftLint found violations${NC}"
            cat "$SWIFTLINT_OUTPUT"
            FAILED=true
            echo ""
            echo "Fix with: swiftlint --fix"
        fi
        rm -f "$SWIFTLINT_OUTPUT"
    else
        echo -e "${YELLOW}⚠️  SwiftLint not installed${NC}"
        echo "Install with: brew install swiftlint"
        FAILED=true
    fi
    echo ""
    
    # 2. swift-format Check
    echo -e "${BLUE}2. swift-format Validation${NC}"
    if command -v swift-format &> /dev/null || xcrun --find swift-format &> /dev/null 2>&1; then
        SWIFT_FORMAT=$(command -v swift-format 2>/dev/null || echo "xcrun swift-format")
        SWIFTFORMAT_OUTPUT=$(mktemp)
        
        if find LiveAssistant -name "*.swift" -not -path "*/Generated/*" -exec $SWIFT_FORMAT lint --strict {} + > "$SWIFTFORMAT_OUTPUT" 2>&1; then
            echo -e "${GREEN}✅ swift-format passed${NC}"
        else
            echo -e "${RED}❌ swift-format found violations${NC}"
            cat "$SWIFTFORMAT_OUTPUT"
            FAILED=true
            echo ""
            echo "Fix with: find LiveAssistant -name \"*.swift\" -not -path \"*/Generated/*\" -exec swift-format format --in-place {} +"
        fi
        rm -f "$SWIFTFORMAT_OUTPUT"
    else
        echo -e "${YELLOW}⚠️  swift-format not available${NC}"
        FAILED=true
    fi
    echo ""
    
    # 3. Build Check
    echo -e "${BLUE}3. Build Verification${NC}"
    if xcodebuild -scheme LiveAssistant -destination 'platform=macOS' clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Build successful${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        echo "Run: xcodebuild -scheme LiveAssistant -destination 'platform=macOS' build"
        FAILED=true
    fi
    echo ""
    
    # 4. Tests Check
    echo -e "${BLUE}4. Tests${NC}"
    if xcodebuild test -scheme LiveAssistant -destination 'platform=macOS' -testPlan LiveAssistant CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO > /dev/null 2>&1; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        echo "Run: xcodebuild test -scheme LiveAssistant -destination 'platform=macOS'"
        FAILED=true
    fi
    echo ""
    
    # 5. Code Coverage
    echo -e "${BLUE}5. Code Coverage${NC}"
    echo "Running tests with coverage..."
    
    # Run tests with coverage
    xcodebuild test \
        -scheme LiveAssistant \
        -destination 'platform=macOS' \
        -testPlan LiveAssistant \
        -enableCodeCoverage YES \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        -resultBundlePath TestResults.xcresult > /dev/null 2>&1 || true
    
    # Calculate coverage
    if [ -d "TestResults.xcresult" ]; then
        COVERAGE=$(xcrun xccov view --report --json TestResults.xcresult 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
total_lines = 0
covered_lines = 0
excluded_patterns = ['Views/', 'View.swift', 'Tests/', 'Generated/', 'Components/']

for target in data.get('targets', []):
    for file_data in target.get('files', []):
        filepath = file_data.get('path', '')
        if any(p in filepath for p in excluded_patterns):
            continue
        for func in file_data.get('functions', []):
            total_lines += func.get('executableLines', 0)
            covered_lines += func.get('coveredLines', 0)

if total_lines > 0:
    print(f'{(covered_lines / total_lines) * 100:.1f}')
else:
    print('0.0')
" 2>/dev/null || echo "0.0")
        
        COVERAGE_INT=$(echo "$COVERAGE" | cut -d. -f1)
        
        if [ "$COVERAGE_INT" -ge 20 ]; then
            echo -e "${GREEN}✅ Code coverage: ${COVERAGE}% (>= 20%)${NC}"
        else
            echo -e "${RED}❌ Code coverage: ${COVERAGE}% (< 20%)${NC}"
            FAILED=true
        fi
        
        rm -rf TestResults.xcresult
    else
        echo -e "${YELLOW}⚠️  Could not calculate coverage${NC}"
    fi
    echo ""
    
    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$FAILED" = false ]; then
        echo -e "${GREEN}✅ All checks passed! Ready to create PR${NC}"
        return 0
    else
        echo -e "${RED}❌ Some checks failed. Please fix issues before creating PR${NC}"
        return 1
    fi
}

#
# VERIFY command - Verify development environment setup
#
cmd_verify() {
    echo -e "${BLUE}🔍 Verifying LiveAssistant setup...${NC}\n"
    
    FAILED=false
    
    # Check command exists
    check_cmd() {
        if command -v "$1" &> /dev/null; then
            echo -e "${GREEN}✅ $2${NC}"
        else
            echo -e "${RED}❌ $2${NC}"
            [ -n "$3" ] && echo "   $3"
            FAILED=true
        fi
    }
    
    # Check path exists
    check_path() {
        if [ -e "$1" ]; then
            echo -e "${GREEN}✅ $2${NC}"
        else
            echo -e "${RED}❌ $2 missing${NC}"
            FAILED=true
        fi
    }
    
    # Tools
    echo -e "${BLUE}📦 Tools${NC}"
    check_cmd "xcodebuild" "Xcode"
    check_cmd "swift" "Swift"
    check_cmd "swiftlint" "SwiftLint" "Install: brew install swiftlint"
    check_cmd "swift-format" "swift-format" "Included with Xcode"
    check_cmd "gh" "GitHub CLI" "Install: brew install gh"
    echo ""
    
    # GitHub CLI auth
    echo -e "${BLUE}🔐 Authentication${NC}"
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"
    else
        echo -e "${RED}❌ GitHub CLI not authenticated${NC}"
        echo "   Run: gh auth login"
        FAILED=true
    fi
    echo ""
    
    # Configuration files
    echo -e "${BLUE}⚙️  Configuration${NC}"
    for file in .swiftlint.yml .swift-format Package.swift swiftgen.yml; do
        check_path "$file" "$file"
    done
    echo ""
    
    # Documentation
    echo -e "${BLUE}📚 Documentation${NC}"
    for file in README.md ARCHITECTURE.md CONTRIBUTING.md CHANGELOG.md; do
        check_path "$file" "$file"
    done
    echo ""
    
    # Project structure
    echo -e "${BLUE}🏗️  Structure${NC}"
    check_path "LiveAssistant/App" "App"
    check_path "LiveAssistant/Core" "Core"
    check_path "LiveAssistant/Features" "Features"
    check_path "LiveAssistant/Resources" "Resources"
    echo ""
    
    # Git hooks
    echo -e "${BLUE}🪝 Git Hooks${NC}"
    if [ -x ".git/hooks/pre-commit" ]; then
        echo -e "${GREEN}✅ Git hooks installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Git hooks not installed${NC}"
        echo "   Run: ./scripts/setup.sh install"
    fi
    echo ""
    
    # Build test
    echo -e "${BLUE}🔨 Build Test${NC}"
    echo "Testing build..."
    if xcodebuild build -scheme LiveAssistant -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Project builds successfully${NC}"
    else
        echo -e "${RED}❌ Project fails to build${NC}"
        FAILED=true
    fi
    echo ""
    
    # Summary
    if [ "$FAILED" = false ]; then
        echo -e "${GREEN}✅ Setup verified! Development environment is ready${NC}"
        return 0
    else
        echo -e "${RED}❌ Setup incomplete. Please address the issues above${NC}"
        return 1
    fi
}

#
# TEST command - Run tests with detailed coverage
#
cmd_test() {
    echo -e "${BLUE}🧪 Running Tests with Code Coverage${NC}\n"
    
    # Clean previous results
    echo -e "${BLUE}🧹 Cleaning previous test results...${NC}"
    rm -rf TestResults.xcresult coverage_reports/
    mkdir -p coverage_reports
    
    # Run tests with coverage
    echo -e "${BLUE}▶️  Running tests...${NC}"
    if xcodebuild test \
        -scheme LiveAssistant \
        -destination 'platform=macOS' \
        -testPlan LiveAssistant \
        -enableCodeCoverage YES \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        -resultBundlePath TestResults.xcresult; then
        echo -e "${GREEN}✅ Tests completed${NC}\n"
    else
        echo -e "${RED}❌ Tests failed${NC}"
        return 1
    fi
    
    # Generate JSON coverage report
    echo -e "${BLUE}📊 Generating coverage report...${NC}"
    xcrun xccov view --report --json TestResults.xcresult > coverage_reports/coverage.json
    
    # Parse and display coverage
    python3 << 'EOF'
import json
import sys

with open('coverage_reports/coverage.json', 'r') as f:
    coverage_data = json.load(f)

excluded_patterns = ['Views/', 'View.swift', 'Tests/', 'Generated/', 'UITests/', 'Components/']

def should_exclude(filepath):
    return any(pattern in filepath for pattern in excluded_patterns)

files_coverage = []
total_lines = 0
covered_lines = 0

for target in coverage_data.get('targets', []):
    for file_data in target.get('files', []):
        filepath = file_data.get('path', '')
        
        if should_exclude(filepath):
            continue
        
        file_lines = 0
        file_covered = 0
        
        for function in file_data.get('functions', []):
            file_lines += function.get('executableLines', 0)
            file_covered += function.get('coveredLines', 0)
        
        if file_lines > 0:
            file_pct = (file_covered / file_lines) * 100
            files_coverage.append({
                'path': filepath.split('/')[-1],
                'lines': file_lines,
                'covered': file_covered,
                'percentage': file_pct
            })
            total_lines += file_lines
            covered_lines += file_covered

if total_lines > 0:
    total_pct = (covered_lines / total_lines) * 100
    
    print("\n📊 Coverage Report\n")
    print(f"Total Coverage: {total_pct:.1f}% ({covered_lines}/{total_lines} lines)")
    print("")
    
    if files_coverage:
        print("Per-File Coverage:")
        files_coverage.sort(key=lambda x: x['percentage'])
        for file_info in files_coverage:
            pct = file_info['percentage']
            symbol = "✅" if pct >= 20 else "⚠️" if pct >= 10 else "❌"
            print(f"  {symbol} {pct:5.1f}% {file_info['path']}")
    
    print("")
    if total_pct >= 20:
        print("✅ Coverage meets minimum threshold (20%)")
        sys.exit(0)
    else:
        print(f"❌ Coverage below minimum threshold (20%)")
        sys.exit(1)
else:
    print("No coverage data available")
    sys.exit(1)
EOF
    
    return $?
}

# Usage
usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  review    Run comprehensive self-review checks"
    echo "  verify    Verify development environment setup"
    echo "  test      Run tests with detailed coverage report"
    echo ""
    echo "Examples:"
    echo "  $0 review    # Before creating PR"
    echo "  $0 verify    # After initial setup"
    echo "  $0 test      # Generate coverage report"
}

# Main command dispatcher
case "${1:-}" in
    review)
        cmd_review
        ;;
    verify)
        cmd_verify
        ;;
    test)
        cmd_test
        ;;
    ""|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac

