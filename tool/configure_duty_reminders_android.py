#!/usr/bin/env python3
"""Configure les alarmes natives VISCERA après flutter create --platforms=android."""
from pathlib import Path
import xml.etree.ElementTree as ET
import shutil
import wave
import math
import struct

app = Path("android/app")
gradle = app / "build.gradle.kts"
if not gradle.exists():
    raise SystemExit("Flutter Android build.gradle.kts manquant")
src = gradle.read_text()
if "isCoreLibraryDesugaringEnabled = true" not in src:
    src = src.replace("compileOptions {",
                      "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
if "coreLibraryDesugaring(" not in src:
    src += ('\n\ndependencies {\n'
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            '}\n')
gradle.write_text(src, encoding="utf-8")

# flutter create génère un MainActivity élémentaire.
# On conserve le package officiel com.viscera.viscera dans une seule source.
target = app / "src/main/kotlin/com/viscera/viscera"
target.mkdir(parents=True, exist_ok=True)
source = Path("tool/android_alarm_src")
for file in ("MainActivity.kt", "VisceraDutyAlarms.kt"):
    shutil.copy2(source / file, target / file)

# Sonnerie originale, synthétisée localement : 4,8 s de notes répétées en
# boucle par MediaPlayer (AudioAttributes.USAGE_ALARM, sans toucher au volume).
# 22,05 kHz mono réduit la taille APK. Forme douce + trois salves distinctes.
raw = app / "src/main/res/raw"
raw.mkdir(parents=True, exist_ok=True)
wav = raw / "viscera_duty_alarm.wav"
rate = 22050
seconds = 4.8
with wave.open(str(wav), "wb") as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(rate)
    frames = bytearray()
    for i in range(round(rate * seconds)):
        t = i / rate
        phase = t % 1.6
        active = (0.0 <= phase < 0.45) or (0.61 <= phase < 1.06)
        if active:
            within = phase if phase < 0.45 else phase - 0.61
            envelope = min(1.0, within * 25, (0.45 - within) * 18)
            freq = 775 if phase < 0.45 else 980
            sample = math.sin(2 * math.pi * freq * t) * 0.72
            sample += math.sin(2 * math.pi * (freq / 2) * t) * 0.12
            val = int(32767 * sample * max(0.0, envelope))
        else:
            val = 0
        frames.extend(struct.pack("<h", max(-32768, min(32767, val))))
    out.writeframes(frames)

manifest = app / "src/main/AndroidManifest.xml"
ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
ET.register_namespace("tools", "http://schemas.android.com/tools")
tree = ET.parse(manifest)
root = tree.getroot()
ns = "{http://schemas.android.com/apk/res/android}"
permissions = [
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.USE_FULL_SCREEN_INTENT",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
    "android.permission.WAKE_LOCK",
    "android.permission.VIBRATE",
]
for permission in permissions:
    if not any(x.tag == "uses-permission" and x.get(ns + "name") == permission
               for x in root):
        root.insert(0, ET.Element("uses-permission", {ns + "name": permission}))

application = root.find("application")
if application is None:
    raise SystemExit("Balise Android application manquante")
activity = next((x for x in application.findall("activity")
                 if x.get(ns + "name", "").endswith("MainActivity")), None)
if activity is not None:
    activity.set(ns + "showWhenLocked", "true")
    activity.set(ns + "turnScreenOn", "true")

def component(tag, name, **attrs):
    for existing in application.findall(tag):
        if existing.get(ns + "name") == name:
            return existing
    return ET.SubElement(application, tag,
                         {ns + "name": name, **{ns+k: v for k, v in attrs.items()}})

for receiver in [
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
]:
    node = component("receiver", receiver, exported="false")
    if receiver.endswith("BootReceiver") and not node.findall("intent-filter"):
        intent = ET.SubElement(node, "intent-filter")
        for action in ["android.intent.action.BOOT_COMPLETED",
                       "android.intent.action.MY_PACKAGE_REPLACED",
                       "android.intent.action.QUICKBOOT_POWERON"]:
            ET.SubElement(intent, "action", {ns + "name": action})

native = component("receiver", ".DutyAlarmReceiver", exported="false")
if not native.findall("intent-filter"):
    filter_tag = ET.SubElement(native, "intent-filter")
    for action in ["android.intent.action.BOOT_COMPLETED",
                   "android.intent.action.MY_PACKAGE_REPLACED",
                   "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"]:
        ET.SubElement(filter_tag, "action", {ns + "name": action})
component("activity", ".DutyAlarmActivity", exported="false",
          showWhenLocked="true", turnScreenOn="true",
          excludeFromRecents="true", theme="@android:style/Theme.Material.Light.NoActionBar")
component("service", ".DutyAlarmService", exported="false",
          foregroundServiceType="mediaPlayback")

tree.write(manifest, encoding="utf-8", xml_declaration=True)
print("Alarmes VISCERA configurées : sonnerie native prolongée, plein écran, reboot.")
