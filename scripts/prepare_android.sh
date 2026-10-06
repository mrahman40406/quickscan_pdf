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
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

    <queries>
        <intent>
            <action android:name="android.media.action.IMAGE_CAPTURE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.GET_CONTENT" />
        </intent>
        <intent>
            <action android:name="android.intent.action.PICK" />
        </intent>
    </queries>
"""
    if "android.permission.CAMERA" not in content and "<application" in content:
        content = content.replace("<application", permissions + "    <application", 1)

    if "xmlns:tools" not in content:
        content = content.replace("<manifest", '<manifest xmlns:tools="http://schemas.android.com/tools"')

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Permissions and tools namespace injected into AndroidManifest.xml")

# 2. Update android/app/build.gradle or build.gradle.kts
import glob

for gradle_path in glob.glob("android/app/build.gradle*"):
    with open(gradle_path, "r", encoding="utf-8") as f:
        g = f.read()

    # Ensure minSdkVersion is at least 24 (required by cunning_document_scanner)
    g = g.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 24")
    g = g.replace("minSdk = flutter.minSdkVersion", "minSdk = 24")
    g = g.replace("minSdk flutter.minSdkVersion", "minSdk 24")

    # Ensure compileSdkVersion is 36 (required by shared_preferences_android)
    g = g.replace("compileSdkVersion flutter.compileSdkVersion", "compileSdkVersion 36")
    g = g.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")
    g = g.replace("compileSdk flutter.compileSdkVersion", "compileSdk 36")

    # Ensure targetSdkVersion is 36
    g = g.replace("targetSdkVersion flutter.targetSdkVersion", "targetSdkVersion 36")
    g = g.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 36")
    g = g.replace("targetSdk flutter.targetSdkVersion", "targetSdk 36")

    # Enable multidex with correct syntax for Groovy vs Kotlin DSL
    if "multiDexEnabled" not in g:
        if "defaultConfig {" in g:
            multidex_line = "        multiDexEnabled = true" if gradle_path.endswith(".kts") else "        multiDexEnabled true"
            g = g.replace("defaultConfig {", f"defaultConfig {{\n{multidex_line}")

    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(g)
    print(f"Updated {gradle_path} with minSdk 24, compileSdk 36, and multiDex")
EOF

echo "==> Android platform preparation complete."
