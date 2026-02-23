#!/usr/bin/env python3
"""Generate app icon: Denny character on a maze background with ocean colors."""

from PIL import Image, ImageDraw, ImageFilter
import random
import math

SIZE = 1024
MARGIN = 80
BASE_CELL_SIZE = 80
WALL_WIDTH = 14
PATH_COLOR = (255, 255, 255, 180)  # semi-transparent white


def draw_gradient(img: Image.Image):
    """Ocean gradient: deep blue top-left to teal bottom-right."""
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * SIZE)
            r = int(30 + t * 10)
            g = int(80 + t * 120)
            b = int(180 + t * 40)
            draw.point((x, y), fill=(r, g, b))


def draw_gradient_fast(img: Image.Image):
    """Fast ocean gradient using line-by-line approach."""
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / SIZE
        r = int(25 + t * 15)
        g = int(70 + t * 100)
        b = int(190 - t * 30)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))


def generate_maze(cols, rows):
    """Generate a maze using recursive backtracking. Returns set of removed walls."""
    visited = [[False] * cols for _ in range(rows)]
    walls = set()
    # Initialize all walls
    for r in range(rows):
        for c in range(cols):
            if c < cols - 1:
                walls.add(((r, c), (r, c + 1)))  # right wall
            if r < rows - 1:
                walls.add(((r, c), (r + 1, c)))  # bottom wall

    removed = set()
    stack = [(0, 0)]
    visited[0][0] = True

    random.seed(42)  # deterministic for reproducible icon

    while stack:
        r, c = stack[-1]
        neighbors = []
        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and not visited[nr][nc]:
                neighbors.append((nr, nc))

        if neighbors:
            nr, nc = random.choice(neighbors)
            visited[nr][nc] = True
            # Remove wall between current and neighbor
            wall = (min((r, c), (nr, nc)), max((r, c), (nr, nc)))
            removed.add(wall)
            stack.append((nr, nc))
        else:
            stack.pop()

    return walls - removed, removed


def draw_maze(img: Image.Image, walls, cols, rows, offset_x, offset_y, cell_size):
    """Draw maze walls as white lines."""
    draw = ImageDraw.Draw(img, "RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)

    # Draw outer border
    x0, y0 = offset_x, offset_y
    x1 = offset_x + cols * cell_size
    y1 = offset_y + rows * cell_size

    # Draw cell walls
    for (r1, c1), (r2, c2) in walls:
        if r1 == r2:  # vertical wall (between columns)
            wx = offset_x + max(c1, c2) * cell_size
            wy1 = offset_y + r1 * cell_size
            wy2 = wy1 + cell_size
            overlay_draw.line([(wx, wy1), (wx, wy2)], fill=PATH_COLOR, width=WALL_WIDTH)
        else:  # horizontal wall (between rows)
            wy = offset_y + max(r1, r2) * cell_size
            wx1 = offset_x + c1 * cell_size
            wx2 = wx1 + cell_size
            overlay_draw.line([(wx1, wy), (wx2, wy)], fill=PATH_COLOR, width=WALL_WIDTH)

    # Draw border
    border_color = (255, 255, 255, 200)
    overlay_draw.line([(x0, y0), (x1, y0)], fill=border_color, width=WALL_WIDTH)
    overlay_draw.line([(x0, y1), (x1, y1)], fill=border_color, width=WALL_WIDTH)
    overlay_draw.line([(x0, y0), (x0, y1)], fill=border_color, width=WALL_WIDTH)
    overlay_draw.line([(x1, y0), (x1, y1)], fill=border_color, width=WALL_WIDTH)

    # Blur the maze slightly for a softer look
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=1.5))
    img.paste(Image.alpha_composite(Image.new("RGBA", img.size, (0, 0, 0, 0)), overlay), (0, 0), overlay)


def add_bubbles(img: Image.Image):
    """Add subtle decorative bubbles."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    random.seed(99)
    for _ in range(15):
        x = random.randint(50, SIZE - 50)
        y = random.randint(50, SIZE - 50)
        r = random.randint(8, 25)
        alpha = random.randint(30, 70)
        draw.ellipse([(x - r, y - r), (x + r, y + r)],
                     outline=(255, 255, 255, alpha), width=2)
    img.paste(Image.alpha_composite(Image.new("RGBA", img.size, (0, 0, 0, 0)), overlay), (0, 0), overlay)


def main():
    # Create base image
    img = Image.new("RGBA", (SIZE, SIZE))
    draw_gradient_fast(img)

    # Generate and draw maze — fill nearly edge-to-edge
    cols, rows = 10, 10
    cell_size = int(BASE_CELL_SIZE * ((SIZE - 40) / (cols * BASE_CELL_SIZE)))  # ~98px
    offset_x = (SIZE - cols * cell_size) // 2
    offset_y = (SIZE - rows * cell_size) // 2

    walls, _ = generate_maze(cols, rows)
    draw_maze(img, walls, cols, rows, offset_x, offset_y, cell_size)

    # Add bubbles
    add_bubbles(img)

    # Overlay Denny character — large and centered
    denny = Image.open("output/characters/denny.png").convert("RGBA")
    denny_size = 650
    denny = denny.resize((denny_size, denny_size), Image.LANCZOS)

    # Position Denny centered, slightly below middle
    dx = (SIZE - denny_size) // 2
    dy = (SIZE - denny_size) // 2 + 60

    # Add subtle shadow behind Denny
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        [(dx + 40, dy + denny_size - 60), (dx + denny_size - 40, dy + denny_size + 10)],
        fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(img, shadow)

    # Paste Denny
    img.paste(denny, (dx, dy), denny)

    # Save
    output_path = "../LowDopamineLabyrinth/LowDopamineLabyrinth/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    img_rgb = img.convert("RGB")
    img_rgb.save(output_path, "PNG")
    print(f"App icon saved to {output_path}")

    # Also save a copy for reference
    img_rgb.save("output/app_icon.png", "PNG")
    print("Copy saved to output/app_icon.png")


if __name__ == "__main__":
    main()
