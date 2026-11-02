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
SYMBOL = (BRAND / "viscera-symbol-light.svg").read_text(encoding="utf-8")
INNER = SYMBOL.split(">", 1)[1].rsplit("</svg>", 1)[0]


def svg_scene(background: bool = True, maskable: bool = False, monochrome: bool = False):
    # Coordonnées des quatre tracés du logo maître (viewBox 855 x 710).
    scale = 0.75 if maskable else 1.0
    x = 512 - (427 * scale)
    y = 512 - (353.5 * scale)
    paths = INNER.replace(TURQUOISE, "#FFFFFF") if monochrome else INNER
    backdrop = '<rect width="1024" height="1024" fill="' + DARK + '"/>' if background else ""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        + backdrop + '<g transform="translate(' + str(x) + ' ' + str(y) +
        ') scale(' + str(scale) + ')">' + paths + '</g></svg>'
    )


def png(target: Path, size: int, *, background: bool = True,
        maskable: bool = False, monochrome: bool = False):
    target.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(
        bytestring=svg_scene(background, maskable, monochrome).encode("utf-8"),
        write_to=str(target), output_width=size, output_height=size
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
        '<background android:drawable="@color/viscera_primary"/>'
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
    png(site / "favicon.png", 64)
    png(site / "apple-touch-icon.png", 180)
    png(site / "icons" / "Icon-192.png", 192)
    png(site / "icons" / "Icon-512.png", 512)
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
