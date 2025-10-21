#!/usr/bin/env python3
"""
Generate and post PR validation results comment
Usage: python3 report_pr_results.py
"""
import os
import sys
from pathlib import Path
from typing import Optional, Tuple


def read_file_safe(filepath: str) -> Optional[str]:
    """Read file safely, return None if not exists"""
    try:
        return Path(filepath).read_text()
    except Exception:
        return None


def parse_coverage() -> Tuple[str, str]:
    """Parse coverage result and status"""
    coverage = read_file_safe('coverage_result.txt') or "N/A"
    status = read_file_safe('coverage_status.txt') or "UNKNOWN"
    return coverage.strip(), status.strip()


def check_lint_results(filepath: str) -> Tuple[bool, Optional[str]]:
    """Check lint file for errors/warnings"""
    content = read_file_safe(filepath)
    if not content:
        return True, None

    has_issues = 'warning:' in content or 'error:' in content
    return not has_issues, content[:3000] if has_issues else None


def generate_pr_comment() -> str:
    """Generate markdown comment for PR"""
    threshold = os.getenv('COVERAGE_THRESHOLD', '20.0')
    coverage, coverage_status = parse_coverage()

    swiftlint_pass, swiftlint_output = check_lint_results('swiftlint-output.txt')
    swiftformat_pass, swiftformat_output = check_lint_results('swiftformat-output.txt')

    tests_failed = os.getenv('TESTS_FAILED') == 'true'
    test_errors = os.getenv('TEST_ERRORS', '')

    lines = [
        "## 🔍 PR Validation Results",
        "",
    ]

    # SwiftLint
    if swiftlint_pass:
        lines.append("✅ **SwiftLint**: Passed")
    else:
        lines.extend([
            "❌ **SwiftLint**: Failed",
            "",
            "<details><summary>⚠️ Click to see SwiftLint violations</summary>",
            "",
            "```",
            swiftlint_output or "See workflow logs for details",
            "```",
            "</details>",
        ])
    lines.append("")

    # swift-format
    if swiftformat_pass:
        lines.append("✅ **swift-format**: Passed")
    else:
        lines.extend([
            "❌ **swift-format**: Failed",
            "",
            "<details><summary>⚠️ Click to see formatting issues</summary>",
            "",
            "```",
            swiftformat_output or "See workflow logs for details",
            "```",
            "</details>",
        ])
    lines.append("")

    # Build
    lines.extend(["✅ **Build**: Passed", ""])

    # Tests
    if tests_failed:
        github_server = os.getenv('GITHUB_SERVER_URL', 'https://github.com')
        github_repo = os.getenv('GITHUB_REPOSITORY', '')
        github_run_id = os.getenv('GITHUB_RUN_ID', '')

        lines.extend([
            "❌ **Unit Tests**: Failed",
            "",
            "<details><summary>🔴 Click to see test failures</summary>",
            "",
            "```",
            test_errors or "See workflow logs for details",
            "```",
            "",
            f"**Full logs**: [View in Actions]({github_server}/{github_repo}/actions/runs/{github_run_id})",
            "</details>",
        ])
    else:
        lines.append("✅ **Unit Tests**: Passed")
    lines.append("")

    # Coverage
    if coverage == "N/A" or coverage == "0.00":
        lines.extend([
            "⚠️ **Coverage**: Could not calculate (tests may have failed)",
            "",
            "_Coverage reporting requires successful test execution_",
        ])
    elif coverage_status == "FAILED":
        lines.extend([
            f"❌ **Coverage**: {coverage}% (threshold: {threshold}%)",
            "",
            "⚠️ Coverage is below the required threshold. Please add tests for:",
            "- ViewModels",
            "- Repositories",
            "- Services",
        ])
    elif coverage_status == "PASSED":
        lines.append(f"✅ **Coverage**: {coverage}% (threshold: {threshold}%)")
    else:
        lines.append("⚠️ **Coverage**: Could not calculate")
    lines.append("")

    # Overall status
    lines.append("---")
    if tests_failed or coverage_status == "FAILED":
        lines.extend([
            "## ⚠️ Action Required",
            "",
        ])
        if tests_failed:
            lines.append("1. 🔴 **Fix test failures** (see details above)")
        if coverage_status == "FAILED":
            lines.append(f"2. 📊 **Increase code coverage** to at least {threshold}%")
        lines.extend([
            "",
            "Then push your changes to trigger checks again.",
        ])
    else:
        lines.extend([
            "## 🎉 All Checks Passed!",
            "",
            "Great work! Your code meets all quality standards.",
        ])

    lines.extend([
        "",
        "---",
        "*Excluded from coverage: SwiftUI Views, Components, Models, App setup, Test files, Generated files*",
    ])

    return "\n".join(lines)


def main():
    """Generate PR comment markdown file"""
    try:
        comment = generate_pr_comment()
        Path('pr-comment.md').write_text(comment)
        print("✅ Generated pr-comment.md")
        return 0
    except Exception as e:
        print(f"❌ Error generating PR comment: {e}", file=sys.stderr)
        # Create minimal comment so workflow doesn't crash
        Path('pr-comment.md').write_text(
            "## 🔍 PR Validation Results\n\n"
            "⚠️ Error generating full report. Check workflow logs.\n"
        )
        return 1


if __name__ == '__main__':
    sys.exit(main())

