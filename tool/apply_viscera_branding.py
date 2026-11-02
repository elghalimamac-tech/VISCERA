#!/usr/bin/env python3
"""Génère toutes les icônes VISCERA depuis le même symbole SVG.
À lancer après 'flutter create --platforms=android,ios,web ...'.
Dépendances d'outillage: pip install cairosvg pillow.
Les écrans Flutter utilisent les SVG sources versionnées dans assets/branding/.
"""
from __future__ import annotations
import json
import plistlib
import re
from pathlib import Path
from xml.etree import ElementTree as ET

import cairosvg

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "branding"
DARK = "#083B46"
TURQUOISE = "#13B8B0"
# Une source SVG haute fidélité, issue des nouvelles illustrations VISCERA.
# La même source est utilisée par Flutter Web, Android et iOS.
SOURCE_SYMBOL = (BRAND / "viscera-symbol.svg").read_text(encoding="utf-8")
SOURCE_LIGHT = (BRAND / "viscera-symbol-light.svg").read_text(encoding="utf-8")
SOURCE_ICON = (BRAND / "viscera-app-icon.svg").read_text(encoding="utf-8")
SYMBOL_VIEWBOX = "220 287 810 677"


def nested_symbol(source, x, y, width, height, monochrome=False):
    inner = source.split(">", 1)[1].rsplit("</svg>", 1)[0]
    if monochrome:
        # Icônes monochromes Android : uniquement des silhouettes blanches.
        inner = re.sub(r'fill="url\([^)]+\)"', 'fill="#FFFFFF"', inner)
    return ('<svg x="' + str(x) + '" y="' + str(y) + '" width="' +
            str(width) + '" height="' + str(height) +
            '" viewBox="' + SYMBOL_VIEWBOX + '">' + inner + '</svg>')


def svg_scene(background=True, maskable=False, monochrome=False):
    if background:
        if not maskable:
            return SOURCE_ICON
        # Les icônes PWA maskable conservent le motif dans la zone sûre.
        return SOURCE_ICON.replace(
            'x="185" y="205" width="654" height="585"',
            'x="249" y="240" width="526" height="492"',
        )
    # Android adaptive foreground 432x432 : symbole dans la safe zone
    # centrée (~60 %), distincte du fond. Les autres scènes sont libres.
    x, y, w, h = (90, 111, 252, 210) if maskable else (53, 75, 326, 282)
    source = SOURCE_LIGHT if monochrome else SOURCE_SYMBOL
    mark = nested_symbol(source, x, y, w, h, monochrome=monochrome)
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 432 432">' + mark + '</svg>'


def png(target: Path, size: int, *, background: bool = True,
        maskable: bool = False, monochrome: bool = False):
    target.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        bytestring=svg_scene(background, maskable, monochrome).encode("utf-8"),
        write_to=str(target), output_width=size, output_height=size
    )


def adaptive_background_svg():
    # Même icône à vagues, mais sans le monogramme, pour la couche Android.
    return re.sub(
        r'<svg x="185" y="205" width="654" height="585".*?</svg>',
        '',
        SOURCE_ICON,
        count=1,
        flags=re.S,
    )


