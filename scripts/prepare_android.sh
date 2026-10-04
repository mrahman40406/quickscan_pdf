#!/usr/bin/env bash
set -e

echo "==> Re-creating clean Android platform files..."
rm -rf android
flutter create . --platforms=android --org=com.quickscan

echo "==> Configuring Android Manifest and Gradle..."
python3 - << 'EOF'
import os

# 1. Update AndroidManifest.xml
manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    permissions = """    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
"""
    if "android.permission.CAMERA" not in content and "<application" in content:
        content = content.replace("<application", permissions + "    <application", 1)

    if "xmlns:tools" not in content:
        content = content.replace("<manifest", '<manifest xmlns:tools="http://schemas.android.com/tools"')

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Permissions and tools namespace injected into AndroidManifest.xml")

# 2. Update android/app/build.gradle
gradle_path = "android/app/build.gradle"
if os.path.exists(gradle_path):
    with open(gradle_path, "r", encoding="utf-8") as f:
        g = f.read()

    # Ensure minSdkVersion is at least 21
    g = g.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 21")
    g = g.replace("minSdk = flutter.minSdkVersion", "minSdk = 21")
    g = g.replace("minSdk flutter.minSdkVersion", "minSdk 21")

    # Ensure compileSdkVersion is 34
    g = g.replace("compileSdkVersion flutter.compileSdkVersion", "compileSdkVersion 34")
    g = g.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 34")
    g = g.replace("compileSdk flutter.compileSdkVersion", "compileSdk 34")

    # Enable multidex
    if "multiDexEnabled" not in g:
        g = g.replace("defaultConfig {", "defaultConfig {\n        multiDexEnabled true")

    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(g)
    print("Updated build.gradle with minSdk 21, compileSdk 34, and multiDexEnabled true")
EOF

echo "==> Android platform preparation complete."
