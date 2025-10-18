#!/usr/bin/env python3
"""
Verification script for cursor-automation installation
Run this after installation to check prerequisites and configuration
"""

import subprocess
import sys
from pathlib import Path


def check_python_version():
    """Check Python version is 3.9+"""
    version = sys.version_info
    if version.major >= 3 and version.minor >= 9:
        print(f"✅ Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"❌ Python {version.major}.{version.minor}.{version.micro} (need 3.9+)")
        return False


def check_command(cmd, name):
    """Check if a command is available"""
    try:
        result = subprocess.run(
            [cmd, "--version"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            print(f"✅ {name} available")
            return True
    except Exception:
        pass
    print(f"❌ {name} not found")
    return False


def check_gh_auth():
    """Check if GitHub CLI is authenticated"""
    try:
        result = subprocess.run(
            ["gh", "auth", "status"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            print("✅ GitHub CLI authenticated")
            return True
    except Exception:
        pass
    print("❌ GitHub CLI not authenticated")
    return False


def check_imports():
    """Check if required Python packages are installed"""
    packages = [
        ("github", "PyGithub"),
        ("pydantic", "pydantic"),
        ("click", "click"),
        ("pydantic_settings", "pydantic-settings"),
    ]

    all_ok = True
    for module, name in packages:
        try:
            __import__(module)
            print(f"✅ {name} installed")
        except ImportError:
            print(f"❌ {name} not installed")
            all_ok = False

    return all_ok


def check_structure():
    """Check directory structure"""
    base_dir = Path(__file__).parent
    required = [
        "src/cursor_automation",
        "tests",
        "templates",
        "pyproject.toml",
    ]

    all_ok = True
    for path in required:
        full_path = base_dir / path
        if full_path.exists():
            print(f"✅ {path} exists")
        else:
            print(f"❌ {path} missing")
            all_ok = False

    return all_ok


def check_cursor_automation():
    """Check if cursor-automation package is importable"""
    try:
        import cursor_automation

        print(f"✅ cursor-automation package (v{cursor_automation.__version__})")
        return True
    except ImportError:
        print("❌ cursor-automation package not installed")
        print("   Run: pip install -e .")
        return False


def main():
    """Run all checks"""
    print("=" * 60)
    print("Cursor Automation - Installation Verification")
    print("=" * 60)
    print()

    checks = [
        ("Python Version", check_python_version),
        ("Directory Structure", check_structure),
        ("GitHub CLI", lambda: check_command("gh", "GitHub CLI")),
        ("Cursor CLI", lambda: check_command("cursor", "Cursor CLI")),
        ("GitHub Authentication", check_gh_auth),
        ("Python Packages", check_imports),
        ("Package Installation", check_cursor_automation),
    ]

    results = []
    for name, check_func in checks:
        print(f"\nChecking {name}...")
        results.append(check_func())

    print()
    print("=" * 60)

    if all(results):
        print("✅ All checks passed! Installation is complete.")
        print()
        print("Next steps:")
        print("  1. Configure: export CURSOR_GITHUB_TOKEN=$(gh auth token)")
        print("  2. Run daemon: cursor-daemon daemon")
        print("  3. Or test single PR: cursor-daemon process-pr <number>")
    else:
        print("❌ Some checks failed. Please fix the issues above.")
        print()
        print("Installation help:")
        print("  - Python 3.11+: https://www.python.org/downloads/")
        print("  - GitHub CLI: brew install gh")
        print("  - Cursor CLI: Add to PATH from Cursor app")
        print("  - Packages: pip install -e .")
        sys.exit(1)

    print("=" * 60)


if __name__ == "__main__":
    main()

