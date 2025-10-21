#!/bin/bash
# ApkSource 1.1
# Generates a complete Gradle project from APKs with advanced support, detailed logs, safe ProGuard patch, and Kotlin
# Author: Llucs

set -euo pipefail

APK=$1
PROJECT_NAME="PatchedApp"
SKIP_BACKUP=${2:-false}

MIN_APKTOOL_VERSION="2.7.0"
MIN_JADX_VERSION="1.4.7"
GRADLE_VERSION="8.7"

# ---------------------------
# Helper functions
# ---------------------------
check_cmd() {
    local cmd=$1 min_version=$2
    command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "Error: $cmd not installed."; exit 1; }
    if [ -n "$min_version" ]; then
        local version=$($cmd --version 2>&1 | head -n1 | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
        if [ "$(printf '%s\n%s' "$version" "$min_version" | sort -V | head -n1)" != "$min_version" ]; then
            echo >&2 "Error: $cmd version $version is too old. Requires $min_version."
            exit 1
        fi
    fi
}

progress_bar() {
    local current=$1 total=$2
    local percent=$((current * 100 / total))
    local bar=$(printf '█%.0s' $(seq 1 $((percent/2))))
    local spaces=$(printf ' %.0s' $(seq 1 $((50-percent/2))))
    printf "\r[%-50s] %d%% (%d/%d)" "$bar$spaces" "$percent" "$current" "$total"
}

smart_package_detection() {
    local jadx_dir=$1
    # Prioridade 1: Manifest
    local pkg=$(grep -oP 'package="[^"]+"' temp_apktool/AndroidManifest.xml | cut -d'"' -f2 | head -1)
    [ -n "$pkg" ] && { echo "$pkg"; return; }
    
    # Prioridade 2: Pasta com MAIS arquivos Java/Kotlin
    local best_pkg="" max_files=0
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        local count=$(find "$dir" -name "*.java" -o -name "*.kt" 2>/dev/null | wc -l)
        if [ "$count" -gt "$max_files" ]; then
            max_files=$count
            best_pkg=$(basename "$dir")
        fi
    done < <(find "$jadx_dir" -type d -mindepth 1 -maxdepth 1 2>/dev/null)
    
    # Prioridade 3: Primeiro package statement
    [ -z "$best_pkg" ] && best_pkg=$(find "$jadx_dir" -name '*.java' -exec grep -m1 -oP '^package\s+[\w.]+' {} \; | head -n1 | cut -d' ' -f2 | cut -d';' -f1)
    
    echo "${best_pkg:-unknown.pkg1}"
}

