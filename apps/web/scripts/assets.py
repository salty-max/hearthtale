"""
The site's pictures, as PNGs under apps/web/public/:

  logo-<n>.png          the painted logo (assets/logo-master.png), its corners
                        rounded as the addon's own (Media/Logo.tga): 48, 96,
                        192, 320 (the header, the splash, the home page at 2x)
  favicon-16.png, favicon-32.png   the logo, sharpened for its size
  apple-touch-icon.png  180, square and opaque (iOS rounds it itself)
  pwa-192.png, pwa-512.png         the installed app's icon, rounded
  pwa-maskable-512.png  full bleed, for launchers that cut their own shape
  classes/<token>.png   each class's round crest, the game's own
                        (Interface/TargetingFrame/UI-Classes-Circles), as the
                        addon's pages show it
  ui/skull.png          the game's skull (Interface/TargetingFrame/
                        UI-TargetingFrame-Skull): a Hardcore life's mark, as
                        the addon's book shows it

The crests and the skull come from wago.tools' copy of the game files (BLP),
read with Pillow. Run once after changing the logo; the output is committed.

    python3 -m venv /tmp/v && /tmp/v/bin/pip install pillow
    /tmp/v/bin/python apps/web/scripts/assets.py
"""
import io
import os
import urllib.request

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(__file__)
PUBLIC = os.path.join(HERE, "..", "public")
MASTER = os.path.join(HERE, "..", "..", "..", "assets", "logo-master.png")

CIRCLES = 237669  # interface/targetingframe/ui-classes-circles.blp: 64 px a crest
SKULL = 137025  # interface/targetingframe/ui-targetingframe-skull.blp: 32 px
# (CLASS_ICON_TCOORDS: column, row of each class's crest in the texture)
CRESTS = {
    "WARRIOR": (0, 0), "MAGE": (1, 0), "ROGUE": (2, 0), "DRUID": (3, 0),
    "HUNTER": (0, 1), "SHAMAN": (1, 1), "PRIEST": (2, 1), "WARLOCK": (3, 1),
    "PALADIN": (0, 2),
}
# The addon's Media/Logo.tga: radius 34 at 256 px.
RADIUS = 34 / 256


def fetch(fdid: int) -> bytes:
    req = urllib.request.Request(f"https://wago.tools/api/casc/{fdid}?download", headers={"User-Agent": "Hearthtale assets"})
    return urllib.request.urlopen(req, timeout=30).read()


def rounded(img: Image.Image, radius: float) -> Image.Image:
    """Transparent rounded corners, drawn 4x and downsampled for a clean edge."""
    k = 4
    w, h = img.size
    mask = Image.new("L", (w * k, h * k), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w * k - 1, h * k - 1), radius=radius * w * k, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask.resize((w, h), Image.LANCZOS))
    return out


def sized(master: Image.Image, n: int) -> Image.Image:
    """The logo at n px: Lanczos, then sharpened in proportion (small sizes blur most)."""
    img = master.resize((n, n), Image.LANCZOS)
    if n <= 64:
        return img.filter(ImageFilter.UnsharpMask(radius=0.6, percent=120, threshold=1))
    if n <= 200:
        return img.filter(ImageFilter.UnsharpMask(radius=0.8, percent=60, threshold=2))
    return img


def save(img: Image.Image, *path: str) -> None:
    full = os.path.join(PUBLIC, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    img.save(full, optimize=True)
    print(f"{os.path.join(*path):28} {img.size[0]}x{img.size[1]}")


master = Image.open(MASTER).convert("RGB")
for n in (48, 96, 192, 320):
    save(rounded(sized(master, n), RADIUS), f"logo-{n}.png")
for n in (16, 32):
    save(rounded(sized(master, n), RADIUS), f"favicon-{n}.png")
save(sized(master, 180), "apple-touch-icon.png")
save(rounded(sized(master, 192), RADIUS), "pwa-192.png")
save(rounded(sized(master, 512), RADIUS), "pwa-512.png")
save(sized(master, 512), "pwa-maskable-512.png")

circles = Image.open(io.BytesIO(fetch(CIRCLES))).convert("RGBA")
for token, (col, row) in CRESTS.items():
    save(circles.crop((col * 64, row * 64, col * 64 + 64, row * 64 + 64)), "classes", f"{token.lower()}.png")

save(Image.open(io.BytesIO(fetch(SKULL))).convert("RGBA"), "ui", "skull.png")
