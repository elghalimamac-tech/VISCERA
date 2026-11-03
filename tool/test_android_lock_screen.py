#!/usr/bin/env python3
"""Vérifier qu'aucun dossier patient ne reste visible sur l'écran verrouillé."""
from pathlib import Path
import xml.etree.ElementTree as ET

manifest = Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    raise SystemExit("Manifeste Android absent : générer et configurer l'APK d'abord")

root = ET.parse(manifest).getroot()
namespace = "{http://schemas.android.com/apk/res/android}"
application = root.find("application")
if application is None:
    raise SystemExit("Application Android introuvable")

def find_activity(suffix):
    for item in application.findall("activity"):
        if (item.get(namespace + "name") or "").endswith(suffix):
            return item
    raise AssertionError(f"Activité Android absente : {suffix}")

main = find_activity("MainActivity")
assert main.get(namespace + "showWhenLocked") != "true", (
    "RISQUE CONFIDENTIALITÉ : MainActivity visible sur téléphone verrouillé"
)
assert main.get(namespace + "turnScreenOn") != "true", (
    "RISQUE CONFIDENTIALITÉ : MainActivity réveille l'écran verrouillé"
)

alarm = find_activity("DutyAlarmActivity")
assert alarm.get(namespace + "showWhenLocked") == "true", (
    "L'écran d'alarme de garde doit pouvoir sonner sur l'écran verrouillé"
)
assert alarm.get(namespace + "turnScreenOn") == "true", (
    "Une véritable alarme doit pouvoir réveiller l'écran"
)
print("OK : dossier patient protégé sur écran verrouillé ; alarme isolée.")
