#!/usr/bin/env python3
"""Generate a pixel art spider sprite for the game"""

from PIL import Image, ImageDraw

# Create a 64x64 pixel sprite
size = 64
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Spider color (dark brown/black)
body_color = (60, 40, 30, 255)
leg_color = (40, 20, 10, 255)
eye_color = (255, 100, 100, 255)

# Draw spider body (oval/round in center)
body_x, body_y = 32, 32
body_radius = 10

# Main body (larger circle)
draw.ellipse(
    [body_x - body_radius, body_y - body_radius + 3,
     body_x + body_radius, body_y + body_radius + 3],
    fill=body_color
)

# Head part (smaller circle above body)
head_radius = 6
draw.ellipse(
    [body_x - head_radius, body_y - body_radius - 5,
     body_x + head_radius, body_y - body_radius + 5],
    fill=body_color
)

# Draw 8 legs (4 on each side)
leg_length = 12
leg_thickness = 2

# Left front legs
for i, y_offset in enumerate([-8, -2]):
    # Draw line-like legs using rectangles
    draw.rectangle(
        [body_x - leg_length - 2, body_y + y_offset,
         body_x - 2, body_y + y_offset + leg_thickness],
        fill=leg_color
    )

# Left back legs
for i, y_offset in enumerate([2, 8]):
    draw.rectangle(
        [body_x - leg_length - 2, body_y + y_offset,
         body_x - 2, body_y + y_offset + leg_thickness],
        fill=leg_color
    )

# Right front legs
for i, y_offset in enumerate([-8, -2]):
    draw.rectangle(
        [body_x + 2, body_y + y_offset,
         body_x + leg_length + 2, body_y + y_offset + leg_thickness],
        fill=leg_color
    )

# Right back legs
for i, y_offset in enumerate([2, 8]):
    draw.rectangle(
        [body_x + 2, body_y + y_offset,
         body_x + leg_length + 2, body_y + y_offset + leg_thickness],
        fill=leg_color
    )

# Draw eyes (two small red circles)
eye_radius = 2
draw.ellipse(
    [body_x - 4 - eye_radius, body_y - body_radius - 3 - eye_radius,
     body_x - 4 + eye_radius, body_y - body_radius - 3 + eye_radius],
    fill=eye_color
)
draw.ellipse(
    [body_x + 4 - eye_radius, body_y - body_radius - 3 - eye_radius,
     body_x + 4 + eye_radius, body_y - body_radius - 3 + eye_radius],
    fill=eye_color
)

# Save the sprite
output_path = "vampire-raiders-client/assets/enemies/spider.png"
img.save(output_path)
print(f"Spider sprite created: {output_path}")
