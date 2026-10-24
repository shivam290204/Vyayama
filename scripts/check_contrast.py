import sys

def rel_lum(hex_code):
    hex_code = hex_code.lstrip('#')
    r, g, b = [int(hex_code[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    def adj(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * adj(r) + 0.7152 * adj(g) + 0.0722 * adj(b)

def contrast(hex1, hex2):
    l1, l2 = rel_lum(hex1), rel_lum(hex2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

def run_checks():
    checks = [
        # Dark Mode Text & Backgrounds
        ("Dark mode: onPrimary on primary (#15171C on #FF6B2C)", "#15171C", "#FF6B2C", 4.5),
        ("Dark mode: primary text on background (#F4F5F7 on #0F1115)", "#F4F5F7", "#0F1115", 4.5),
        ("Dark mode: primary text on surface (#F4F5F7 on #1A1D24)", "#F4F5F7", "#1A1D24", 4.5),
        ("Dark mode: primary text on raised (#F4F5F7 on #232730)", "#F4F5F7", "#232730", 4.5),
        ("Dark mode: secondary text on background (#A9AFBC on #0F1115)", "#A9AFBC", "#0F1115", 4.5),
        ("Dark mode: secondary text on surface (#A9AFBC on #1A1D24)", "#A9AFBC", "#1A1D24", 4.5),
        ("Dark mode: secondary text on raised (#A9AFBC on #232730)", "#A9AFBC", "#232730", 4.5),
        ("Dark mode: accent on background (#3DA9FC on #0F1115)", "#3DA9FC", "#0F1115", 4.5),
        ("Dark mode: accent on surface (#3DA9FC on #1A1D24)", "#3DA9FC", "#1A1D24", 4.5),
        ("Dark mode: accent on raised (#3DA9FC on #232730)", "#3DA9FC", "#232730", 4.5),
        ("Dark mode: primary UI graphical element on surface (#FF6B2C on #1A1D24)", "#FF6B2C", "#1A1D24", 3.0),
        
        # Light Mode Text & Backgrounds
        ("Light mode: onPrimary on primary (#15171C on #FF6B2C)", "#15171C", "#FF6B2C", 4.5),
        ("Light mode: primary text on background (#15171C on #FAF8F5)", "#15171C", "#FAF8F5", 4.5),
        ("Light mode: primary text on surface (#15171C on #FFFFFF)", "#15171C", "#FFFFFF", 4.5),
        ("Light mode: primary text on raised (#15171C on #F0EEEA)", "#15171C", "#F0EEEA", 4.5),
        ("Light mode: secondary text on background (#5C6370 on #FAF8F5)", "#5C6370", "#FAF8F5", 4.5),
        ("Light mode: secondary text on surface (#5C6370 on #FFFFFF)", "#5C6370", "#FFFFFF", 4.5),
        ("Light mode: secondary text on raised (#5C6370 on #F0EEEA)", "#5C6370", "#F0EEEA", 4.5),
        ("Light mode: primary accessible text on background (#B83E08 on #FAF8F5)", "#B83E08", "#FAF8F5", 4.5),
        ("Light mode: accent accessible text on background (#0D72B8 on #FAF8F5)", "#0D72B8", "#FAF8F5", 4.5),
    ]

    all_pass = True
    print("=" * 80)
    print("WCAG AA Contrast Verification")
    print("=" * 80)
    for name, c1, c2, req in checks:
        ratio = contrast(c1, c2)
        passed = ratio >= req
        if not passed:
            all_pass = False
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {name:70} | {ratio:5.2f}:1 (min: {req:.1f}:1)")

    print("=" * 80)
    if all_pass:
        print("RESULT: ALL CONTRAST RATIOS MEET OR EXCEED WCAG AA REQUIREMENTS!")
    else:
        print("RESULT: SOME CONTRAST RATIOS FAILED WCAG AA!")
    print("=" * 80)
    return all_pass

if __name__ == "__main__":
    if not run_checks():
        sys.exit(1)
