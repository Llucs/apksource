#!/bin/bash
# ApkSource 1.2
# Author: Llucs

set -euo pipefail

APK=$1
SKIP_BACKUP=${2:-false}
PROJECT_NAME=${3:-""}

MIN_APKTOOL_VERSION="2.7.0"
MIN_JADX_VERSION="1.4.7"
GRADLE_VERSION="8.7"

# ---------------------------
# SMART PROJECT NAME
# ---------------------------
if [ -z "$PROJECT_NAME" ]; then
    # Extract APK name, remove .apk, replace spaces with _, remove invalid chars
    PROJECT_NAME=$(basename "$APK" .apk | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_]//g')
fi

# ---------------------------
# ENHANCED DEPENDENCIES (25+)
# ---------------------------
BASIC_DEPS="implementation 'androidx.appcompat:appcompat:1.7.0'
implementation 'androidx.core:core-ktx:1.13.1'"

CORE_LIBS=(
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
    # Dependency Injection
    "com.google.dagger:dagger:2.52"
    "androidx.hilt:hilt-navigation-fragment:1.2.0"
    # RxJava + Coroutines
    "io.reactivex.rxjava3:rxjava:3.1.9"
    "io.reactivex.rxjava3:rxandroid:3.0.2"
    "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1"
    # Networking + JSON
    "com.squareup.moshi:moshi:1.15.1"
    "com.squareup.retrofit2:converter-moshi:2.11.0"
    # Image/Video
    "com.github.chrisbanes:PhotoView:2.3.0"
    # Charts + Maps
    "com.github.PhilJay:MPAndroidChart:v3.1.0"
    "com.google.android.gms:play-services-maps:18.2.0"
    # Testing + Utils
    "junit:junit:4.13.2"
    "androidx.test.ext:junit:1.2.1"
    "org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1"
    # Architecture
    "androidx.hilt:hilt-compiler:1.2.0"
    "androidx.room:room-compiler:2.6.0"
)

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

