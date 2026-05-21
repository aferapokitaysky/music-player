import os
import numpy as np
from PIL import Image, ImageDraw

def main():
    src_path = "/Users/korova/Desktop/massegnger/aesthetic-player/f9539e2b-3f71-45da-97d4-0064bc8e8e48.png"
    dst_path = "/Users/korova/Desktop/massegnger/aesthetic-player/logo.png"
    
    if not os.path.exists(src_path):
        print(f"Source file not found: {src_path}")
        return
        
    img = Image.open(src_path).convert("RGBA")
    width, height = img.size
    print(f"Loaded image: {width}x{height}")
    
    # 1. Detect bounds.
    # The circle has nothing on its left or right. So 'left' and 'right' boundaries are 100% clean!
    # Let's find all dark pixels (RGB < 80) in the top 55% of the image (well above the text and middle separator line).
    threshold = 80
    left = width
    right = 0
    top = height
    
    for y in range(int(height * 0.55)):
        for x in range(width):
            r, g, b, a = img.getpixel((x, y))
            if r < threshold and g < threshold and b < threshold:
                if x < left: left = x
                if x > right: right = x
                if y < top: top = y
                
    print(f"Detected clean circle bounds: Left={left}, Right={right}, Top={top}")
    
    # Since it is a perfect circle:
    # Width = Right - Left
    # Height = Width
    # Center X = (Left + Right) / 2
    # Center Y = Top + Width / 2
    size = right - left
    cx = (left + right) / 2.0
    cy = top + size / 2.0
    
    print(f"Calculated circle geometry: Center=({cx}, {cy}), Diameter={size}")
    
    # Crop the exact circle area. Let's add a small margin of 2px to ensure the outline isn't clipped
    margin = 2
    crop_size = size + margin * 2
    x0 = int(cx - crop_size / 2)
    y0 = int(cy - crop_size / 2)
    x1 = int(cx + crop_size / 2)
    y1 = int(cy + crop_size / 2)
    
    cropped = img.crop((x0, y0, x1, y1))
    c_w, c_h = cropped.size
    print(f"Cropped to: {c_w}x{c_h} centered at ({cx}, {cy})")
    
    # 2. Make it a transparent white logo!
    result_img = Image.new("RGBA", (c_w, c_h), (0, 0, 0, 0))
    
    # We want a perfect circle mask to ensure absolutely no pixels outside the outer circle are kept
    mask = Image.new("L", (c_w, c_h), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, c_w, c_h), fill=255)
    
    for y in range(c_h):
        for x in range(c_w):
            # Only process pixels inside the circle mask
            if mask.getpixel((x, y)) == 255:
                r, g, b, a = cropped.getpixel((x, y))
                brightness = (r + g + b) / 3.0
                
                # Black lines have low brightness (< 120)
                if brightness < 120:
                    if brightness < 60:
                        alpha = 255
                    else:
                        alpha = int(255 * (120 - brightness) / 60.0)
                        
                    result_img.putpixel((x, y), (255, 255, 255, alpha))
                    
    # 3. Save as logo.png
    result_img.save(dst_path, "PNG")
    print(f"Successfully processed white transparent logo and saved to {dst_path}")

if __name__ == "__main__":
    main()