merge_multi_apk() {
    local base_apk=$1
    local merged_apk="temp_merged.apk"
    
    # Detecta APKs split (base.apk + config.*.apk)
    local split_apks=()
    for apk in *.apk; do
        if [[ "$apk" =~ config\..*\.apk$ ]]; then
            split_apks+=("$apk")
        fi
    done
    
    if [ ${#split_apks[@]} -eq 0 ]; then
        cp "$base_apk" "$merged_apk"
        return 0
    fi
    
    echo "[0.5] Merging ${#split_apks[@]} split APKs..."
    cp "$base_apk" "$merged_apk"
    
    for split in "${split_apks[@]}"; do
        unzip -o "$split" -d temp_split >/dev/null
        cd temp_split
        zip -r "../$merged_apk" . -u >/dev/null
        cd ..
        rm -rf temp_split
    done
    
    mv "$merged_apk" "$base_apk"
    echo "[0.5] Multi-APK merged successfully"
}

# ---------------------------
# AUTO-CLEANUP
# ---------------------------
cleanup() {
    rm -rf temp_apktool temp_jadx temp_mapping temp_split temp_merged.apk
}
trap cleanup EXIT

# ---------------------------
# Environment checks
# ---------------------------
progress_bar 1 10

check_cmd apktool "$MIN_APKTOOL_VERSION"
check_cmd jadx "$MIN_JADX_VERSION"
check_cmd python3 ""
check_cmd grep ""
check_cmd sed ""
check_cmd gradle ""

if [ -z "${JAVA_HOME:-}" ]; then
    echo "Error: JAVA_HOME not set."
    exit 1
fi
if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    echo "Warning: ANDROID_HOME or ANDROID_SDK_ROOT not set. Configure for future builds."
fi

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
    echo "Error: provide a valid APK. Usage: $0 file.apk [skip-backup]"
    exit 1
fi

# Multi-APK Detection & Merge
progress_bar 2 10
merge_multi_apk "$APK"

# Validate APK
file "$APK" | grep -q "Zip archive" || { echo "Error: Invalid APK file"; exit 1; }

# ---------------------------
# Backup if project exists
# ---------------------------
progress_bar 3 10
if [ -d "$PROJECT_NAME" ] && [ "$SKIP_BACKUP" != "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP="$PROJECT_NAME-backup-$TIMESTAMP"
    echo "Backing up existing project: $BACKUP"
    mv "$PROJECT_NAME" "$BACKUP" || { echo "Error creating backup."; exit 1; }
elif [ "$SKIP_BACKUP" = "true" ]; then
    echo "Backup disabled."
fi

# ---------------------------
# Create temporary folders
# ---------------------------
rm -rf "$PROJECT_NAME"
mkdir -p "$PROJECT_NAME/app/src/main/java" "$PROJECT_NAME/app/src/main/res"

# ---------------------------
# Decompile APK
# ---------------------------
progress_bar 4 10
echo
(
    echo "[4/10] Decompiling resources and manifest with apktool..."
    apktool d "$APK" -o temp_apktool -f || {
        echo "Error: apktool failed. Check APK integrity or update apktool."
        exit 1
    }
) &
APKTOOL_PID=$!

(
    echo "[5/10] Decompiling Java/Kotlin code with jadx..."
    jadx -d temp_jadx "$APK" || {
        echo "Error: jadx failed. Check APK or update jadx."
        exit 1
    }
) &
JADX_PID=$!
wait $APKTOOL_PID $JADX_PID

# ---------------------------
# Detect ProGuard mapping
# ---------------------------
progress_bar 6 10
if unzip -l "$APK" | grep -q "mapping.txt"; then
    echo "[6/10] ProGuard mapping detected"
    unzip -p "$APK" "mapping.txt" > temp_mapping/mapping.txt || { echo "Error extracting mapping"; exit 1; }
    if ! grep -q "->" temp_mapping/mapping.txt; then
        echo "Warning: mapping.txt invalid, ignoring."
        rm temp_mapping/mapping.txt
    fi
else
    echo "[6/10] No mapping detected"
fi

# ---------------------------
# Copy resources and manifest
# ---------------------------
cp -r temp_apktool/res/* "$PROJECT_NAME/app/src/main/res/" 2>/dev/null || echo "Warning: resource copy"
cp temp_apktool/AndroidManifest.xml "$PROJECT_NAME/app/src/main/AndroidManifest.xml" || { echo "Error copying manifest"; exit 1; }

# Detect SDKs and package
MIN_SDK_VERSION=$(grep -oP 'android:minSdkVersion="\K\d+' "$PROJECT_NAME/app/src/main/AndroidManifest.xml" || echo "21")
TARGET_SDK_VERSION=$(grep -oP 'android:targetSdkVersion="\K\d+' "$PROJECT_NAME/app/src/main/AndroidManifest.xml" || echo "33")
COMPILE_SDK_VERSION=${TARGET_SDK_VERSION:-33}

MAIN_PACKAGE=$(smart_package_detection "temp_jadx")
echo "[7/10] Package detected: $MAIN_PACKAGE"

# ---------------------------
# Safe ProGuard patch + organize code
# ---------------------------
progress_bar 7 10
python3 <<PYTHON
import os, re, sys
from pathlib import Path

SRC_DIR = "temp_jadx"
DST_DIR = "$PROJECT_NAME/app/src/main/java"
MAP_FILE = "temp_mapping/mapping.txt"

mapping = {}
if os.path.exists(MAP_FILE):
    with open(MAP_FILE, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            m = re.match(r"(\S+)\s+->\s+(\S+):", line)
            if m: mapping[m.group(2)] = m.group(1)

pattern_cache = {obf: re.compile(r'\b' + re.escape(obf) + r'\b') for obf in mapping}

count_files = 0
count_subs = 0

for root, dirs, files in os.walk(SRC_DIR):
    for file in files:
        if file.endswith(('.java', '.kt')):
            path = Path(root) / file
            try:
                content = path.read_text(encoding="utf-8", errors="ignore")
                for obf, orig in mapping.items():
                    content, subs = pattern_cache[obf].subn(orig, content)
                    count_subs += subs
                m_pkg = re.search(r"^package\s+([\w.]+);", content, re.MULTILINE)
                pkg = m_pkg.group(1) if m_pkg else "unknown.pkg1"
                dest_dir = Path(DST_DIR) / *pkg.split(".")
                dest_dir.mkdir(parents=True, exist_ok=True)
                (dest_dir / file).write_text(content, encoding="utf-8")
                count_files += 1
            except Exception as e:
                print(f"Warning: Error processing {path}: {e}", file=sys.stderr)

print(f"[8/10] Files processed: {count_files}")
print(f"[8.1] Name substitutions applied: {count_subs}")
PYTHON

# ---------------------------
# Fix android.R imports
# ---------------------------
progress_bar 8 10
find "$PROJECT_NAME/app/src/main/java" -name "*.java" -o -name "*.kt" | while read JAVA_FILE; do
    sed -i.bak "s/import android.R;/import $MAIN_PACKAGE.R;/" "$JAVA_FILE" 2>/dev/null || true
    rm -f "${JAVA_FILE}.bak"
done

# ---------------------------
# Detect external libraries
# ---------------------------
DEPENDENCIES="implementation 'androidx.appcompat:appcompat:1.7.0'
implementation 'androidx.core:core-ktx:1.13.1'"

libs=(
    "androidx.constraintlayout:constraintlayout:2.2.0"
    "com.google.android.gms:play-services-base:18.5.0"
    "com.squareup.retrofit2:retrofit:2.11.0"
    "com.google.code.gson:gson:2.10.1"
    "com.squareup.okhttp3:okhttp:5.0.0-alpha.11"
    "com.google.firebase:firebase-bom:34.0.0"
    "com.github.bumptech.glide:glide:4.16.0"
    "androidx.room:room-runtime:2.6.0"
    "androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.6"
    "androidx.navigation:navigation-fragment-ktx:2.8.3"
)

for lib in "${libs[@]}"; do
    lib_name=$(echo "$lib" | cut -d: -f2)
    if grep -r --include='*.*' "$lib_name" "$PROJECT_NAME/app/src/main/java" >/dev/null 2>/dev/null; then
        DEPENDENCIES+="
implementation '$lib'"
    fi
done

# Kotlin plugin if .kt files exist
KOTLIN_PLUGIN=""
if find "$PROJECT_NAME/app/src/main/java" -name "*.kt" | grep -q .; then
    KOTLIN_PLUGIN="apply plugin: 'kotlin-android'
apply plugin: 'kotlin-parcelize'
"
    DEPENDENCIES+="
implementation 'org.jetbrains.kotlin:kotlin-stdlib:2.0.21'"
fi

# ---------------------------
# Generate modern Gradle files
# ---------------------------
progress_bar 9 10
cat <<EOL > "$PROJECT_NAME/app/build.gradle"
$KOTLIN_PLUGIN
apply plugin: 'com.android.application'

android {
    namespace '$MAIN_PACKAGE'
    compileSdk $COMPILE_SDK_VERSION
    
    defaultConfig {
        applicationId '$MAIN_PACKAGE'
        minSdkVersion $MIN_SDK_VERSION
        targetSdkVersion $TARGET_SDK_VERSION
        versionCode 1
        versionName "1.0"
    }
    
    buildTypes {
        release {
            minifyEnabled false
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
$DEPENDENCIES
}
EOL

cat <<EOL > "$PROJECT_NAME/build.gradle"
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath "com.android.tools.build:gradle:$GRADLE_VERSION"
$KOTLIN_PLUGIN
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOL

echo "include ':app'" > "$PROJECT_NAME/settings.gradle"

# ---------------------------
# Generate Gradle Wrapper
# ---------------------------
progress_bar 10 10
cd "$PROJECT_NAME"
gradle wrapper --gradle-version "$GRADLE_VERSION" --distribution-type all >/dev/null 2>&1 || echo "Warning: failed to generate wrapper"
chmod +x gradlew
cd - > /dev/null

# ---------------------------
# Finalization
# ---------------------------
echo
echo "[10/10] ApkSource 1.1 project ready in '$PROJECT_NAME'."
echo "The project is ready to open in Android Studio or run ./gradlew build"