# Multi-module detection
detect_modules() {
    local jadx_dir=$1
    local modules=()
    
    # Detect common module patterns
    local module_patterns=(
        "dagger*" "di*" "injection*"
        "network*" "api*" "retrofit*"
        "data*" "repository*"
        "domain*" "usecase*"
        "ui*" "view*" "fragment*" "activity*"
    )
    
    for pattern in "${module_patterns[@]}"; do
        if find "$jadx_dir" -type d -name "$pattern" | grep -q .; then
            modules+=("$pattern")
        fi
    done
    
    # If no modules detected, return single module
    [ ${#modules[@]} -eq 0 ] && echo "app" || printf '%s\n' "${modules[@]}"
}

smart_package_detection() {
    local jadx_dir=$1
    # Priority 1: Manifest
    local pkg=$(grep -oP 'package="[^"]+"' temp_apktool/AndroidManifest.xml | cut -d'"' -f2 | head -1)
    [ -n "$pkg" ] && { echo "$pkg"; return; }
    
    # Priority 2: Folder with MOST Java/Kotlin files
    local best_pkg="" max_files=0
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        local count=$(find "$dir" -name "*.java" -o -name "*.kt" 2>/dev/null | wc -l)
        if [ "$count" -gt "$max_files" ]; then
            max_files=$count
            best_pkg=$(basename "$dir")
        fi
    done < <(find "$jadx_dir" -type d -mindepth 1 -maxdepth 1 2>/dev/null)
    
    # Priority 3: First package statement
    [ -z "$best_pkg" ] && best_pkg=$(find "$jadx_dir" -name '*.java' -exec grep -m1 -oP '^package\s+[\w.]+' {} \; | head -n1 | cut -d' ' -f2 | cut -d';' -f1)
    
    echo "${best_pkg:-unknown.pkg1}"
}

merge_multi_apk() {
    local base_apk=$1
    local merged_apk="temp_merged.apk"
    
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
progress_bar 1 12

check_cmd apktool "$MIN_APKTOOL_VERSION"
check_cmd jadx "$MIN_JADX_VERSION"
check_cmd python3 ""
check_cmd gradle ""

if [ -z "${JAVA_HOME:-}" ]; then
    echo "Error: JAVA_HOME not set."
    exit 1
fi

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
    echo "Error: provide a valid APK. Usage: $0 file.apk [skip-backup] [project-name]"
    exit 1
fi

# Multi-APK Detection & Merge
progress_bar 2 12
merge_multi_apk "$APK"

# Validate APK
file "$APK" | grep -q "Zip archive" || { echo "Error: Invalid APK file"; exit 1; }

# ---------------------------
# Backup if project exists
# ---------------------------
progress_bar 3 12
if [ -d "$PROJECT_NAME" ] && [ "$SKIP_BACKUP" != "true" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP="$PROJECT_NAME-backup-$TIMESTAMP"
    echo "Backing up existing project: $BACKUP"
    mv "$PROJECT_NAME" "$BACKUP"
elif [ "$SKIP_BACKUP" = "true" ]; then
    echo "Backup disabled."
fi

# ---------------------------
# Create project structure (MULTI-MODULE)
# ---------------------------
rm -rf "$PROJECT_NAME"
MODULES=($(detect_modules "temp_jadx"))
echo "[3.5] Modules detected: ${MODULES[*]}"

for module in "${MODULES[@]}"; do
    mkdir -p "$PROJECT_NAME/$module/src/main/java" "$PROJECT_NAME/$module/src/main/res"
done

# ---------------------------
# Decompile APK (PARALLEL)
# ---------------------------
progress_bar 4 12
echo
(
    echo "[4/12] Decompiling resources..."
    apktool d "$APK" -o temp_apktool -f
) &
APKTOOL_PID=$!

(
    echo "[5/12] Decompiling code..."
    jadx -d temp_jadx "$APK"
) &
JADX_PID=$!
wait $APKTOOL_PID $JADX_PID

# ---------------------------
# ProGuard mapping
# ---------------------------
progress_bar 6 12
if unzip -l "$APK" | grep -q "mapping.txt"; then
    echo "[6/12] ProGuard mapping detected"
    mkdir -p temp_mapping
    unzip -p "$APK" "mapping.txt" > temp_mapping/mapping.txt
fi

# ---------------------------
# Copy resources to MAIN module
# ---------------------------
cp -r temp_apktool/res/* "$PROJECT_NAME/app/src/main/res/" 2>/dev/null || true
cp temp_apktool/AndroidManifest.xml "$PROJECT_NAME/app/src/main/AndroidManifest.xml"

# Detect SDKs
MIN_SDK_VERSION=$(grep -oP 'android:minSdkVersion="\K\d+' "$PROJECT_NAME/app/src/main/AndroidManifest.xml" || echo "21")
TARGET_SDK_VERSION=$(grep -oP 'android:targetSdkVersion="\K\d+' "$PROJECT_NAME/app/src/main/AndroidManifest.xml" || echo "33")
COMPILE_SDK_VERSION=${TARGET_SDK_VERSION:-33}

MAIN_PACKAGE=$(smart_package_detection "temp_jadx")
echo "[7/12] Package: $MAIN_PACKAGE"

# ---------------------------
# ENHANCED ProGuard + Code organization
# ---------------------------
progress_bar 7 12
python3 <<PYTHON
import os, re, sys
from pathlib import Path

SRC_DIR = "temp_jadx"
DST_BASE = "$PROJECT_NAME"
MAP_FILE = "temp_mapping/mapping.txt"
MAIN_MODULE = "app"
MODULES = [$(for m in "${MODULES[@]}"; do echo "    '$m',"; done)]

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
                
                # Apply ProGuard mapping
                for obf, orig in mapping.items():
                    content, subs = pattern_cache[obf].subn(orig, content)
                    count_subs += subs
                
                # Detect module from package path
                m_pkg = re.search(r"^package\s+([\w.]+);", content, re.MULTILINE)
                pkg = m_pkg.group(1) if m_pkg else "unknown.pkg1"
                
                # Route to correct module
                module = MAIN_MODULE
                for mod in MODULES:
                    if any(part in pkg for part in mod.split("*")):
                        module = mod
                        break
                
                # Create destination
                pkg_parts = pkg.split(".")
                dest_dir = Path(DST_BASE) / module / "src/main/java" / *pkg_parts
                dest_dir.mkdir(parents=True, exist_ok=True)
                
                (dest_dir / file).write_text(content, encoding="utf-8")
                count_files += 1
            except Exception as e:
                print(f"Warning: Error processing {path}: {e}", file=sys.stderr)

print(f"[8/12] Files: {count_files} | Subs: {count_subs}")
PYTHON

count_files=$(python3 -c "
import re
with open('temp_count.py', 'w') as f:
    f.write('''$(cat <<'EOF'
import os
count = 0
for root, dirs, files in os.walk('$PROJECT_NAME'):
    for file in files:
        if file.endswith(('.java', '.kt')):
            count += 1
print(count)
EOF
)''')
os.system('python3 temp_count.py')
")

# Fix imports
progress_bar 8 12
find "$PROJECT_NAME" -name "*.java" -o -name "*.kt" | while read FILE; do
    sed -i.bak "s/import android.R;/import $MAIN_PACKAGE.R;/" "$FILE" 2>/dev/null || true
    rm -f "${FILE}.bak"
done

# ---------------------------
# ENHANCED Dependency Detection
# ---------------------------
progress_bar 9 12
DEPENDENCIES="$BASIC_DEPS"

for lib in "${CORE_LIBS[@]}"; do
    lib_name=$(echo "$lib" | cut -d: -f2)
    if grep -r --include='*.{java,kt}' "$lib_name" "$PROJECT_NAME" >/dev/null 2>/dev/null; then
        DEPENDENCIES+="
    $lib"
        echo "Detected: $lib_name"
    fi
done

# Kotlin support
KOTLIN_PLUGIN=""
if find "$PROJECT_NAME" -name "*.kt" | grep -q .; then
    KOTLIN_PLUGIN="apply plugin: 'kotlin-android'
apply plugin: 'kotlin-parcelize'
apply plugin: 'dagger.hilt.android.plugin'
    "
    DEPENDENCIES+="
    implementation 'org.jetbrains.kotlin:kotlin-stdlib:2.0.21'
    kapt 'com.google.dagger:hilt-android-compiler:2.52'"
fi

# ---------------------------
# GENERATE MULTI-MODULE GRADLE
# ---------------------------
progress_bar 10 12

# Root build.gradle
cat <<EOL > "$PROJECT_NAME/build.gradle"
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath "com.android.tools.build:gradle:$GRADLE_VERSION"
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21"
        classpath "com.google.dagger:hilt-android-gradle-plugin:2.52"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOL

# Settings.gradle
cat <<EOL > "$PROJECT_NAME/settings.gradle"
include ':app'
EOL
for module in "${MODULES[@]:1}"; do
    echo "include ':$module'" >> "$PROJECT_NAME/settings.gradle"
done

# App build.gradle (WITH SIGNING)
cat <<EOL > "$PROJECT_NAME/app/build.gradle"
$KOTLIN_PLUGIN
apply plugin: 'com.android.application'
apply plugin: 'kotlin-kapt'
apply plugin: 'dagger.hilt.android.plugin'

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
    
    # SIGNING CONFIGS
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
        release {
            storeFile file('release.keystore')
            storePassword System.getenv("KEYSTORE_PASSWORD") ?: "changeit"
            keyAlias 'key0'
            keyPassword System.getenv("KEY_PASSWORD") ?: "changeit"
        }
    }
    
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            minifyEnabled false
            signingConfig signingConfigs.release
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
$DEPENDENCIES
}
EOL

# Generate other modules
for module in "${MODULES[@]:1}"; do
    cat <<EOL > "$PROJECT_NAME/$module/build.gradle"
apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    compileSdk $COMPILE_SDK_VERSION
    
    defaultConfig {
        minSdkVersion $MIN_SDK_VERSION
        targetSdkVersion $TARGET_SDK_VERSION
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}

dependencies {
    implementation project(':app')
    implementation 'androidx.core:core-ktx:1.13.1'
}
EOL
done

# ---------------------------
# Generate Wrapper + Keystore
# ---------------------------
progress_bar 11 12
cd "$PROJECT_NAME"
gradle wrapper --gradle-version "$GRADLE_VERSION" >/dev/null 2>&1
chmod +x gradlew

# Generate debug keystore
keytool -genkey -v -keystore app/debug.keystore -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" \
    -storepass android -keypass android -batch >/dev/null 2>&1 || true

cd - >/dev/null

# ---------------------------
# FINALIZATION
# ---------------------------
progress_bar 12 12
echo
echo "[12/12] ApkSource 1.2 COMPLETED"
echo "Project: $PROJECT_NAME (${#MODULES[@]} modules)"
echo "Files processed: $count_files"
echo "Dependencies: $(echo "$DEPENDENCIES" | grep -c "implementation")"
echo "Run: cd $PROJECT_NAME && ./gradlew build"
echo "Open in Android Studio - READY TO BUILD"
echo
echo "Repository: https://github.com/Llucs/apksource"