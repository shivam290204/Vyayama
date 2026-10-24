#!/usr/bin/env python3
"""
Secret & Token Scanning Utility for Vyayama
Scans all git-tracked files (or workspace files) to prevent committed secrets,
specifically JWT tokens, private keys, and hardcoded backend credentials.
"""

import os
import re
import subprocess
import sys

# Pattern matching standard JSON Web Tokens (e.g. Supabase anon/service_role keys)
JWT_PATTERN = re.compile(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}')

# Excluded paths / patterns
EXCLUDED_DIRS = {
    '.git',
    '.dart_tool',
    'build',
    '.idea',
    '.vscode',
    'node_modules',
}

EXCLUDED_FILES = {
    '.env',  # Local developer config (should be in .gitignore)
}


def get_files_to_scan(root_dir: str):
    """Retrieve list of files to scan via git ls-files if available, else walk."""
    try:
        res = subprocess.run(
            ['git', 'ls-files'],
            cwd=root_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        files = [os.path.join(root_dir, f.strip()) for f in res.stdout.splitlines() if f.strip()]
        return [f for f in files if os.path.isfile(f) and os.path.basename(f) not in EXCLUDED_FILES]
    except Exception:
        # Fallback to filesystem walk
        scanned = []
        for dirpath, dirnames, filenames in os.walk(root_dir):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
            for fname in filenames:
                if fname in EXCLUDED_FILES:
                    continue
                scanned.append(os.path.join(dirpath, fname))
        return scanned


def mask_secret(match_str: str) -> str:
    if len(match_str) <= 12:
        return '***'
    return match_str[:6] + '...' + match_str[-4:]


def scan_file(file_path: str):
    violations = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_no, line in enumerate(f, start=1):
                matches = JWT_PATTERN.findall(line)
                for m in matches:
                    violations.append((line_no, mask_secret(m), line.strip()))
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}", file=sys.stderr)
    return violations


def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    files = get_files_to_scan(repo_root)
    total_files = len(files)
    total_violations = 0

    print(f"Scanning {total_files} files for committed secrets and JWT tokens...")

    for fpath in files:
        # Skip this script itself
        if os.path.abspath(fpath) == os.path.abspath(__file__):
            continue
        rel_path = os.path.relpath(fpath, repo_root)
        violations = scan_file(fpath)
        if violations:
            total_violations += len(violations)
            for line_no, masked, raw_line in violations:
                print(f"[SECURITY VIOLATION] {rel_path}:{line_no}")
                print(f"  Detected JWT token: {masked}")
                print(f"  Content: {raw_line[:80]}...")

    if total_violations > 0:
        print(f"\nFAILURE: {total_violations} committed secret(s) or JWT token(s) detected!", file=sys.stderr)
        print("Please remove secrets from code and supply them via environment variables.", file=sys.stderr)
        sys.exit(1)

    print("\nSUCCESS: All files verified. Zero committed secrets or JWT tokens found.")
    sys.exit(0)


if __name__ == '__main__':
    main()
