#!/usr/bin/env python3
"""
Generate favicon files from SVG source.
This script creates PNG and ICO versions of the favicon for better browser compatibility.
"""

import os
import base64
from PIL import Image, ImageDraw
import io

def create_favicon_png(size, output_path):
    """Create a PNG favicon of the specified size."""
    # Create a blue circular background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Background circle
    draw.ellipse([0, 0, size-1, size-1], fill=(14, 165, 233, 255))
    
    # Document background (white rectangle)
    doc_margin = size // 4
    doc_width = size - (doc_margin * 2)
    doc_height = int(doc_width * 1.125)  # Slightly taller than wide
    doc_x = doc_margin
    doc_y = (size - doc_height) // 2
    
    draw.rectangle([doc_x, doc_y, doc_x + doc_width, doc_y + doc_height], 
                  fill=(255, 255, 255, 240), outline=(2, 132, 199, 255), width=1)
    
    # Document lines
    line_start_x = doc_x + size // 16
    line_end_x = doc_x + doc_width - size // 16
    line_spacing = max(2, size // 16)
    line_y = doc_y + size // 8
    
    for i in range(4):
        opacity = int(255 * (0.8 - i * 0.2))
        line_color = (14, 165, 233, opacity)
        line_end = line_end_x - (i * size // 32)  # Vary line lengths
        
        # PIL doesn't support alpha in line drawing directly, so we use rectangles
        draw.rectangle([line_start_x, line_y + i * line_spacing, 
                       line_end, line_y + i * line_spacing + 1], 
                      fill=line_color)
    
    # Central focus dot
    center = size // 2
    outer_radius = max(2, size // 16)
    inner_radius = max(1, size // 32)
    
    draw.ellipse([center - outer_radius, center - outer_radius, 
                 center + outer_radius, center + outer_radius], 
                fill=(2, 132, 199, 255))
    
    draw.ellipse([center - inner_radius, center - inner_radius, 
                 center + inner_radius, center + inner_radius], 
                fill=(255, 255, 255, 255))
    
    img.save(output_path, 'PNG')
    print(f"✅ Created {output_path}")

def main():
    """Generate all favicon files."""
    static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'app', 'static')
    
    print("🎨 Generating favicon files...")
    print(f"Output directory: {static_dir}")
    
    # Create PNG favicons
    create_favicon_png(16, os.path.join(static_dir, 'favicon-16x16.png'))
    create_favicon_png(32, os.path.join(static_dir, 'favicon-32x32.png'))
    create_favicon_png(180, os.path.join(static_dir, 'apple-touch-icon.png'))
    
    # Create ICO file (using 32x32 PNG as base)
    png_32_path = os.path.join(static_dir, 'favicon-32x32.png')
    ico_path = os.path.join(static_dir, 'favicon.ico')
    
    with Image.open(png_32_path) as img:
        img.save(ico_path, format='ICO', sizes=[(32, 32), (16, 16)])
    
    print(f"✅ Created {ico_path}")
    print("")
    print("🎉 All favicon files generated successfully!")
    print("")
    print("📋 Generated files:")
    print("   - favicon.svg (already exists)")
    print("   - favicon-16x16.png")
    print("   - favicon-32x32.png") 
    print("   - favicon.ico")
    print("   - apple-touch-icon.png")

if __name__ == "__main__":
    main() 