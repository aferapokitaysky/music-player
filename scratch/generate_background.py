import os
from PIL import Image, ImageDraw, ImageFont

def generate_dmg_background(output_path):
    width, height = 540, 360
    # Create dark background matching app style
    img = Image.new("RGBA", (width, height), "#0B0B0C")
    draw = ImageDraw.Draw(img)
    
    # Try drawing a subtle grid or lines to make it look technical and premium
    for y in range(0, height, 20):
        draw.line([(0, y), (width, y)], fill="#171719", width=1)
    for x in range(0, width, 20):
        draw.line([(x, 0), (x, height)], fill="#171719", width=1)
        
    # Draw watermarked logo if available
    logo_path = "logo.png"
    if os.path.exists(logo_path):
        try:
            logo = Image.open(logo_path).convert("RGBA")
            # Resize logo for background watermark
            logo = logo.resize((120, 120))
            # Make it translucent
            logo_alpha = logo.split()[3]
            logo_alpha = logo_alpha.point(lambda p: p * 0.05) # 5% opacity watermark
            logo.putalpha(logo_alpha)
            # Paste in center
            img.paste(logo, (width//2 - 60, height//2 - 70), logo)
        except Exception as e:
            print(f"Skipping logo watermark: {e}")

    # Draw sleek drag-and-drop indicator line with arrow
    # App is at {140, 150}, Applications is at {400, 150}
    start_x, start_y = 190, 150
    end_x, end_y = 350, 150
    
    # Draw sleek white dashes
    draw.line([(start_x, start_y), (end_x, end_y)], fill="#333336", width=2)
    # Draw arrow head
    draw.polygon([(end_x, end_y - 6), (end_x + 8, end_y), (end_x, end_y + 6)], fill="#ffffff")
    
    # Draw title text and guides
    # Load a default font or standard system font if available
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 20)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 12)
    except IOError:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # Draw texts
    draw.text((20, 20), "Aferapokitaysky Player", fill="#ffffff", font=font_title)
    draw.text((20, 48), "Установка", fill="#88888b", font=font_sub)
    draw.text((120, 260), "Перетащите иконку плеера в папку Applications", fill="#88888b", font=font_sub)

    # Make parent directory if not exists
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"DMG Background generated successfully at: {output_path}")

if __name__ == "__main__":
    generate_dmg_background("web/dmg_background.png")
