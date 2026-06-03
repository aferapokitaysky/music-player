import os
from PIL import Image, ImageDraw

def main():
    src_path = "/Users/korova/Desktop/aesthetic-player/f9539e2b-3f71-45da-97d4-0064bc8e8e48.png"
    dst_path = "/Users/korova/Desktop/aesthetic-player/web/logo_seo.png"
    
    if not os.path.exists(src_path):
        print(f"Source file not found: {src_path}")
        return
        
    img = Image.open(src_path).convert("RGBA")
    width, height = img.size
    print(f"Loaded image: {width}x{height}")
    
    # Detect bounds of the circular logo in the top section
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
                
    size = right - left
    cx = (left + right) / 2.0
    cy = top + size / 2.0
    
    margin = 4
    crop_size = size + margin * 2
    x0 = int(cx - crop_size / 2)
    y0 = int(cy - crop_size / 2)
    x1 = int(cx + crop_size / 2)
    y1 = int(cy + crop_size / 2)
    
    cropped = img.crop((x0, y0, x1, y1))
    c_w, c_h = cropped.size
    
    # Create image with solid white background
    result_img = Image.new("RGBA", (c_w, c_h), (255, 255, 255, 255))
    
    # Copy the dark elements of the logo as black pixels
    for y in range(c_h):
        for x in range(c_w):
            r, g, b, a = cropped.getpixel((x, y))
            brightness = (r + g + b) / 3.0
            
            if brightness < 120:
                if brightness < 60:
                    alpha = 255
                else:
                    alpha = int(255 * (120 - brightness) / 60.0)
                
                # Write black pixels with alpha antialiasing over white background
                result_img.putpixel((x, y), (0, 0, 0, alpha))
                
    result_img.save(dst_path, "PNG")
    print(f"Successfully processed SEO logo and saved to {dst_path}")

if __name__ == "__main__":
    main()
