#!/usr/bin/env bash
set -e

echo "==> Re-creating clean Android platform files..."
rm -rf android
flutter create . --platforms=android --org=com.quickscan

echo "==> Injecting camera and storage permissions..."
python3 - << 'EOF'
import os

path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    permissions = """    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
"""
    if "<application" in content and "android.permission.CAMERA" not in content:
        content = content.replace("<application", permissions + "    <application", 1)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print("Permissions successfully injected into AndroidManifest.xml")
EOF

echo "==> Android platform preparation complete."