def android():
    app = ROOT / "android" / "app" / "src" / "main"
    if not app.exists():
        return
    res = app / "res"
    for folder, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                         ("xxhdpi", 144), ("xxxhdpi", 192)]:
        for filename in ("ic_launcher.png", "ic_launcher_round.png"):
            png(res / ("mipmap-" + folder) / filename, size)
    # Le premier plan est transparent; Android applique son propre masque.
    png(res / "drawable-nodpi" / "viscera_foreground.png", 432,
        background=False, maskable=True)
    background_png = res / "drawable-nodpi" / "viscera_adaptive_background.png"
    background_png.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=adaptive_background_svg().encode("utf-8"),
                     write_to=str(background_png), output_width=432, output_height=432)
    png(res / "drawable-nodpi" / "viscera_monochrome.png", 432,
        background=False, maskable=True, monochrome=True)
    png(res / "drawable-nodpi" / "viscera_notification.png", 96,
        background=False, maskable=True, monochrome=True)
    png(res / "drawable-nodpi" / "viscera_splash.png", 256, background=False)
    colors = res / "values" / "viscera_colors.xml"
    colors.parent.mkdir(parents=True, exist_ok=True)
    colors.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources><color name="viscera_primary">' + DARK +
        '</color></resources>\n', encoding="utf-8"
    )
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
        '<background android:drawable="@drawable/viscera_adaptive_background"/>'
        '<foreground android:drawable="@drawable/viscera_foreground"/>'
        '<monochrome android:drawable="@drawable/viscera_monochrome"/>'
        '</adaptive-icon>\n'
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        path = res / "mipmap-anydpi-v26" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(adaptive, encoding="utf-8")
    for splash in (res / "drawable" / "launch_background.xml",
                   res / "drawable-v21" / "launch_background.xml"):
        splash.parent.mkdir(parents=True, exist_ok=True)
        splash.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">'
        '<item android:drawable="@color/viscera_primary"/>'
        '<item><bitmap android:gravity="center" android:src="@drawable/viscera_splash"/>'
        '</item></layer-list>\n', encoding="utf-8"
    )
    manifest = app / "AndroidManifest.xml"
    if manifest.exists():
        ns = "http://schemas.android.com/apk/res/android"
        ET.register_namespace("android", ns)
        doc = ET.parse(manifest)
        app_node = doc.getroot().find("application")
        if app_node is not None:
            app_node.set("{" + ns + "}label", "VISCERA")
            app_node.set("{" + ns + "}icon", "@mipmap/ic_launcher")
            app_node.set("{" + ns + "}roundIcon", "@mipmap/ic_launcher_round")
        if app_node is not None:
            name = "{" + ns + "}name"
            resource = "{" + ns + "}resource"
            existing = any(n.get(name) == "com.google.firebase.messaging.default_notification_icon"
                           for n in app_node.findall("meta-data"))
            if not existing:
                ET.SubElement(app_node, "meta-data", {
                    name: "com.google.firebase.messaging.default_notification_icon",
                    resource: "@drawable/viscera_notification",
                })
        doc.write(manifest, encoding="utf-8", xml_declaration=True)


def ios():
    app = ROOT / "ios" / "Runner"
    if not app.exists():
        return
    icons = app / "Assets.xcassets" / "AppIcon.appiconset"
    sizes = [(20, 1), (20, 2), (20, 3), (29, 1), (29, 2),
             (29, 3), (40, 1), (40, 2), (40, 3), (60, 2), (60, 3),
             (76, 1), (76, 2), (83.5, 2), (1024, 1)]
    for points, mult in sizes:
        point_text = str(points).replace(".0", "")
        filename = "Icon-App-" + point_text + "x" + point_text + "@" + str(mult) + "x.png"
        png(icons / filename, int(points * mult))
    info = app / "Info.plist"
    if info.exists():
        with info.open("rb") as fh:
            data = plistlib.load(fh)
        data["CFBundleDisplayName"] = "VISCERA"
        data["CFBundleName"] = "VISCERA"
        with info.open("wb") as fh:
            plistlib.dump(data, fh, sort_keys=False)


def web():
    site = ROOT / "web"
    if not site.exists():
        return
    png(site / "favicon.png", 128)
    png(site / "apple-touch-icon.png", 180)
    png(site / "icons" / "Icon-192.png", 192)
    png(site / "icons" / "Icon-512.png", 512)
    png(site / "icons" / "Icon-1024.png", 1024)
    png(site / "icons" / "Icon-maskable-192.png", 192, maskable=True)
    png(site / "icons" / "Icon-maskable-512.png", 512, maskable=True)
    manifest = site / "manifest.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
    else:
        data = {}
    data.update({
        "name": "VISCERA — Chirurgie viscérale",
        "short_name": "VISCERA",
        "description": "Gestion du service de chirurgie viscérale",
        "display": "standalone",
        "theme_color": DARK,
        "background_color": DARK,
        "icons": [
            {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "icons/Icon-maskable-192.png", "sizes": "192x192",
             "type": "image/png", "purpose": "maskable"},
            {"src": "icons/Icon-maskable-512.png", "sizes": "512x512",
             "type": "image/png", "purpose": "maskable"}
        ]
    })
    manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                        encoding="utf-8")
    index = site / "index.html"
    if index.exists():
        html = index.read_text(encoding="utf-8")
        html = re.sub(r"<title>.*?</title>", "<title>VISCERA — Chirurgie viscérale</title>",
                      html, count=1, flags=re.S)
        html = re.sub(r'(<meta name="theme-color" content=")[^"]+(")',
                      lambda m: m.group(1) + DARK + m.group(2), html)
        if 'rel="apple-touch-icon"' not in html:
            html = html.replace("</head>",
                '  <link rel="apple-touch-icon" href="apple-touch-icon.png">\n</head>')
        index.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    android()
    ios()
    web()
    print("Identité VISCERA: icônes Android/iOS et favicon/PWA Web générés.")
