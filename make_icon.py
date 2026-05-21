import sys
from PIL import Image
import os
import subprocess

def create_icns(input_image_path):
    # Load the image
    try:
        img = Image.open(input_image_path)
    except Exception as e:
        print(f"Error loading image: {e}")
        return False

    # The user provided an image with a big logo on top and small icons below.
    # The big logo is roughly in the top half. We'll crop it out.
    width, height = img.size
    
    # Assuming the main logo is in a square at the top
    crop_size = min(width, int(height * 0.6))
    left = (width - crop_size) / 2
    top = 0
    right = left + crop_size
    bottom = crop_size
    
    cropped_img = img.crop((left, top, right, bottom))
    
    # Make sure it's a square and has alpha channel
    cropped_img = cropped_img.convert("RGBA")
    
    # Create an iconset folder
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Generate all required icon sizes for macOS
    sizes = [
        (16, "16x16"),
        (32, "16x16@2x"),
        (32, "32x32"),
        (64, "32x32@2x"),
        (128, "128x128"),
        (256, "128x128@2x"),
        (256, "256x256"),
        (512, "256x256@2x"),
        (512, "512x512"),
        (1024, "512x512@2x")
    ]
    
    for size, name in sizes:
        resized_img = cropped_img.resize((size, size), Image.Resampling.LANCZOS)
        resized_img.save(os.path.join(iconset_dir, f"icon_{name}.png"))
        
    # Run iconutil to create the .icns file
    try:
        subprocess.run(["iconutil", "-c", "icns", iconset_dir], check=True)
        print("Successfully created AppIcon.icns")
        # Cleanup iconset dir
        subprocess.run(["rm", "-rf", iconset_dir])
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to run iconutil: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 make_icon.py <image_path>")
        sys.exit(1)
        
    create_icns(sys.argv[1])
