# ApkSource

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)  
[![Python](https://img.shields.io/badge/Python-3.x-blue.svg)](https://www.python.org/)  
[![Gradle](https://img.shields.io/badge/Gradle-8.7-green.svg)](https://gradle.org/)  

**ApkSource** is a professional tool that generates a complete Gradle project from an APK. It decompiles resources and code (Java/Kotlin), applies safe Proguard mapping, and sets up a modern Android Studio project — **without compiling the APK automatically**.  

---

## Disclaimer

I am not responsible for bricked devices, corrupted SD cards, data loss, job loss due to app failure, or any damages caused by using this project. Use at your own risk. Make backups, verify compatibility, and research features before use. This software is provided "as-is," without warranties. If you use any part of this project on third-party systems without authorization, the legal responsibility is yours.  

---

## Prerequisites

- Java JDK (JAVA_HOME set)  
- Android SDK (ANDROID_HOME or ANDROID_SDK_ROOT set)  
- Gradle 8.7+  
- apktool 2.7.0+  
- jadx 1.4.7+  
- Python 3  
- grep and sed  

---

## Installation

Clone the repository:  

```bash
git clone https://github.com/yourusername/ApkSource.git
cd ApkSource
chmod +x ApkSource.sh```


---

Usage

./ApkSource.sh path/to/your.apk [skip-backup]

path/to/your.apk → APK to decompile

[skip-backup] → Optional; set true to skip backup if PatchedApp exists


After running, a Gradle project will be generated in the PatchedApp folder, ready to open in Android Studio or build with:

./gradlew build


---

Features

Decompile APK resources and manifest with apktool

Decompile Java/Kotlin code with jadx

Apply safe Proguard mapping

Detect and configure dependencies automatically

Prepare a ready-to-build Gradle project

Detailed logging for easy debugging



---

License

MIT License — see LICENSE file.