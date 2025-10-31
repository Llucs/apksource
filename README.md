# ApkSource

![Apksource Banner](https://github.com/Llucs/apksource/blob/main/banner.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://www.python.org/downloads/)
[![CLI](https://img.shields.io/badge/CLI-Professional-brightgreen.svg)]()

**ApkSource** is a command-line tool that automatically decompiles Android APK files and reconstructs them into a fully structured **Gradle project** — ready to be opened in **Android Studio**.

---

## 🚀 Features

- 🔍 **Smart dependency check**  
  Ensures that all required tools (`java`, `apktool`, `jadx`) are installed and meet the minimum versions.

- 🧠 **Automatic project setup**  
  Creates a full Gradle-based Android Studio project structure from a single APK.

- 📦 **Dependency detection**  
  Scans the decompiled source code and automatically injects the necessary dependencies (e.g. Retrofit, Room, Hilt, Glide, etc.) into `build.gradle`.

- 🧾 **ProGuard mapping support**  
  Optionally applies `mapping.txt` to de-obfuscate class names.

- ⚙️ **Fully CLI-based**  
  Fast, simple, and ideal for developers who prefer the terminal.

---

## 📦 Installation

You can install ApkSource directly from **PyPI**:

```bash
pip install apksource

Or, if you have the source code:

```
git clone https://github.com/Llucs/apksource.git
cd apksource
pip install .
```

---

🧰 Requirements

Make sure the following dependencies are installed and available in your PATH:

Tool	Minimum Version	Description

Java (JDK)	17+	Required for apktool and jadx
apktool	2.7.0+	Used to decompile APK resources
jadx	1.4.7+	Used to decompile DEX (Java/Kotlin code)



---

⚙️ Usage

Once installed, you can use the apksource command globally:

🧩 Basic usage

apksource decompile myapp.apk

This will:

1. Check all dependencies (java, apktool, jadx)


2. Decompile the APK into source code and resources


3. Create a Gradle-ready project directory



🏗️ Optional flags

Option	Description

--project-name NAME	Custom name for the generated project folder
--skip-backup	Skip backup if a folder with the same name already exists


Example:

apksource decompile myapp.apk --project-name MyAppSource --skip-backup


---

🗂️ Output Structure

After running successfully, you’ll get a directory like this:

MyAppSource/
├── app/
│   ├── build.gradle
│   ├── src/
│   │   └── main/
│   │       ├── java/
│   │       └── res/
│   └── debug.keystore
├── build.gradle
├── settings.gradle
└── gradlew

This project can be opened directly in Android Studio for analysis, modification, or rebuilding.


---

⚠️ Notes for Termux Users

ApkSource can run on Termux with some setup:

pkg install python openjdk-17 wget git
pip install apksource

However, apktool and jadx must be manually installed and configured in your Termux environment.
Make sure to test Java execution with:

java -version
apktool --version
jadx --version


---

🧑‍💻 Author

Llucs
📧 c307lucas@gmail.com
🌍 GitHub: [Llucs](https://github.com/Llucs/)


---

📜 License

This project is licensed under the MIT License – see the [LICENSE](https://github.com/Llucs/apksource/blob/main/LICENSE) file for details.


---

⭐ Support

If you find this project helpful, please give it a ⭐ on GitHub and share it with other Android developers!