import os
from PIL import Image, ImageDraw

src_path = 'docs/logo.png'
dest_dir = 'docs'

if not os.path.exists(src_path):
    print(f"Error: {src_path} not found.")
    exit(1)

# Load original logo (white on transparent)
logo = Image.open(src_path).convert("RGBA")
width, height = logo.size

# Create a solid dark background canvas (matching the player's brand color, e.g. #0B0B0C)
# with a rounded rectangle or circle to look premium
bg_color = (11, 11, 12, 255) # Dark theme color #0B0B0C
canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
draw = ImageDraw.Draw(canvas)

# Draw a beautiful smooth circular background behind the logo
# (leaving a small 5% margin so the white logo fits nicely inside)
margin = int(width * 0.05)
draw.ellipse(
    [margin, margin, width - margin, height - margin],
    fill=bg_color
)

# Paste the white logo on top of the dark circular background
combined = Image.alpha_composite(canvas, logo)

# Generate favicon.ico containing standard sizes (16, 32, 48)
combined.save(os.path.join(dest_dir, 'favicon.ico'), sizes=[(16, 16), (32, 32), (48, 48)])
print("Generated favicon.ico with solid dark background")

# Generate standard PNG favicons
sizes = [16, 32, 48, 96, 192]
for size in sizes:
    resized_img = combined.resize((size, size), Image.Resampling.LANCZOS)
    resized_img.save(os.path.join(dest_dir, f'favicon-{size}x{size}.png'))
    print(f"Generated favicon-{size}x{size}.png with solid dark background")

print("All favicons successfully generated with a solid premium background!")
