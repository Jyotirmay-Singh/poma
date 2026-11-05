"""Windows-only derivatives of Poma's existing original mark (build tool)."""
from pathlib import Path
from PIL import Image
from generate_branding import mark, PAPER

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "mobile/windows/runner/resources"
PACKAGE = ROOT / "release/windows/Assets"


def main():
    RESOURCES.mkdir(parents=True, exist_ok=True)
    PACKAGE.mkdir(parents=True, exist_ok=True)
    icon = mark(1024, PAPER)
    icon.save(RESOURCES / "app_icon.ico", sizes=[(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)])
    transparent = mark(1024)
    cropped = transparent.crop(transparent.getbbox())
    tray = Image.new("RGBA", (256, 256))
    cropped.thumbnail((220, 220), Image.Resampling.LANCZOS)
    tray.alpha_composite(cropped, ((256 - cropped.width) // 2, (256 - cropped.height) // 2))
    sizes = [(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
    tray.save(RESOURCES / "tray_icon.ico", sizes=sizes)
    for name, color in (("tray_white.ico", "white"), ("tray_black.ico", "black")):
        mono = Image.new("RGBA", tray.size, color)
        mono.putalpha(tray.getchannel("A"))
        mono.save(RESOURCES / name, sizes=sizes)
    for name, size in (("Square44x44Logo", 44), ("Square150x150Logo", 150), ("StoreLogo", 50)):
        for scale in (100, 125, 150, 200, 400):
            n = round(size * scale / 100)
            icon.resize((n, n), Image.Resampling.LANCZOS).save(PACKAGE / f"{name}.scale-{scale}.png", optimize=True)
        icon.resize((size, size), Image.Resampling.LANCZOS).save(PACKAGE / f"{name}.png", optimize=True)
    print("Generated Windows icons and MSIX visual assets only.")


if __name__ == "__main__":
    main()
