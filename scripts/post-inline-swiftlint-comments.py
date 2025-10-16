#!/usr/bin/env python3

#
# post-inline-swiftlint-comments.py
# LiveAssistant
#
# Posts SwiftLint violations as inline comments on Pull Requests
# Usage: python3 post-inline-swiftlint-comments.py <pr-number> <violations-json-file>
#

import json
import os
import sys
import requests
from typing import List, Dict, Any

def load_violations(filepath: str) -> List[Dict[str, Any]]:
    """Load violations from SwiftLint JSON output"""
    try:
        with open(filepath, 'r') as f:
            violations = json.load(f)
        return violations if isinstance(violations, list) else []
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {filepath}: {e}")
        sys.exit(1)

def get_pr_details(token: str, repo: str, pr_number: int) -> Dict[str, Any]:
    """Fetch PR details from GitHub API"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    pr_url = f'https://api.github.com/repos/{repo}/pulls/{pr_number}'
    response = requests.get(pr_url, headers=headers)
    
    if response.status_code != 200:
        print(f"Error fetching PR: {response.status_code} - {response.text}")
        sys.exit(1)
    
    return response.json()

def format_violation_comment(violation: Dict[str, Any]) -> str:
    """Format a violation as a comment"""
    rule_id = violation.get('rule_id', 'unknown')
    reason = violation.get('reason', 'No description')
    severity = violation.get('severity', 'warning')
    
    emoji = '🔴' if severity == 'error' else '⚠️'
    
    comment = f"{emoji} **{rule_id}**\n\n"
    comment += f"{reason}\n\n"
    comment += f"**Severity:** {severity}\n"
    
    # Add suggestion if available
    if 'suggestion' in violation:
        comment += f"\n**Suggestion:** {violation['suggestion']}"
    
    return comment

def get_repo_root() -> str:
    """Get repository root path"""
    import subprocess
    try:
        root = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], 
                                      stderr=subprocess.DEVNULL).decode().strip()
        return root
    except:
        return os.getcwd()

def post_review_comments(token: str, repo: str, pr_number: int, 
                        violations: List[Dict[str, Any]], commit_id: str):
    """Post violations as inline PR review comments"""
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    # Get repository root to make paths relative
    repo_root = get_repo_root()
    
    # Prepare review comments
    comments = []
    skipped = 0
    
    for violation in violations:
        file_path = violation.get('file', '')
        line = violation.get('line', 1)
        
        # Make path relative to repo root
        if file_path.startswith(repo_root):
            file_path = file_path[len(repo_root)+1:]
        
        # Skip if path is still absolute or invalid
        if file_path.startswith('/') or not file_path:
            skipped += 1
            continue
        
        comment = {
            'path': file_path,
            'line': int(line),
            'body': format_violation_comment(violation)
        }
        comments.append(comment)
    
    if not comments:
        print("No valid violations to comment (all paths invalid or no violations)")
        if skipped > 0:
            print(f"Skipped {skipped} violation(s) with invalid paths")
        return
    
    # GitHub limits to 50 comments per review
    if len(comments) > 50:
        print(f"Warning: {len(comments)} comments, limiting to first 50")
        comments = comments[:50]
    
    # Create review with inline comments
    review_url = f'https://api.github.com/repos/{repo}/pulls/{pr_number}/reviews'
    
    review_body = f"## 🔍 SwiftLint Code Quality Review\n\n"
    review_body += f"Found **{len(violations)}** code quality issue(s) that need attention.\n\n"
    
    if skipped > 0:
        review_body += f"_(Skipped {skipped} violation(s) with invalid file paths)_\n\n"
    
    review_body += "Please address these violations before merging."
    
    review_data = {
        'commit_id': commit_id,
        'body': review_body,
        'event': 'COMMENT',
        'comments': comments
    }
    
    print(f"Posting {len(comments)} inline comment(s)...")
    
    response = requests.post(review_url, headers=headers, json=review_data)
    
    if response.status_code == 200:
        print(f"✅ Successfully posted {len(comments)} inline comment(s)")
        print(f"📝 Review created on PR #{pr_number}")
    else:
        print(f"❌ Error posting review: {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 post-inline-swiftlint-comments.py <pr-number> <violations-json-file>")
        print("")
        print("Example:")
        print("  python3 post-inline-swiftlint-comments.py 42 swiftlint.json")
        sys.exit(1)
    
    # Get arguments
    pr_number = int(sys.argv[1])
    violations_file = sys.argv[2]
    
    # Get environment variables
    token = os.environ.get('GITHUB_TOKEN')
    repo = os.environ.get('GITHUB_REPOSITORY', 'ybalashkevych/LiveAssistant')
    
    if not token:
        print("Error: GITHUB_TOKEN environment variable not set")
        sys.exit(1)
    
    print(f"Processing violations for PR #{pr_number}")
    print(f"Repository: {repo}")
    
    # Load violations
    violations = load_violations(violations_file)
    print(f"Loaded {len(violations)} violation(s) from {violations_file}")
    
    if not violations:
        print("No violations found, nothing to post")
        sys.exit(0)
    
    # Get PR details
    print(f"Fetching PR details...")
    pr_data = get_pr_details(token, repo, pr_number)
    commit_id = pr_data['head']['sha']
    print(f"Target commit: {commit_id[:7]}")
    
    # Post comments
    post_review_comments(token, repo, pr_number, violations, commit_id)
    
    print("✅ Done!")

if __name__ == '__main__':
    main()

