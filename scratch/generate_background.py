import os
from PIL import Image, ImageDraw, ImageFont

def generate_dmg_background(output_path):
    # Double the resolution (1080x720) for sharp Retina display rendering in macOS Finder
    width, height = 1080, 720
    
    # Create dark background matching app style
    img = Image.new("RGBA", (width, height), "#0B0B0C")
    draw = ImageDraw.Draw(img)
    
    # Draw a grid with 40px steps (maps to 20px steps on Retina display)
    for y in range(0, height, 40):
        draw.line([(0, y), (width, y)], fill="#151517", width=2)
    for x in range(0, width, 40):
        draw.line([(x, 0), (x, height)], fill="#151517", width=2)
        
    # Draw watermarked logo if available
    logo_path = "logo.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path).convert("RGBA")
            # Resize logo for background watermark (240x240 on 1080x720)
            logo = logo.resize((240, 240))
            # Make it translucent
            logo_alpha = logo.split()[3]
            logo_alpha = logo_alpha.point(lambda p: p * 0.04) # 4% opacity watermark
            logo.putalpha(logo_alpha)
            # Paste in center
            img.paste(logo, (width//2 - 120, height//2 - 130), logo)
        except Exception as e:
            print(f"Skipping logo watermark: {e}")

    # --- SLEEK CHEVRON TRANSITION ARROW ---
    # App icon centers at (280, 300) -> right edge is at x ~ 370
    # Applications icon centers at (800, 300) -> left edge is at x ~ 710
    start_x, end_x = 380, 700
    y = 300
    
    # 1. Draw a dark translucent capsule guide track
    track_h = 32
    draw.rounded_rectangle(
        [(start_x, y - track_h//2), (end_x, y + track_h//2)],
        radius=16,
        fill="#18181B",
        outline="#27272A",
        width=2
    )
    
    # 2. Draw a series of sleek chevrons pointing to the right
    # (x: 460, 520, 580, 640)
    chev_positions = [470, 510, 550, 590, 630]
    chev_colors = ["#27272A", "#3F3F46", "#71717A", "#A1A1AA", "#F4F4F5"]
    
    for idx, pos in enumerate(chev_positions):
        color = chev_colors[idx]
        # Draw chevron shape: >
        # Points: (pos-8, y-8) -> (pos, y) -> (pos-8, y+8)
        draw.line([(pos - 6, y - 8), (pos + 2, y), (pos - 6, y + 8)], fill=color, width=4)
    
    # 3. Draw a white circle marker at the end point
    draw.ellipse([(end_x - 6, y - 6), (end_x + 6, y + 6)], fill="#ffffff")

    # Load high-quality system fonts if available
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 36)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 22)
    except IOError:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # Draw titles (double font size for Retina)
    draw.text((40, 40), "Aferapokitaysky Player", fill="#ffffff", font=font_title)
    draw.text((180, 520), "Перетащите иконку плеера в папку Applications", fill="#88888b", font=font_sub)

    # Make parent directory if not exists
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    img.save(output_path, "PNG", dpi=(144, 144))
    print(f"Retina DMG Background generated successfully at: {output_path}")

if __name__ == "__main__":
    generate_dmg_background("web/dmg_background.png")
