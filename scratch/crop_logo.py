import os
from PIL import Image, ImageDraw

def main():
    src_path = "/Users/korova/.gemini/antigravity-ide/brain/f7539277-1b6f-4f20-922d-7eb6d02f65d9/aferapokitaysky_logo_1779284571354.png"
    dst_path = "/Users/korova/Desktop/massegnger/aesthetic-player/logo.png"
    
    if not os.path.exists(src_path):
        print(f"Source file not found: {src_path}")
        return
        
    img = Image.open(src_path).convert("RGBA")
    width, height = img.size
    print(f"Loaded image: {width}x{height}")
    
    # Let's find the central bright/white squircle bounding box.
    # We can scan pixels to find the boundaries of the white logo.
    # The logo itself is a white/silver squircle on a gradient background.
    # Let's scan from the edges towards the center to find where the bright region begins.
    # A bright pixel can be defined by having RGB values above a threshold, e.g. R > 180, G > 180, B > 180.
    # Let's scan from top, bottom, left, right to find the bounding box of pixels with R > 150, G > 150, B > 150.
    
    threshold = 150
    left_bound = width
    right_bound = 0
    top_bound = height
    bottom_bound = 0
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = img.getpixel((x, y))
            if r > threshold and g > threshold and b > threshold:
                if x < left_bound: left_bound = x
                if x > right_bound: right_bound = x
                if y < top_bound: top_bound = y
                if y > bottom_bound: bottom_bound = y
                
    print(f"Detected white logo bounds: Left={left_bound}, Right={right_bound}, Top={top_bound}, Bottom={bottom_bound}")
    
    # If the bounds are reasonable, let's use them to define the crop circle/squircle.
    # Otherwise, fallback to a standard central square.
    if left_bound < right_bound and top_bound < bottom_bound:
        # Calculate center and diameter
        cx = (left_bound + right_bound) / 2
        cy = (top_bound + bottom_bound) / 2
        w = right_bound - left_bound
        h = bottom_bound - top_bound
        size = min(w, h)
        print(f"Center: ({cx}, {cy}), Size: {size}")
    else:
        # Fallback
        cx, cy = width / 2, height / 2
        size = int(width * 0.76) # standard squircle size in 1024x1024 is around 780px
        print(f"Fallback center: ({cx}, {cy}), Size: {size}")
        
    # We want a perfect circle crop. Let's crop a square centered at (cx, cy) with size equal to the detected size.
    # To keep a tiny margin of safety, we can scale the size slightly or just use a circle mask.
    half_size = size / 2
    # Ensure within bounds
    x0 = max(0, int(cx - half_size))
    y0 = max(0, int(cy - half_size))
    x1 = min(width, int(cx + half_size))
    y1 = min(height, int(cy + half_size))
    
    cropped = img.crop((x0, y0, x1, y1))
    
    # Now make it a perfect circle with transparent background
    c_w, c_h = cropped.size
    mask = Image.new("L", (c_w, c_h), 0)
    draw = ImageDraw.Draw(mask)
    # Draw a white circle on the black mask
    draw.ellipse((0, 0, c_w, c_h), fill=255)
    
    # Create final transparent image
    circle_img = Image.new("RGBA", (c_w, c_h), (0, 0, 0, 0))
    circle_img.paste(cropped, (0, 0), mask=mask)
    
    # Save the cropped circular logo
    circle_img.save(dst_path, "PNG")
    print(f"Successfully processed and saved circular transparent logo to {dst_path}")
    
    # Also save to f9539e2b-3f71-45da-97d4-0064bc8e8e48.png just to be consistent
    circle_img.save("/Users/korova/Desktop/massegnger/aesthetic-player/f9539e2b-3f71-45da-97d4-0064bc8e8e48.png", "PNG")

if __name__ == "__main__":
    main()
