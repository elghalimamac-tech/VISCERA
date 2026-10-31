#!/usr/bin/env python3
"""Prepare the generated Flutter Android project for VISCERA Firebase Messaging."""
import json
import re
import shutil
from pathlib import Path

PACKAGE = "com.viscera.app"
config = Path("firebase/google-services.json")
app = Path("android/app/build.gradle.kts")
settings = Path("android/settings.gradle.kts")
destination = Path("android/app/google-services.json")

if not all(path.is_file() for path in (config, app, settings)):
    raise SystemExit("Missing Firebase config or generated Android Gradle files")

data = json.loads(config.read_text(encoding="utf-8"))
packages = {
    entry["client_info"]["android_client_info"]["package_name"]
    for entry in data["client"]
}
if PACKAGE not in packages:
    raise SystemExit("Firebase package does not match VISCERA Android applicationId")

app_text = app.read_text(encoding="utf-8")
app_text, count = re.subn(
    r'(?m)^([ \t]*applicationId[ \t]*=[ \t]*)"[^"]+"',
    lambda match: match.group(1) + '"' + PACKAGE + '"',
    app_text,
    count=1,
)
if count != 1:
    raise SystemExit("Expected an applicationId in android/app/build.gradle.kts")

if 'id("com.google.gms.google-services")' not in app_text:
    app_text, count = re.subn(
        r'(?m)^([ \t]*)id\("dev\.flutter\.flutter-gradle-plugin"\)[ \t]*$',
        lambda match: match.group(0) + '\n' + match.group(1) + 'id("com.google.gms.google-services")',
        app_text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Flutter Gradle plugin anchor not found in app build file")
app.write_text(app_text, encoding="utf-8")

settings_text = settings.read_text(encoding="utf-8")
if 'id("com.google.gms.google-services")' not in settings_text:
    settings_text, count = re.subn(
        r'(?m)^plugins[ \t]*\{[ \t]*$',
        lambda match: match.group(0) + '\n    id("com.google.gms.google-services") version "4.4.4" apply false',
        settings_text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Root plugins block not found in android/settings.gradle.kts")
settings.write_text(settings_text, encoding="utf-8")
shutil.copyfile(config, destination)
print("Configured Firebase Google Services for", PACKAGE)
