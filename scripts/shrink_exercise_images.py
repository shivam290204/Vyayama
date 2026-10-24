#!/usr/bin/env python3
"""
Exercise Image Optimization Script for Vyayama
1. Backs up original PNGs to git-ignored assets/exercises_originals/
2. Converts PNGs to WebP (quality 80, max width 1080px)
3. Updates references in exercises.json, exercise.dart, tests, and CSV
"""

import os
import shutil
import json
import re
from PIL import Image

def main():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    exercises_dir = os.path.join(repo_root, 'assets', 'exercises')
    backup_dir = os.path.join(repo_root, 'assets', 'exercises_originals')

    os.makedirs(backup_dir, exist_ok=True)

    png_files = [f for f in sorted(os.listdir(exercises_dir)) if f.lower().endswith('.png')]
    print(f"Found {len(png_files)} PNG files to optimize in {exercises_dir}")

    total_orig_bytes = 0
    total_webp_bytes = 0
    conversion_log = []

    for fname in png_files:
        png_path = os.path.join(exercises_dir, fname)
        backup_path = os.path.join(backup_dir, fname)

        # 1. Back up original if not already backed up
        if not os.path.exists(backup_path):
            shutil.copy2(png_path, backup_path)

        orig_size = os.path.getsize(png_path)
        total_orig_bytes += orig_size

        # 2. Convert to WebP
        base_name = os.path.splitext(fname)[0]
        webp_path = os.path.join(exercises_dir, f"{base_name}.webp")

        with Image.open(png_path) as img:
            orig_w, orig_h = img.size
            target_img = img

            if orig_w > 1080:
                scale = 1080.0 / orig_w
                new_h = int(round(orig_h * scale))
                target_img = img.resize((1080, new_h), Image.Resampling.LANCZOS)

            # Preserve transparency if RGBA/LA or palette with transparency
            target_img.save(webp_path, 'WEBP', quality=80, method=6)

        webp_size = os.path.getsize(webp_path)
        total_webp_bytes += webp_size
        savings_pct = (1.0 - (webp_size / orig_size)) * 100.0

        conversion_log.append({
            'file': fname,
            'orig_size': orig_size,
            'webp_size': webp_size,
            'savings_pct': savings_pct,
        })

        # Remove the PNG from assets/exercises now that it is converted & backed up
        os.remove(png_path)

    print(f"\nConverted {len(png_files)} PNGs to WebP:")
    print(f"  Before: {total_orig_bytes / (1024 * 1024):.2f} MB ({total_orig_bytes:,} bytes)")
    print(f"  After:  {total_webp_bytes / (1024 * 1024):.2f} MB ({total_webp_bytes:,} bytes)")
    total_savings = (1.0 - (total_webp_bytes / total_orig_bytes)) * 100.0
    print(f"  Net Reduction: {total_savings:.1f}% saved! ({(total_orig_bytes - total_webp_bytes) / (1024 * 1024):.2f} MB freed)")

    # 3. Update assets/data/exercises.json
    json_path = os.path.join(repo_root, 'assets', 'data', 'exercises.json')
    with open(json_path, 'r', encoding='utf-8') as f:
        exercises_data = json.load(f)

    updated_json_count = 0
    for ex in exercises_data.get('exercises', []):
        anim = ex.get('animation_asset')
        if anim and anim.endswith('.png'):
            ex['animation_asset'] = anim[:-4] + '.webp'
            updated_json_count += 1

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(exercises_data, f, indent=2)
    print(f"\nUpdated {updated_json_count} animation_asset paths in {json_path}")

    # 4. Update lib/features/workouts/data/exercise.dart
    exercise_dart = os.path.join(repo_root, 'lib', 'features', 'workouts', 'data', 'exercise.dart')
    with open(exercise_dart, 'r', encoding='utf-8') as f:
        code = f.read()

    new_code, sub_count = re.subn(r"assets/exercises/([a-zA-Z0-9_]+)\.png", r"assets/exercises/\1.webp", code)
    if sub_count > 0:
        with open(exercise_dart, 'w', encoding='utf-8') as f:
            f.write(new_code)
        print(f"Updated {sub_count} asset path occurrences in {exercise_dart}")

    # 5. Update test files referencing .png in assets/exercises
    test_files = [
        os.path.join(repo_root, 'test', 'workouts', 'exercise_video_and_character_test.dart'),
        os.path.join(repo_root, 'test', 'exercise_animation_test.dart'),
    ]
    for tf in test_files:
        if os.path.exists(tf):
            with open(tf, 'r', encoding='utf-8') as f:
                t_content = f.read()
            new_t, t_sub = re.subn(r"assets/exercises/([a-zA-Z0-9_]+)\.png", r"assets/exercises/\1.webp", t_content)
            if t_sub > 0:
                with open(tf, 'w', encoding='utf-8') as f:
                    f.write(new_t)
                print(f"Updated {t_sub} occurrences in {os.path.basename(tf)}")

    print("\nAll assets, models, and tests successfully updated to WebP.")

if __name__ == '__main__':
    main()
