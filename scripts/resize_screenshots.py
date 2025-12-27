#!/usr/bin/env python3
"""
Resize all images in AppStore/Screenshots to 2560 × 1600px
"""

from PIL import Image
import os
from pathlib import Path

# Configuration
SCREENSHOTS_DIR = Path(__file__).parent.parent / "Screenshots"
TARGET_WIDTH = 2560
TARGET_HEIGHT = 1600

def resize_image(image_path):
    """Resize a single image to target dimensions"""
    try:
        img = Image.open(image_path)
        original_size = img.size
        
        # Resize using high-quality resampling
        img_resized = img.resize(
            (TARGET_WIDTH, TARGET_HEIGHT),
            Image.Resampling.LANCZOS
        )
        
        # Save back to the same file
        img_resized.save(image_path, quality=95, optimize=True)
        
        print(f"✓ {image_path.name}: {original_size} → {(TARGET_WIDTH, TARGET_HEIGHT)}")
        return True
    except Exception as e:
        print(f"✗ {image_path.name}: Error - {e}")
        return False

def main():
    if not SCREENSHOTS_DIR.exists():
        print(f"Error: Directory {SCREENSHOTS_DIR} not found")
        return
    
    # Find all image files
    image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp'}
    image_files = [
        f for f in SCREENSHOTS_DIR.iterdir()
        if f.is_file() and f.suffix.lower() in image_extensions
    ]
    
    if not image_files:
        print("No image files found")
        return
    
    print(f"Found {len(image_files)} image(s)")
    print(f"Resizing to {TARGET_WIDTH} × {TARGET_HEIGHT}px\n")
    
    success_count = sum(resize_image(img) for img in sorted(image_files))
    
    print(f"\nCompleted: {success_count}/{len(image_files)} images resized")

if __name__ == "__main__":
    main()
