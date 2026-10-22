"""Generate Poma's original static mark; Pillow is a build-only dependency."""

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "mobile/android/app/src/main/res"
IOS = ROOT / "mobile/ios/Runner/Assets.xcassets"
PAPER = "#F8F9FD"
IRIS = "#6854C8"
TEAL = "#147D80"


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def mark(size, background=None):
    scale = 3
    image = Image.new("RGBA", (1024 * scale, 1024 * scale), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def dot(x, y, radius, color):
        draw.ellipse(tuple(round(v * scale) for v in (x-radius, y-radius, x+radius, y+radius)), fill=color)

    # Pillow strokes inside its bounding box; SVG strokes around the radius.
    draw.arc(tuple(v * scale for v in (218, 218, 806, 806)), 30, 330, fill=IRIS, width=72 * scale)
    for angle in (30, 330):
        dot(512 + 258 * math.cos(math.radians(angle)), 512 + 258 * math.sin(math.radians(angle)), 36, IRIS)
    draw.line([(512*scale, 354*scale), (512*scale, 512*scale), (646*scale, 512*scale)], fill=IRIS, width=64*scale, joint="curve")
    for point in ((512, 354), (512, 512), (646, 512)):
        dot(*point, 32, IRIS)
    dot(770, 512, 44, TEAL)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main():
    svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <title>Poma: a manually started interval</title>
  <path d="M735.435 641 A258 258 0 1 1 735.435 383" fill="none" stroke="#6854C8" stroke-width="72" stroke-linecap="round"/>
  <path d="M512 354 V512 H646" fill="none" stroke="#6854C8" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="770" cy="512" r="44" fill="#147D80"/>
</svg>
'''
    write(ROOT / "branding/poma-mark.svg", svg)
    mark(1024, PAPER).convert("RGB").save(ROOT / "branding/poma-icon-1024.png", optimize=True)
    for density, size in (("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)):
        path = ANDROID / f"mipmap-{density}/ic_launcher.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        mark(size, PAPER).convert("RGB").save(path, optimize=True)
    vector = '''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">
    <path android:pathData="M735.435,641 A258,258 0,1 1,735.435 383" android:strokeColor="#6854C8" android:strokeWidth="72" android:strokeLineCap="round" android:fillColor="#00000000"/>
    <path android:pathData="M512,354 V512 H646" android:strokeColor="#6854C8" android:strokeWidth="64" android:strokeLineCap="round" android:strokeLineJoin="round" android:fillColor="#00000000"/>
    <path android:pathData="M814,512 A44,44 0,1 0,726 512 A44,44 0,1 0,814 512" android:fillColor="#147D80"/>
</vector>
'''
    write(ANDROID / "drawable/ic_launcher_foreground.xml", vector)
    write(ANDROID / "drawable/ic_launcher_monochrome.xml", vector.replace("#6854C8", "#FFFFFFFF").replace("#147D80", "#FFFFFFFF"))
    write(ANDROID / "values/branding.xml", '<resources><color name="poma_icon_background">#F8F9FD</color></resources>\n')
    adaptive = '''<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/poma_icon_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    {monochrome}
</adaptive-icon>
'''
    write(ANDROID / "mipmap-anydpi-v26/ic_launcher.xml", adaptive.format(monochrome=""))
    write(ANDROID / "mipmap-anydpi-v33/ic_launcher.xml", adaptive.format(monochrome='<monochrome android:drawable="@drawable/ic_launcher_monochrome"/>'))
    for folder, background in (("values-v31", PAPER), ("values-night-v31", "#1C2332")):
        write(ANDROID / folder / "styles.xml", f'''<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.NoTitleBar">
        <item name="android:windowSplashScreenBackground">{background}</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground</item>
        <item name="android:windowBackground">{background}</item>
    </style>
</resources>
''')
    splash = ANDROID / "drawable-nodpi/poma_splash.png"
    splash.parent.mkdir(parents=True, exist_ok=True)
    mark(192).save(splash, optimize=True)
    launch = '''<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground"/>
    <item><bitmap android:gravity="center" android:src="@drawable/poma_splash"/></item>
</layer-list>
'''
    for folder in ("drawable", "drawable-v21"):
        write(ANDROID / folder / "launch_background.xml", launch)
    catalog = IOS / "AppIcon.appiconset/Contents.json"
    for item in json.loads(catalog.read_text())["images"]:
        size = round(float(item["size"].split("x")[0]) * float(item["scale"].rstrip("x")))
        mark(size, PAPER).convert("RGB").save(catalog.parent / item["filename"], optimize=True)
    for suffix, size in (("",96),("@2x",192),("@3x",288)):
        mark(size).save(IOS / f"LaunchImage.imageset/LaunchImage{suffix}.png", optimize=True)
    write(IOS / "LaunchBackground.colorset/Contents.json", json.dumps({"colors":[
        {"idiom":"universal","color":{"color-space":"srgb","components":{"red":"0.973","green":"0.976","blue":"0.992","alpha":"1.000"}}},
        {"idiom":"universal","appearances":[{"appearance":"luminosity","value":"dark"}],"color":{"color-space":"srgb","components":{"red":"0.110","green":"0.137","blue":"0.196","alpha":"1.000"}}}
    ],"info":{"author":"xcode","version":1}}, indent=2)+"\n")
    story = ROOT / "mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard"
    text = story.read_text()
    text = text.replace('<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>', '<color key="backgroundColor" name="LaunchBackground"/>')
    text = text.replace('<image name="LaunchImage" width="168" height="185"/>', '<image name="LaunchImage" width="96" height="96"/>\n        <namedColor name="LaunchBackground"><color red="0.973" green="0.976" blue="0.992" alpha="1" colorSpace="custom" customColorSpace="sRGB"/></namedColor>')
    write(story, text)
    print("Original Poma icon and native static splash assets generated")


if __name__ == "__main__":
    main()
