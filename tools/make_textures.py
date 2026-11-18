"""Build Farmer Joe's TGA textures from the emblem in the design handoff.

Usage:
    python tools/make_textures.py [path/to/fj-emblem.png]

Writes to Media/:
    Emblem128.tga        window portrait: emblem cropped to a circle (106% zoom),
                         1px black outline and a soft drop shadow (72px design area)
    MinimapIcon64.tga    pitchfork + coins crop (175% zoom, 50%/30% position), circular
    MinimapRing64.tga    white 2px ring for the minimap button (tinted in Lua)
    MinimapBase64.tga    black disc, Coffee Bean inner line, black outer line
    MinimapGlow64.tga    soft Mustard glow shown on hover
    Grain128.tga         tileable dark streaked grain for the window background
    Vignette256.tga      edge darkening over the window background
    Diamond32.tga        white diamond (difficulty pips, ornaments), tinted in Lua
    Corner64.tga         corner filigree, tinted in Lua
All are 32-bit uncompressed TGA with power-of-two sizes.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
MEDIA = os.path.join(ADDON, "Media")
DEFAULT_SRC = os.path.join(ADDON, "WoW Forever Addon UI Mockups", "design_handoff_farmer_joe",
                           "assets", "fj-emblem.png")
SS = 8  # supersampling factor for smooth edges


def save(img, name):
    os.makedirs(MEDIA, exist_ok=True)
    img.save(os.path.join(MEDIA, name), format="TGA", compression=None)
    print("wrote", os.path.join("Media", name), img.size)


def disc_mask(size, cx, cy, r):
    """Antialiased circle mask, all values in final-pixel units."""
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).ellipse(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS), fill=255)
    return big.resize((size, size), Image.LANCZOS)


def ring_mask(size, cx, cy, r_out, r_in):
    return ImageChops.subtract(disc_mask(size, cx, cy, r_out), disc_mask(size, cx, cy, r_in))


def crop_frac(src, x0, y0, x1, y1, out_px):
    w, h = src.size
    box = (round(x0 * w), round(y0 * h), round(x1 * w), round(y1 * h))
    return src.crop(box).resize((out_px, out_px), Image.LANCZOS)


def solid(size, rgb, mask):
    img = Image.new("RGBA", (size, size), rgb + (0,))
    img.putalpha(mask)
    return img


def emblem_portrait(src):
    # Design area 72px: 66px emblem circle centred at (36, 35); 1px black outline;
    # shadow "0 2px 0 1px rgba(0,0,0,.6)" (outline circle offset 2px down).
    N, S = 128, 128 / 72
    cx, cy = 36 * S, 35 * S
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow = solid(N, (0, 0, 0), disc_mask(N, cx, cy + 2 * S, 34 * S).point(lambda v: int(v * 0.6)))
    out = Image.alpha_composite(out, shadow)
    out = Image.alpha_composite(out, solid(N, (0, 0, 0), disc_mask(N, cx, cy, 34 * S)))
    # 106% zoom: the visible 66px is the centre 1/1.06 of the image
    m = (1 - 1 / 1.06) / 2
    diam = round(66 * S)
    face = crop_frac(src, m, m, 1 - m, 1 - m, diam).convert("RGBA")
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    layer.paste(face, (round(cx - diam / 2), round(cy - diam / 2)))
    layer.putalpha(disc_mask(N, cx, cy, 33 * S))
    out = Image.alpha_composite(out, layer)
    save(out, "Emblem128.tga")


def minimap_icon(src):
    # Mock: 24px circle, background-size 175%, position 50% 30%.
    # Image is 42px; offset (-9, -5.4) -> visible fraction x .2143-.7857, y .1286-.7
    N = 64
    img = Image.new("RGBA", (N, N), (0x1D, 0x3A, 0x14, 255))
    face = crop_frac(src, 9 / 42, 5.4 / 42, 33 / 42, 29.4 / 42, N).convert("RGBA")
    img = Image.alpha_composite(img, face)
    img.putalpha(disc_mask(N, N / 2, N / 2, N / 2 - 0.5))
    save(img, "MinimapIcon64.tga")


def minimap_rings():
    # Design area 33px (31px button + 1px black outline each side), centre 16.5.
    N, S = 64, 64 / 33
    c = 16.5 * S
    # base: outer black line, then (ring goes here), Coffee Bean line, black disc
    base = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    base = Image.alpha_composite(base, solid(N, (0, 0, 0), ring_mask(N, c, c, 16.5 * S, 15.5 * S)))
    base = Image.alpha_composite(base, solid(N, (0x1F, 0x13, 0x00), ring_mask(N, c, c, 13.5 * S, 12.5 * S)))
    base = Image.alpha_composite(base, solid(N, (0x0A, 0x0A, 0x0A), disc_mask(N, c, c, 12.5 * S)))
    save(base, "MinimapBase64.tga")
    # ring: 2px, white so Lua can tint it Golden Bronze / Mustard
    save(solid(N, (255, 255, 255), ring_mask(N, c, c, 15.5 * S, 13.5 * S)), "MinimapRing64.tga")
    # glow: "0 0 7px 3px rgba(247,206,91,.7)" -> design area 64px centred, ring radius 15.5
    G = 64
    big = Image.new("L", (G * 4, G * 4), 0)
    r = (15.5 + 3) * 4
    ImageDraw.Draw(big).ellipse((G * 2 - r, G * 2 - r, G * 2 + r, G * 2 + r), fill=int(255 * 0.7))
    big = big.filter(ImageFilter.GaussianBlur(3.5 * 4))
    glow = solid(G, (0xF7, 0xCE, 0x5B), big.resize((G, G), Image.LANCZOS))
    save(glow, "MinimapGlow64.tga")


def grain():
    """Grain128: tileable, horizontally streaked dark speckle (wood/leather feel), drawn at low alpha."""
    import random
    random.seed(7)
    w, h = 24, 128  # low-res noise, stretched horizontally into streaks
    small = Image.new("L", (w, h))
    small.putdata([max(0, min(255, int(random.gauss(128, 46)))) for _ in range(w * h)])
    tiled = Image.new("L", (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            tiled.paste(small, (i * w, j * h))
    N = 128
    big = tiled.resize((N * 3, N * 3), Image.BICUBIC).crop((N, N, N * 2, N * 2))
    alpha = big.point(lambda v: int(max(0, v - 70) * 0.55))
    save(solid(N, (0, 0, 0), alpha), "Grain128.tga")


def vignette():
    """Vignette256: black, transparent in the middle, darker toward the edges."""
    N = 256
    mask = Image.new("L", (N, N))
    px = []
    for y in range(N):
        for x in range(N):
            dx, dy = (x + 0.5) / N * 2 - 1, (y + 0.5) / N * 2 - 1
            d = math.sqrt(dx * dx * 0.85 + dy * dy)
            t = max(0.0, min(1.0, (d - 0.45) / 0.95))
            px.append(int(255 * 0.62 * t * t * (3 - 2 * t)))
    mask.putdata(px)
    save(solid(N, (0, 0, 0), mask), "Vignette256.tga")


def diamond():
    """Diamond32: white antialiased diamond (difficulty pips, section ornaments), tinted in Lua."""
    N = 32
    big = Image.new("L", (N * SS, N * SS), 0)
    c, r = N * SS / 2, (N / 2 - 1.5) * SS
    ImageDraw.Draw(big).polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=255)
    save(solid(N, (255, 255, 255), big.resize((N, N), Image.LANCZOS)), "Diamond32.tga")


def corner():
    """Corner64: top-left filigree (diamond on the corner, fading inner bracket), white, tinted in Lua."""
    N = 64
    S = SS
    big = Image.new("L", (N * S, N * S), 0)
    d = ImageDraw.Draw(big)
    c, r = 9 * S, 7 * S
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=255)
    for i in range(18, 60):  # inner bracket lines fading out
        a = int(255 * max(0.0, 1 - (i - 18) / 42) ** 1.4)
        d.rectangle((i * S, 15 * S, (i + 1) * S, 17 * S), fill=a)
        d.rectangle((15 * S, i * S, 17 * S, (i + 1) * S), fill=a)
    d.ellipse((19 * S, 19 * S, 23 * S, 23 * S), fill=200)
    save(solid(N, (255, 255, 255), big.resize((N, N), Image.LANCZOS)), "Corner64.tga")


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    src = Image.open(src_path).convert("RGB")
    emblem_portrait(src)
    minimap_icon(src)
    minimap_rings()
    grain()
    vignette()
    diamond()
    corner()


if __name__ == "__main__":
    main()
