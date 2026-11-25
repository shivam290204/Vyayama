#!/usr/bin/env python3
"""
Secret & Token Scanning Utility for Vyayama
Scans git-tracked files, untracked non-ignored files, and staged diffs to prevent
pushing secrets (JWTs, Google/Firebase keys, Supabase service keys, AI keys,
private keys, signing passwords, or credential files) to GitHub.
"""

import os
import re
import subprocess
import sys

SECRET_PATTERNS = {
    'JWT Token': re.compile(
        r'eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{10,}'
    ),
    'Google / Firebase API Key': re.compile(r'AIza[0-9A-Za-z_-]{35}'),
    'Private Key Header': re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
    'Supabase Secret / CLI Token': re.compile(
        r'\b(?:sb_secret_[A-Za-z0-9_-]{16,}|sbp_[A-Za-z0-9]{20,})\b'
    ),
    'AI / Provider Secret Key': re.compile(
        r'\bsk-(?:proj-|ant-|live-|test-)?[A-Za-z0-9_-]{20,}\b'
    ),
    'GitHub Token': re.compile(r'\bgh[pousr]_[A-Za-z0-9]{20,}\b'),
    'Privileged Env Assignment': re.compile(
        r'(?i)(?:SUPABASE_SERVICE_ROLE_KEY|VISION_API_KEY|FIREBASE_SERVICE_ACCOUNT|FCM_SERVICE_ACCOUNT|RESEND_API_KEY|CRON_SECRET)\s*[:=]\s*[\'"][A-Za-z0-9._+/=-]{16,}[\'"]'
    ),
    'Keystore Password Literal': re.compile(
        r'(?im)^\s*(?:storePassword|keyPassword)\s*=\s*(?!your-|keystoreProperties|System\.|env\()([^\s"\']{6,})\s*$'
    ),
}

FORBIDDEN_FILENAME_RE = re.compile(
    r'(?i)(?:^|/)(?:\.env(?!\.example$)(?:\..+)?|key\.properties|google-services\.json|GoogleService-Info\.plist|client_secret.*\.json|credentials\.json|firebase_options\.dart|.*\.(?:jks|keystore|p12|p8|pem|key))$'
)

EXCLUDED_DIRS = {
    '.git',
    '.dart_tool',
    'build',
    '.idea',
    '.vscode',
    'node_modules',
}

BINARY_EXTENSIONS = {
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico',
    '.mp3', '.wav', '.ttf', '.otf', '.jks', '.keystore',
    '.apk', '.aab', '.zip', '.jar', '.pdf',
}


def run_git(args: list[str], cwd: str) -> list[str]:
    res = subprocess.run(
        ['git', *args],
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    return [line.strip() for line in res.stdout.splitlines() if line.strip()]


def get_files_to_scan(root_dir: str) -> list[str]:
    """Retrieve git-tracked + untracked non-ignored files, or walk workspace."""
    try:
        tracked = run_git(['ls-files'], root_dir)
        untracked = run_git(['ls-files', '--others', '--exclude-standard'], root_dir)
        seen = set()
        result = []
        for rel in tracked + untracked:
            norm = rel.replace('\\', '/')
            if norm not in seen:
                seen.add(norm)
                full = os.path.join(root_dir, rel)
                if os.path.isfile(full):
                    result.append(full)
        return result
    except Exception:
        scanned = []
        for dirpath, dirnames, filenames in os.walk(root_dir):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
            for fname in filenames:
                scanned.append(os.path.join(dirpath, fname))
        return scanned


def mask_secret(match_str: str) -> str:
    if len(match_str) <= 10:
        return '***'
    return match_str[:5] + '...' + match_str[-4:]


def scan_text(lines: list[str]) -> list[tuple[str, int, str]]:
    violations = []
    for line_no, line in enumerate(lines, start=1):
        for label, rx in SECRET_PATTERNS.items():
            for m in rx.finditer(line):
                token = m.group(m.lastindex or 0)
                if 'your-' in token.lower() or 'placeholder' in token.lower() or 'example' in token.lower():
                    continue
                violations.append((label, line_no, mask_secret(token)))
    return violations


def scan_file(file_path: str) -> list[tuple[str, int, str]]:
    ext = os.path.splitext(file_path)[1].lower()
    if ext in BINARY_EXTENSIONS:
        return []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return scan_text(f.read().splitlines())
    except Exception as e:
        print(f'Warning: Could not read {file_path}: {e}', file=sys.stderr)
        return []


def main() -> int:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    files = get_files_to_scan(repo_root)
    total_files = len(files)
    total_violations = 0

    print(
        f'Scanning {total_files} tracked & untracked-visible files for secrets, keys, and credential files...'
    )

    self_abs = os.path.abspath(__file__)
    for fpath in files:
        if os.path.abspath(fpath) == self_abs:
            continue
        rel_path = os.path.relpath(fpath, repo_root).replace('\\', '/')

        if FORBIDDEN_FILENAME_RE.search(rel_path):
            total_violations += 1
            print(f'[SECURITY VIOLATION] Forbidden credential/secret file trackable by Git: {rel_path}')
            continue

        for label, line_no, masked in scan_file(fpath):
            total_violations += 1
            print(f'[SECURITY VIOLATION] {rel_path}:{line_no} ({label}: {masked})')

    # Also check staged diff lines if git is present
    try:
        staged_res = subprocess.run(
            ['git', 'diff', '--cached', '--unified=0', '--no-color'],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        added_lines = [
            l[1:]
            for l in staged_res.stdout.splitlines()
            if l.startswith('+') and not l.startswith('+++')
        ]
        for label, line_no, masked in scan_text(added_lines):
            total_violations += 1
            print(f'[SECURITY VIOLATION] Staged diff line #{line_no} ({label}: {masked})')
    except Exception:
        pass

    if total_violations > 0:
        print(
            f'\nFAILURE: {total_violations} secret or sensitive file violation(s) detected!',
            file=sys.stderr,
        )
        print(
            'Remove secrets and ensure sensitive files remain in .gitignore before pushing.',
            file=sys.stderr,
        )
        return 1

    print('\nSUCCESS: All files verified. Zero secrets, tokens, or credential files staged or trackable.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
