#!/usr/bin/env python3
"""
Generate OG (Open Graph) and Twitter Card images for JustLayMe
Creates 1200x630 JPG images with brand colors and messaging
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os

    # Brand colors
    DARK_BG = "#0f0f23"
    ACCENT_PURPLE = "#8b5cf6"
    ACCENT_CYAN = "#06b6d4"
    WHITE = "#ffffff"
    LIGHT_GRAY = "#e5e7eb"

    # Image dimensions
    WIDTH = 1200
    HEIGHT = 630

    def create_gradient_background(width, height, color1, color2):
        """Create a gradient background image"""
        image = Image.new('RGB', (width, height), color1)
        pixels = image.load()

        # Create gradient from color1 to color2
        for x in range(width):
            for y in range(height):
                # Diagonal gradient
                ratio = (x + y) / (width + height)
                r1, g1, b1 = int(color1[1:3], 16), int(color1[3:5], 16), int(color1[5:7], 16)
                r2, g2, b2 = int(color2[1:3], 16), int(color2[3:5], 16), int(color2[5:7], 16)

                r = int(r1 + (r2 - r1) * ratio)
                g = int(g1 + (g2 - g1) * ratio)
                b = int(b1 + (b2 - b1) * ratio)

                pixels[x, y] = (r, g, b)

        return image

    def create_og_image():
        """Create OG image with dark background and gradient"""
        img = create_gradient_background(WIDTH, HEIGHT, DARK_BG, ACCENT_CYAN)
        draw = ImageDraw.Draw(img)

        # Try to use a nice font, fallback to default
        try:
            title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 90)
            subtitle_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 48)
            tagline_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 36)
        except:
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()
            tagline_font = ImageFont.load_default()

        # Add decorative circles
        circle_radius = 120
        draw.ellipse(
            [(WIDTH - circle_radius * 2 - 50, HEIGHT - circle_radius * 2 - 30),
             (WIDTH - 50, HEIGHT - 30)],
            outline=ACCENT_PURPLE,
            width=3
        )

        # Draw main title
        title = "JustLayMe"
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (WIDTH - title_width) / 2
        draw.text((title_x, 150), title, fill=WHITE, font=title_font)

        # Draw subtitle
        subtitle = "Unfiltered AI Conversations"
        subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
        subtitle_x = (WIDTH - subtitle_width) / 2
        draw.text((subtitle_x, 280), subtitle, fill=ACCENT_CYAN, font=subtitle_font)

        # Draw tagline
        tagline = "Chat Without Restrictions"
        tagline_bbox = draw.textbbox((0, 0), tagline, font=tagline_font)
        tagline_width = tagline_bbox[2] - tagline_bbox[0]
        tagline_x = (WIDTH - tagline_width) / 2
        draw.text((tagline_x, 370), tagline, fill=LIGHT_GRAY, font=tagline_font)

        return img

    def create_twitter_image():
        """Create Twitter Card image with slightly different layout"""
        img = create_gradient_background(WIDTH, HEIGHT, DARK_BG, ACCENT_PURPLE)
        draw = ImageDraw.Draw(img)

        # Try to use a nice font, fallback to default
        try:
            title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 85)
            subtitle_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 42)
            tagline_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 32)
        except:
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()
            tagline_font = ImageFont.load_default()

        # Add decorative element
        draw.rectangle(
            [(50, 50), (100, 100)],
            outline=ACCENT_PURPLE,
            width=3
        )

        # Draw main title
        title = "JustLayMe"
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_x = (WIDTH - title_width) / 2
        draw.text((title_x, 120), title, fill=WHITE, font=title_font)

        # Draw subtitle
        subtitle = "Unfiltered AI Conversations"
        subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
        subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
        subtitle_x = (WIDTH - subtitle_width) / 2
        draw.text((subtitle_x, 250), subtitle, fill=ACCENT_PURPLE, font=subtitle_font)

        # Draw tagline
        tagline = "Chat Without Restrictions"
        tagline_bbox = draw.textbbox((0, 0), tagline, font=tagline_font)
        tagline_width = tagline_bbox[2] - tagline_bbox[0]
        tagline_x = (WIDTH - tagline_width) / 2
        draw.text((tagline_x, 340), tagline, fill=WHITE, font=tagline_font)

        return img

    def main():
        output_dir = "/home/fastl/JustLayMe-react/public"

        print("Generating OG and Twitter Card images...")

        # Create OG image
        og_img = create_og_image()
        og_path = os.path.join(output_dir, "og-image.jpg")
        og_img.save(og_path, "JPEG", quality=90, optimize=True)
        print(f"Created: {og_path}")

        # Create Twitter image
        twitter_img = create_twitter_image()
        twitter_path = os.path.join(output_dir, "twitter-image.jpg")
        twitter_img.save(twitter_path, "JPEG", quality=90, optimize=True)
        print(f"Created: {twitter_path}")

        print("\nImages generated successfully!")
        print(f"Dimensions: {WIDTH}x{HEIGHT} pixels")
        print(f"Format: JPEG (90% quality)")
        print(f"\nAdd to your HTML head:")
        print('  <meta property="og:image" content="https://yourdomain.com/og-image.jpg" />')
        print('  <meta property="og:image:width" content="1200" />')
        print('  <meta property="og:image:height" content="630" />')
        print('  <meta name="twitter:image" content="https://yourdomain.com/twitter-image.jpg" />')

    if __name__ == "__main__":
        main()

except ImportError:
    print("Error: PIL (Pillow) is not installed.")
    print("\nTo create the images, install Pillow:")
    print("  pip install Pillow")
    print("\nOr use the included specification document to create images manually.")
    exit(1)
