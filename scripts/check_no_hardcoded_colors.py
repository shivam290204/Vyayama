#!/usr/bin/env python3
"""
Lint check: ensure no hardcoded Color(0x...) values exist outside lib/core/theme/.
All colors should be derived from Theme.of(context).colorScheme, context.colors
(AppColorsExtension), or defined centrally in lib/core/theme/.
"""

import os
import re
import sys

def main() -> int:
    workspace_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lib_dir = os.path.join(workspace_root, 'lib')
    theme_dir = os.path.normpath(os.path.join(lib_dir, 'core', 'theme'))

    pattern = re.compile(r'Color\s*\(\s*0x[0-9a-fA-F]+\s*\)')
    violations = []

    for root, _, files in os.walk(lib_dir):
        norm_root = os.path.normpath(root)
        if norm_root.startswith(theme_dir):
            continue
        for f in files:
            if not f.endswith('.dart'):
                continue
            file_path = os.path.join(root, f)
            rel_path = os.path.relpath(file_path, workspace_root)
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as fp:
                for line_idx, line in enumerate(fp, start=1):
                    if pattern.search(line):
                        violations.append((rel_path, line_idx, line.strip()))

    if violations:
        print(f"FAILED: Found {len(violations)} hardcoded Color(0x...) occurrence(s) outside lib/core/theme/:\n")
        for file_path, line_idx, line in violations:
            print(f"  {file_path}:{line_idx}: {line}")
        print("\nPlease move colors to lib/core/theme/ or use Theme.of(context).colorScheme / context.colors.")
        return 1

    print("SUCCESS: 0 hardcoded Color(0x...) occurrences found outside lib/core/theme/.")
    return 0

if __name__ == '__main__':
    sys.exit(main())
