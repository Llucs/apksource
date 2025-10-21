# ApkSource

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.x-blue.svg)](https://www.python.org/)
[![Gradle](https://img.shields.io/badge/Gradle-8.7-green.svg)](https://gradle.org/)
[![Bash](https://img.shields.io/badge/Bash-Script-yellow.svg)](https://www.gnu.org/software/bash/)
[![GitHub Stars](https://img.shields.io/github/stars/Llucs/ApkSource.svg?style=social)](https://github.com/Llucs/ApkSource/stargazers)

**ApkSource** is a professional tool that generates a complete Gradle project from an APK. It decompiles resources and code (Java/Kotlin), applies safe Proguard mapping, and sets up a modern Android Studio project — **without compiling the APK automatically**.

---

## Disclaimer

This software is provided "as-is" without warranties. I am not responsible for bricked devices, corrupted SD cards, data loss, or any damages caused by using this project. Use at your own risk. Make backups, verify compatibility, and research features before use. If you use this project on third-party systems without authorization, the legal responsibility is yours.

---

## Prerequisites

- **Java JDK 17+** (JAVA_HOME set, includes keytool)
- **Android SDK** (ANDROID_HOME or ANDROID_SDK_ROOT set – optional for generation, required for full builds)
- **Gradle 8.7+**
- **apktool 2.7.0+**
- **jadx 1.4.7+**
- **Python 3**
- **grep** and **sed**
- **unzip** and **zip**
- **file** (from coreutils)

---

## Installation

Clone the repository and set up the script:

```bash
git clone https://github.com/yourusername/ApkSource.git
cd ApkSource
chmod +x ApkSource.sh