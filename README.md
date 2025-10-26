ApkSource

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.x-blue.svg)](https://www.python.org/)
[![Gradle](https://img.shields.io/badge/Gradle-8.7-green.svg)](https://gradle.org/)
[![Bash](https://img.shields.io/badge/Bash-Script-yellow.svg)](https://www.gnu.org/software/bash/)
[![GitHub Stars](https://img.shields.io/github/stars/Llucs/ApkSource.svg?style=social)](https://github.com/Llucs/ApkSource/stargazers)    

ApkSource converts any Android APK into a complete, multi-module Gradle project, ready for Android Studio. It decompiles resources and code, applies safe ProGuard mapping, detects modules and dependencies, and configures Gradle automatically — without compiling the APK.


---

Disclaimer

Use at your own risk. The author is not responsible for data loss, corrupted devices, or other damages. Always back up files, verify compatibility, and obtain proper authorization when analyzing third-party APKs.


---

### Prerequisites

| **Tool / Requirement** | **Minimum Version** | **Notes** |
|------------------------|---------------------|-----------|
| Java JDK              | 17+                 | JAVA_HOME must be set, includes keytool |
| Gradle                | 8.7+                | Required for project build and wrapper |
| apktool               | 2.7.0+              | Used for resource decompilation |
| jadx                  | 1.4.7+              | Used for code decompilation (Java/Kotlin) |
| Python                | 3.x                 | For ProGuard mapping and automation |
| Core utilities        | -                   | grep, sed, unzip, zip, file |
| Android SDK           | Optional            | Required for full builds |



---

Installation

`git clone https://github.com/Llucs/ApkSource.git
cd ApkSource
chmod +x ApkSource.sh`

Install dependencies:

On Ubuntu/Debian

`pkg install apktool python openjdk-17 unzip zip findutils coreutils grep sed file`

On Fedora

`sudo dnf install apktool python3 java-17-openjdk unzip zip findutils coreutils grep sed file`

On Arch Linux

`sudo pacman -S python jdk17-openjdk unzip zip findutils coreutils grep sed file
yay -S apktool`

On Alpine Linux

`sudo apk add apktool python3 openjdk17 unzip zip findutils coreutils grep sed file`

---

Usage

Command	Description

`./ApkSource.sh /path/to/app.apk`	Basic usage, generates project in current directory
`./ApkSource.sh app.apk true`	Skips backup if project exists
`./ApkSource.sh app.apk false MyProject`	Sets custom project name


After execution:

`cd MyProject
./gradlew build`

Open in Android Studio to explore and modify the project.


---

Features

Decompile APK: Resources via apktool, code via jadx (Java/Kotlin)

Multi-module support: Detects modules (ui, network, data, repository)

ProGuard mapping: Restores original names if mapping.txt exists

Dependency detection: Adds libraries automatically to Gradle

Gradle setup: Root + module build scripts ready

Debug keystore generated: For test builds

Multi-APK support: Automatically merges split APKs



---

Auto-detected Dependencies

Category	Libraries / Plugins

AndroidX	appcompat, core-ktx, constraintlayout, room-runtime, lifecycle-viewmodel-ktx, navigation-fragment-ktx
Networking / JSON	Retrofit, OkHttp, Moshi, Gson
DI / Architecture	Dagger, Hilt
Reactive / Coroutines	RxJava, RxAndroid, kotlinx-coroutines-android
Image / Media	Glide, PhotoView
Charts / Maps	MPAndroidChart, play-services-maps
Testing / Utils	JUnit, kotlinx-coroutines-test, androidx.test.ext:junit


> Kotlin plugin is applied automatically if Kotlin files are detected.




---

Project Structure

MyProject/
├─ app/                  # Main module
│  ├─ src/main/java/     # Decompiled Java/Kotlin code
│  ├─ src/main/res/      # Resources
│  └─ build.gradle       # App module build script
├─ <other_modules>/      # Detected modules (auto)
│  └─ src/main/java/
├─ build.gradle           # Root Gradle configuration
├─ settings.gradle        # Includes all modules
├─ gradlew                # Gradle wrapper
└─ app/debug.keystore     # Debug keystore


---

Advanced Usage & Tips

Merge multi-APK splits: The script automatically merges configuration APKs.

Custom keystore: Replace app/debug.keystore for production signing.

Selective module builds: Use Gradle tasks like ./gradlew :moduleName:build.

ProGuard mapping: Place mapping.txt in the APK root to restore original names.

Debugging build issues: Use ./gradlew assembleDebug --stacktrace for detailed logs.



---

License

MIT License © Llucs
[LICENSE](https://github.com/Llucs/apksource/blob/main/LICENSE)