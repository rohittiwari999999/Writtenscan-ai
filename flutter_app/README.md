# WriteScan AI — Mobile Flutter Android App

WriteScan AI is a production-ready Android mobile application built with Flutter that converts handwritten notes, cursive script, whiteboard captures, and scanned documents into editable digital text using Google Gemini Vision 3.8 Flash OCR.

---

## 1. Features
- **High-Accuracy Handwriting OCR**: Real document intelligence for cursive English and Indian languages (Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi, Urdu).
- **Camera Document Scanner**: Real-time camera viewfinder with flash control, document grid guidelines, and auto-capture framing.
- **Image Processing & Enhancement**: Crop, rotate (90° steps), deskew, brightness/contrast correction, binarization/document enhancement filter.
- **Rich Document Editor**:
  - Full inline editing.
  - Undo & Redo stack.
  - Find & Replace with match navigation.
  - Word & character counter.
  - Confidence rating badge (HIGH, MEDIUM, LOW).
- **Multi-Format Export**: Export to TXT, styled PDF, Markdown, and direct Android system sharing.
- **Local SQLite History**: Search documents by title or text body, rename, duplicate, and delete with confirmation.

---

## 2. Directory Structure
```
flutter_app/
├── android/                   # Native Android configuration
│   ├── app/
│   │   ├── build.gradle       # MinSdk 23, TargetSdk 34, ProGuard
│   │   └── src/main/AndroidManifest.xml # Camera, storage & uCrop permissions
├── lib/
│   ├── app.dart               # GoRouter navigation & Riverpod root
│   ├── main.dart              # Entry point
│   ├── core/
│   │   ├── theme/             # Material 3 light/dark palette
│   │   ├── constants/         # Supported languages & scripts
│   │   └── errors/            # Typed failures
│   └── features/
│       ├── ocr/               # OCR domain interface & Gemini Cloud service
│       ├── scanner/           # Camera viewfinder
│       ├── image_editor/      # Crop & filter pipeline
│       ├── document_editor/   # Editable results, find/replace, undo/redo
│       ├── history/           # SQLite repository & search
│       └── settings/          # Provider status & retention preferences
└── pubspec.yaml               # Compatible dependencies
```

---

## 3. Local Setup Instructions

### Prerequisites
- Flutter SDK `^3.19.0` or higher
- Android Studio / Android SDK (API Level 34)
- Java 17 (JDK 17)

### Installation
1. Clone the repository and navigate to the flutter app:
   ```bash
   cd flutter_app
   flutter pub get
   ```

2. Configure `.env`:
   ```bash
   cp .env.example .env
   ```
   Add your OCR backend URL:
   ```env
   OCR_BACKEND_URL=http://10.0.2.2:3000   # For Android Emulator pointing to local host
   # Or your deployed Cloud Run URL:
   # OCR_BACKEND_URL=https://your-applet-url.run.app
   ```

3. Run on connected Android device or emulator:
   ```bash
   flutter run
   ```

---

## 4. Building Release APK & Android App Bundle (AAB)

### Build Debug APK:
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Release APK:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Build Android App Bundle (for Google Play Store):
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 5. Automated GitHub Actions Signed APK & AAB CI/CD

An automated pipeline is configured in `.github/workflows/build_signed_apk.yml` to compile and sign your Android APKs and AAB bundles on every push or manual trigger.

### GitHub Repository Secrets Setup:
Navigate to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**:

| Secret Name | Value Description |
|---|---|
| `KEYSTORE_BASE64` | Base64-encoded string of your `upload-keystore.jks` file |
| `KEYSTORE_PASSWORD` | Password for your Android keystore |
| `KEY_ALIAS` | Alias name for the signing key (e.g. `upload`) |
| `KEY_PASSWORD` | Password for the key alias |
| `OCR_BACKEND_URL` | Your live backend OCR URL (e.g. `https://your-applet.run.app`) |

> **Automated Fallback**: If `KEYSTORE_BASE64` is not yet configured, the CI workflow generates a valid self-signed release key automatically so your initial build finishes successfully!

### Quick Keystore Generator Script:
To generate your release keystore and get the base64 string in 1 command:
```bash
cd flutter_app
chmod +x scripts/generate_keystore.sh
./scripts/generate_keystore.sh
```

### Generated GitHub Artifacts:
On completion, download the signed binaries under the **Actions** tab -> **Artifacts**:
- `WriteScanAI-universal-release.apk` (Installs on any Android device)
- `WriteScanAI-arm64-v8a-release.apk` (Optimized small APK for modern 64-bit phones)
- `WriteScanAI-armeabi-v7a-release.apk` (For older 32-bit Android phones)
- `WriteScanAI-playstore-release.aab` (Ready for Google Play Store Console)

---

## 6. Security & Privacy Architecture
- **No API Secrets on Device**: The Flutter client never contains `GEMINI_API_KEY` or cloud credentials. All recognition requests are proxied through your secure backend service (`/api/ocr/recognize`).
- **Zero Cloud Retention**: Images are processed in memory and discarded immediately after transcription. No user documents or photos are kept on server storage.
- **Offline First**: All saved documents, extracted text, and thumbnails are stored securely in local device storage (SQLite/SharedPreferences).
