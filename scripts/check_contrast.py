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
        # Nature & Wellness Green Theme
        ("White text on Forest Green button (#FFFFFF on #14532D)", "#FFFFFF", "#14532D", 4.5),
        ("Dark mode: Primary text on dark background (#F7F8F2 on #151D17)", "#F7F8F2", "#151D17", 4.5),
        ("Dark mode: Primary text on dark surface (#F7F8F2 on #202820)", "#F7F8F2", "#202820", 4.5),
        ("Dark mode: Secondary text on dark background (#A6B7A6 on #151D17)", "#A6B7A6", "#151D17", 4.5),
        ("Dark mode: Lime Green accent on dark background (#8BCF45 on #151D17)", "#8BCF45", "#151D17", 4.5),
        ("Dark mode: Lime Green accent on dark surface (#8BCF45 on #202820)", "#8BCF45", "#202820", 4.5),
        ("Light mode: Charcoal Green text on Off-White background (#202820 on #F7F8F2)", "#202820", "#F7F8F2", 4.5),
        ("Light mode: Charcoal Green text on White card surface (#202820 on #FFFFFF)", "#202820", "#FFFFFF", 4.5),
        ("Light mode: Forest Green primary on Off-White background (#14532D on #F7F8F2)", "#14532D", "#F7F8F2", 4.5),
        ("Light mode: Deep Green secondary on Off-White background (#2E7D32 on #F7F8F2)", "#2E7D32", "#F7F8F2", 4.5),
    ]

    all_pass = True
    print("=" * 80)
    print("Vyayama Nature & Wellness Green Theme - Contrast Verification")
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
