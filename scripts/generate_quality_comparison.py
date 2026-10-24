import os
from PIL import Image, ImageDraw, ImageFont

def make_side_by_side(orig_path, webp_path, exercise_name, output_path):
    orig_img = Image.open(orig_path).convert('RGB')
    webp_img = Image.open(webp_path).convert('RGB')

    orig_size_kb = os.path.getsize(orig_path) / 1024
    webp_size_kb = os.path.getsize(webp_path) / 1024
    savings_pct = (1.0 - (webp_size_kb / orig_size_kb)) * 100

    target_h = 512
    orig_w = int(orig_img.width * (target_h / orig_img.height))
    webp_w = int(webp_img.width * (target_h / webp_img.height))

    orig_resized = orig_img.resize((orig_w, target_h), Image.Resampling.LANCZOS)
    webp_resized = webp_img.resize((webp_w, target_h), Image.Resampling.LANCZOS)

    header_h = 64
    canvas_w = orig_w + webp_w + 30
    canvas_h = target_h + header_h + 20

    canvas = Image.new('RGB', (canvas_w, canvas_h), (21, 29, 23)) # Dark background matching app
    draw = ImageDraw.Draw(canvas)

    # Paste images
    canvas.paste(orig_resized, (10, header_h))
    canvas.paste(webp_resized, (orig_w + 20, header_h))

    # Draw labels
    draw.text((10, 12), f"{exercise_name} - Original PNG", fill=(247, 248, 242))
    draw.text((10, 34), f"Size: {orig_size_kb:.1f} KB | 100% Quality", fill=(166, 183, 166))

    draw.text((orig_w + 20, 12), f"{exercise_name} - Optimized WebP", fill=(139, 207, 69))
    draw.text((orig_w + 20, 34), f"Size: {webp_size_kb:.1f} KB ({savings_pct:.1f}% savings)", fill=(139, 207, 69))

    canvas.save(output_path, 'JPEG', quality=95)
    print(f"Saved comparison to {output_path}")

def main():
    repo_root = r'e:\FitBuddy'
    artifacts_dir = r'C:\Users\DELL\.gemini\antigravity-ide\brain\b48c3fcf-b24b-46e9-bee2-7f65229cbc7b'

    exercises = [
        ('squat', 'Squat'),
        ('pushup', 'Push-Up'),
        ('lunge', 'Lunge'),
        ('cobra_pose', 'Cobra Pose'),
        ('high_knees', 'High Knees'),
    ]

    for key, name in exercises:
        orig = os.path.join(repo_root, 'assets', 'exercises_originals', f"{key}.png")
        webp = os.path.join(repo_root, 'assets', 'exercises', f"{key}.webp")
        out = os.path.join(artifacts_dir, f"comparison_{key}.jpg")
        make_side_by_side(orig, webp, name, out)

if __name__ == '__main__':
    main()
