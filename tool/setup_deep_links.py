#!/usr/bin/env python3
"""Configurer les deep links Supabase pour Android et iOS après flutter create."""
import plistlib
from pathlib import Path
from xml.etree import ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
android = Path("android/app/src/main/AndroidManifest.xml")
if android.exists():
    ET.register_namespace("android", ANDROID_NS)
    tree = ET.parse(android)
    root = tree.getroot()
    activity = root.find(".//activity")
    if activity is None:
        raise RuntimeError("Activité Android introuvable")
    exists = any(
        d.get(f"{{{ANDROID_NS}}}scheme") == "viscera"
        and d.get(f"{{{ANDROID_NS}}}host") == "auth-callback"
        for filt in activity.findall("intent-filter")
        for d in filt.findall("data")
    )
    if not exists:
        filt = ET.SubElement(activity, "intent-filter")
        ET.SubElement(filt, "action", {f"{{{ANDROID_NS}}}name": "android.intent.action.VIEW"})
        ET.SubElement(filt, "category", {f"{{{ANDROID_NS}}}name": "android.intent.category.DEFAULT"})
        ET.SubElement(filt, "category", {f"{{{ANDROID_NS}}}name": "android.intent.category.BROWSABLE"})
        ET.SubElement(filt, "data", {f"{{{ANDROID_NS}}}scheme": "viscera", f"{{{ANDROID_NS}}}host": "auth-callback"})
    root.insert(0, ET.Element("uses-permission", {f"{{{ANDROID_NS}}}name": "android.permission.POST_NOTIFICATIONS"}))
    tree.write(android, encoding="utf-8", xml_declaration=True)

info = Path("ios/Runner/Info.plist")
if info.exists():
    with info.open("rb") as fh:
        data = plistlib.load(fh)
    entries = data.setdefault("CFBundleURLTypes", [])
    if not any("viscera" in e.get("CFBundleURLSchemes", []) for e in entries):
        entries.append({"CFBundleURLSchemes": ["viscera"]})
    with info.open("wb") as fh:
        plistlib.dump(data, fh, sort_keys=False)
