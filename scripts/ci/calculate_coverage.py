#!/usr/bin/env python3
"""
Calculate code coverage from xcresult bundle
Usage: python3 calculate_coverage.py <threshold>
"""
import json
import sys
from pathlib import Path
from typing import Tuple


def should_exclude(filepath: str) -> bool:
    """Check if file should be excluded from coverage"""
    exclude_patterns = [
        '/Views/', '/Tests/', '/Generated/', '/Components/',
        '/UITests/', '/Models/', '/App/'
    ]

    if any(pattern in filepath for pattern in exclude_patterns):
        return True

    # Exclude View files but not ViewModel files
    if filepath.endswith('View.swift') and not filepath.endswith('ViewModel.swift'):
        return True

    if '.xctest' in filepath:
        return True

    return False


def calculate_coverage(coverage_json_path: str) -> Tuple[float, int, int]:
    """Calculate coverage percentage from JSON"""
    try:
        with open(coverage_json_path, 'r') as f:
            coverage_data = json.load(f)
    except Exception as e:
        print(f"Error reading {coverage_json_path}: {e}", file=sys.stderr)
        return 0.0, 0, 0

    total_lines = 0
    covered_lines = 0

    for target in coverage_data.get('targets', []):
        for file_data in target.get('files', []):
            filepath = file_data.get('path', '')

            if should_exclude(filepath):
                continue

            total_lines += file_data.get('executableLines', 0)
            covered_lines += file_data.get('coveredLines', 0)

    coverage_pct = (covered_lines / total_lines * 100) if total_lines > 0 else 0.0
    return coverage_pct, total_lines, covered_lines


def main():
    if len(sys.argv) < 2:
        print("Usage: calculate_coverage.py <threshold>", file=sys.stderr)
        sys.exit(1)

    threshold = float(sys.argv[1])

    if not Path('coverage.json').exists():
        print("⚠️ coverage.json not found", file=sys.stderr)
        Path('coverage_result.txt').write_text("0.00")
        Path('coverage_status.txt').write_text("FAILED")
        return 0

    coverage_pct, total_lines, covered_lines = calculate_coverage('coverage.json')

    print(f"Total executable lines: {total_lines}")
    print(f"Covered lines: {covered_lines}")
    print(f"Coverage: {coverage_pct:.2f}%")

    Path('coverage_result.txt').write_text(f"{coverage_pct:.2f}")

    if coverage_pct < threshold:
        print(f"\n⚠️ Coverage {coverage_pct:.2f}% is below threshold {threshold}%")
        Path('coverage_status.txt').write_text("FAILED")
        return 1
    else:
        print(f"\n✅ Coverage {coverage_pct:.2f}% meets threshold {threshold}%")
        Path('coverage_status.txt').write_text("PASSED")
        return 0


if __name__ == '__main__':
    sys.exit(main())

