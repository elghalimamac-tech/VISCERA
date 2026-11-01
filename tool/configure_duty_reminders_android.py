#!/usr/bin/env python3
"""Préparer Android pour les rappels locaux 24H VISCERA après flutter create."""
from pathlib import Path
import xml.etree.ElementTree as ET

app = Path("android/app")
gradle = app / "build.gradle.kts"
if not gradle.exists():
    raise SystemExit("Flutter Android build.gradle.kts manquant")
src = gradle.read_text()
if "isCoreLibraryDesugaringEnabled = true" not in src:
    src = src.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
if "coreLibraryDesugaring(" not in src:
    src += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
gradle.write_text(src)

manifest = app / "src/main/AndroidManifest.xml"
ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
ET.register_namespace("tools", "http://schemas.android.com/tools")
tree = ET.parse(manifest)
root = tree.getroot()
android = "{http://schemas.android.com/apk/res/android}"
for permission in ["android.permission.RECEIVE_BOOT_COMPLETED",
                   "android.permission.POST_NOTIFICATIONS",
                   "android.permission.SCHEDULE_EXACT_ALARM"]:
    if not any(x.tag == "uses-permission" and x.get(android + "name") == permission for x in root):
        ET.Element("unused")
        root.insert(0, ET.Element("uses-permission", {android + "name": permission}))
application = root.find("application")
if application is None:
    raise SystemExit("Balise Android application manquante")
receivers = [
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
]
for receiver in receivers:
    if any(x.get(android + "name") == receiver for x in application.findall("receiver")):
        continue
    node=ET.SubElement(application,"receiver",{android+"name":receiver,android+"exported":"false"})
    if receiver.endswith("BootReceiver"):
        intent=ET.SubElement(node,"intent-filter")
        for action in ["android.intent.action.BOOT_COMPLETED",
                       "android.intent.action.MY_PACKAGE_REPLACED",
                       "android.intent.action.QUICKBOOT_POWERON"]:
            ET.SubElement(intent,"action",{android+"name":action})
tree.write(manifest,encoding="utf-8",xml_declaration=True)
print("Rappels de garde Android configurés.")
