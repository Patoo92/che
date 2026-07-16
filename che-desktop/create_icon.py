from PIL import Image, ImageDraw, ImageFont
import os

def create_icon():
    size = 64
    img = Image.new("RGB", (size, size), color=(20, 20, 30))
    draw = ImageDraw.Draw(img)
    
    draw.ellipse([8, 8, 56, 56], fill=(0, 200, 255), outline=(255, 255, 255), width=2)
    
    try:
        font = ImageFont.truetype("arial.ttf", 24)
    except Exception:
        font = ImageFont.load_default()
    
    draw.text((20, 18), "C", fill=(255, 255, 255), font=font)
    
    output_path = os.path.join(os.path.dirname(__file__), "icon.png")
    img.save(output_path)
    print(f"Icono creado: {output_path}")

if __name__ == "__main__":
    create_icon()
