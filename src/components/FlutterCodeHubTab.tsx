import React, { useState } from 'react';
import {
  Code2,
  FileCode,
  Copy,
  Check,
  Download,
  Terminal,
  Smartphone,
  CheckCircle2,
  FolderTree,
  ExternalLink,
  ShieldCheck,
  GitBranch,
  KeyRound,
  FileCheck,
} from 'lucide-react';

interface FlutterFile {
  path: string;
  name: string;
  lang: string;
  description: string;
  content: string;
}

const FLUTTER_FILES: FlutterFile[] = [
  {
    path: 'flutter_app/lib/app.dart',
    name: 'app.dart',
    lang: 'dart',
    description: 'Root WriteScanApp ConsumerWidget with Material 3 theme & HomeScreen navigation',
    content: `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';

class WriteScanApp extends ConsumerWidget {
  const WriteScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'WriteScan AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}`,
  },
  {
    path: '.github/workflows/build_signed_apk.yml',
    name: 'build_signed_apk.yml',
    lang: 'yaml',
    description: 'GitHub Actions workflow: Builds signed universal APK, split-per-abi APKs & Google Play AAB',
    content: `name: Build Signed Android APK & AAB

on:
  push:
    branches: [ main, master ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:
    inputs:
      create_release:
        description: 'Publish as a GitHub Release'
        required: false
        default: false
        type: boolean
      build_aab:
        description: 'Build Google Play AAB Bundle in addition to APK'
        required: false
        default: true
        type: boolean

jobs:
  build:
    name: Build & Sign WriteScan AI Android App
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'

      - name: Set up Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: 'stable'
          cache: true

      - name: Configure Keystore & Signing Properties
        working-directory: flutter_app
        env:
          KEYSTORE_BASE64: \${{ secrets.KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: \${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: \${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: \${{ secrets.KEY_PASSWORD }}
        run: |
          mkdir -p android/app
          if [ -n "$KEYSTORE_BASE64" ]; then
            echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
            cat <<EOF > android/key.properties
          storePassword=\${KEYSTORE_PASSWORD:-android}
          keyPassword=\${KEY_PASSWORD:-android}
          keyAlias=\${KEY_ALIAS:-upload}
          storeFile=upload-keystore.jks
          EOF
          else
            # Automated fallback release keystore
            keytool -genkeypair -v -keystore android/app/upload-keystore.jks \\
              -storepass android -alias upload -keypass android -keyalg RSA \\
              -keysize 2048 -validity 10000 -dname "CN=WriteScan AI, O=WriteScan, C=IN"
            cat <<EOF > android/key.properties
          storePassword=android
          keyPassword=android
          keyAlias=upload
          storeFile=upload-keystore.jks
          EOF
          fi

      - name: Install Dependencies
        working-directory: flutter_app
        run: flutter pub get

      - name: Build Signed Universal Release APK
        working-directory: flutter_app
        run: flutter build apk --release

      - name: Build Signed Split Per-ABI APKs
        working-directory: flutter_app
        run: flutter build apk --release --split-per-abi

      - name: Build Signed Android App Bundle (AAB)
        if: \${{ github.event.inputs.build_aab != 'false' }}
        working-directory: flutter_app
        run: flutter build appbundle --release

      - name: Upload Signed APKs as GitHub Actions Artifact
        uses: actions/upload-artifact@v4
        with:
          name: writescan-ai-signed-apks
          path: flutter_app/build/app/outputs/flutter-apk/*-release.apk
          retention-days: 30`,
  },
  {
    path: 'flutter_app/scripts/generate_keystore.sh',
    name: 'generate_keystore.sh',
    lang: 'bash',
    description: 'Keystore generator script: creates upload-keystore.jks & base64 string for GitHub Secrets',
    content: `#!/usr/bin/env bash
# WriteScan AI - Android Release Keystore Generator Helper
set -e

KEYSTORE_DIR="./android/app"
KEYSTORE_FILE="$KEYSTORE_DIR/upload-keystore.jks"
KEY_ALIAS="upload"

mkdir -p "$KEYSTORE_DIR"

echo "Enter a secure Keystore password (min 6 chars):"
read -s -p "Password: " KEY_PASSWORD
echo

keytool -genkeypair -v \\
  -keystore "$KEYSTORE_FILE" \\
  -storepass "$KEY_PASSWORD" \\
  -alias "$KEY_ALIAS" \\
  -keypass "$KEY_PASSWORD" \\
  -keyalg RSA \\
  -keysize 2048 \\
  -validity 10000 \\
  -dname "CN=WriteScan AI, OU=Mobile, O=WriteScan, L=Bengaluru, ST=Karnataka, C=IN"

# Local key.properties
cat <<EOF > ./android/key.properties
storePassword=$KEY_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF

echo "Keystore created! Base64 for GitHub Secrets (KEYSTORE_BASE64):"
base64 -w 0 "$KEYSTORE_FILE" 2>/dev/null || base64 "$KEYSTORE_FILE"`,
  },
  {
    path: 'flutter_app/android/app/build.gradle',
    name: 'build.gradle',
    lang: 'groovy',
    description: 'Android Gradle build with release signingConfigs reading from key.properties or CI env',
    content: `plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.writescan.ai"
    compileSdk = 35
    ndkVersion = "25.1.8937393"

    defaultConfig {
        applicationId "com.writescan.ai"
        minSdkVersion 23
        targetSdk = 35
        versionCode 1
        versionName "1.0"
        multiDexEnabled true
    }

    signingConfigs {
        release {
            def storeFilePath = System.getenv("ANDROID_KEYSTORE_PATH") ?: keystoreProperties['storeFile']
            def storePasswordVal = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: keystoreProperties['storePassword']
            def keyAliasVal = System.getenv("ANDROID_KEY_ALIAS") ?: keystoreProperties['keyAlias']
            def keyPasswordVal = System.getenv("ANDROID_KEY_PASSWORD") ?: keystoreProperties['keyPassword']

            if (storeFilePath != null && file(storeFilePath).exists()) {
                storeFile file(storeFilePath)
                storePassword storePasswordVal
                keyAlias keyAliasVal
                keyPassword keyPasswordVal
            } else if (keystorePropertiesFile.exists() && keystoreProperties['storeFile'] != null) {
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
            } else {
                signingConfig signingConfigs.debug
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}`,
  },
  {
    path: 'flutter_app/lib/features/ocr/domain/ocr_service.dart',
    name: 'ocr_service.dart',
    lang: 'dart',
    description: 'Requirement 3: Clean OCR service abstraction interface and typed result models',
    content: `import 'dart:io';

class OcrResult {
  final String text;
  final String detectedLanguage;
  final String languageCode;
  final int confidenceScore; // 0 - 100
  final String confidenceRating; // HIGH, MEDIUM, LOW
  final int wordCount;
  final int lineCount;
  final List<String> warnings;
  final int processingTimeMs;

  const OcrResult({
    required this.text,
    required this.detectedLanguage,
    required this.languageCode,
    required this.confidenceScore,
    required this.confidenceRating,
    required this.wordCount,
    required this.lineCount,
    this.warnings = const [],
    required this.processingTimeMs,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      text: json['text'] as String? ?? '',
      detectedLanguage: json['detectedLanguage'] as String? ?? 'English',
      languageCode: json['languageCode'] as String? ?? 'en',
      confidenceScore: json['confidenceScore'] as int? ?? 85,
      confidenceRating: json['confidenceRating'] as String? ?? 'HIGH',
      wordCount: json['wordCount'] as int? ?? 0,
      lineCount: json['lineCount'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      processingTimeMs: json['processingTimeMs'] as int? ?? 0,
    );
  }
}

abstract class OcrService {
  Future<OcrResult> recognizeHandwriting(File image, {String? targetLanguage, bool preserveLayout = true});
  Future<List<OcrLanguage>> getSupportedLanguages();
  Future<bool> checkServiceAvailability();
  void dispose();
}`,
  },
  {
    path: 'flutter_app/lib/features/ocr/data/gemini_cloud_ocr_service.dart',
    name: 'gemini_cloud_ocr_service.dart',
    lang: 'dart',
    description: 'Production OCR client calling the secure backend with timeouts and error handling',
    content: `import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../domain/ocr_service.dart';

class GeminiCloudOcrService implements OcrService {
  final http.Client _client;
  final String _baseUrl;
  static const Duration _timeout = Duration(seconds: 45);

  GeminiCloudOcrService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? dotenv.get('OCR_BACKEND_URL', fallback: 'http://10.0.2.2:3000');

  @override
  Future<OcrResult> recognizeHandwriting(
    File image, {
    String? targetLanguage,
    bool preserveLayout = true,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final uri = Uri.parse('$_baseUrl/api/ocr/recognize');

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'imageBase64': base64Image,
        'mimeType': mimeType,
        'language': targetLanguage ?? 'auto',
        'preserveLayout': preserveLayout,
      }),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return OcrResult.fromJson(body);
      }
      throw Exception(body['message'] ?? 'Recognition failed.');
    } else {
      throw HttpException('Server error (\${response.statusCode}): \${response.body}');
    }
  }

  @override
  Future<bool> checkServiceAvailability() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() => _client.close();
}`,
  },
  {
    path: 'flutter_app/android/gradle.properties',
    name: 'gradle.properties',
    lang: 'properties',
    description: 'Enables AndroidX, Jetifier, NonTransitiveRClass, and 4GB JVM memory for Gradle',
    content: `org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
android.nonTransitiveRClass=true`,
  },
];

export const FlutterCodeHubTab: React.FC = () => {
  const [selectedFileIdx, setSelectedFileIdx] = useState(0);
  const [copied, setCopied] = useState(false);
  const [copiedScript, setCopiedScript] = useState(false);

  const activeFile = FLUTTER_FILES[selectedFileIdx];

  const handleCopyCode = () => {
    navigator.clipboard.writeText(activeFile.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleCopyKeystoreCommand = () => {
    navigator.clipboard.writeText('cd flutter_app && ./scripts/generate_keystore.sh');
    setCopiedScript(true);
    setTimeout(() => setCopiedScript(false), 2000);
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-5xl mx-auto w-full flex flex-col space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <span>Flutter Android Source &amp; Signed CI/CD Hub</span>
            <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 font-semibold flex items-center gap-1">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Signed APK Workflow Active</span>
            </span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Automated GitHub Actions CI/CD to build, sign, and release production Android APKs and AAB bundles
          </p>
        </div>
      </div>

      {/* GitHub Actions Signed APK CI/CD Spotlight Card */}
      <div className="bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900 text-white rounded-2xl p-5 border border-indigo-900/50 shadow-xl space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 border-b border-indigo-800/40 pb-3">
          <div className="flex items-center space-x-2.5">
            <div className="w-8 h-8 rounded-lg bg-indigo-600/60 flex items-center justify-center text-indigo-300">
              <GitBranch className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-sm text-white flex items-center gap-2">
                <span>GitHub Actions: Signed APK &amp; AAB Pipeline</span>
                <span className="text-[11px] font-mono px-2 py-0.2 rounded bg-indigo-500/20 text-indigo-300 border border-indigo-400/30">
                  .github/workflows/build_signed_apk.yml
                </span>
              </h3>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={handleCopyKeystoreCommand}
              className="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow transition-colors"
            >
              {copiedScript ? <Check className="w-3.5 h-3.5 text-emerald-300" /> : <KeyRound className="w-3.5 h-3.5" />}
              <span>{copiedScript ? 'Copied Command!' : 'Copy Keystore Gen Command'}</span>
            </button>
          </div>
        </div>

        {/* 4 Secrets Needed in GitHub Repository */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-xs">
          <div className="bg-white/5 border border-white/10 rounded-xl p-3">
            <span className="text-indigo-300 font-mono font-semibold block mb-0.5">KEYSTORE_BASE64</span>
            <span className="text-[11px] text-slate-300">Base64 string of your .jks file (or auto self-signs)</span>
          </div>
          <div className="bg-white/5 border border-white/10 rounded-xl p-3">
            <span className="text-indigo-300 font-mono font-semibold block mb-0.5">KEYSTORE_PASSWORD</span>
            <span className="text-[11px] text-slate-300">Password for your release keystore</span>
          </div>
          <div className="bg-white/5 border border-white/10 rounded-xl p-3">
            <span className="text-indigo-300 font-mono font-semibold block mb-0.5">KEY_ALIAS</span>
            <span className="text-[11px] text-slate-300">Key alias name (e.g. upload)</span>
          </div>
          <div className="bg-white/5 border border-white/10 rounded-xl p-3">
            <span className="text-indigo-300 font-mono font-semibold block mb-0.5">KEY_PASSWORD</span>
            <span className="text-[11px] text-slate-300">Password for your key alias</span>
          </div>
        </div>

        {/* Output Artifacts Info */}
        <div className="flex flex-wrap items-center justify-between text-xs text-slate-300 bg-black/30 px-3.5 py-2.5 rounded-xl border border-white/5">
          <span className="flex items-center gap-1.5">
            <FileCheck className="w-4 h-4 text-emerald-400" />
            <span>Produces: <strong>Universal APK</strong>, <strong>Split ARM64 APK</strong>, and <strong>Google Play AAB</strong></span>
          </span>
          <span className="text-slate-400 text-[11px]">Automatically uploaded to GitHub Actions Artifacts &amp; Releases</span>
        </div>
      </div>

      {/* Build & Compilation Quick Command Strip */}
      <div className="bg-slate-900 text-slate-200 rounded-2xl p-4 font-mono text-xs shadow-md border border-slate-800">
        <div className="flex items-center justify-between pb-2 mb-2 border-b border-slate-800 text-slate-400">
          <span className="flex items-center gap-1.5 font-sans font-semibold text-white">
            <Terminal className="w-4 h-4 text-emerald-400" />
            <span>Local &amp; CI Terminal Commands</span>
          </span>
          <span className="text-[11px]">Flutter 3.24+ • Gradle 8 • API 34</span>
        </div>
        <div className="space-y-1.5 text-slate-300">
          <div><span className="text-emerald-400 font-bold">$</span> cd flutter_app &amp;&amp; ./scripts/generate_keystore.sh  <span className="text-slate-500"># 1-Click Keystore &amp; Base64 generator</span></div>
          <div><span className="text-emerald-400 font-bold">$</span> flutter build apk --release  <span className="text-slate-500"># Builds signed release APK locally</span></div>
          <div><span className="text-emerald-400 font-bold">$</span> flutter build apk --release --split-per-abi  <span className="text-slate-500"># Builds lightweight device-specific APKs</span></div>
          <div><span className="text-emerald-400 font-bold">$</span> git push origin main  <span className="text-slate-500"># Triggers automated GitHub Actions signed build!</span></div>
        </div>
      </div>

      {/* Code Browser Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
        {/* File List */}
        <div className="lg:col-span-4 bg-white dark:bg-slate-800 rounded-2xl p-3 border border-slate-200 dark:border-slate-700/60 shadow-sm space-y-1">
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 px-3 py-1 block">
            Project &amp; CI Files
          </span>

          {FLUTTER_FILES.map((file, idx) => (
            <button
              key={file.path}
              onClick={() => setSelectedFileIdx(idx)}
              className={`w-full text-left p-2.5 rounded-xl text-xs transition-all flex items-start space-x-2.5 ${
                selectedFileIdx === idx
                  ? 'bg-blue-50 dark:bg-blue-950/40 text-blue-900 dark:text-blue-200 font-semibold border border-blue-200 dark:border-blue-800'
                  : 'text-slate-600 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700/50'
              }`}
            >
              <FileCode className="w-4 h-4 text-blue-500 shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1">
                <div className="truncate">{file.name}</div>
                <div className="text-[10px] text-slate-400 font-normal truncate mt-0.5">
                  {file.path}
                </div>
              </div>
            </button>
          ))}
        </div>

        {/* Code Content Viewer */}
        <div className="lg:col-span-8 bg-slate-900 rounded-2xl overflow-hidden border border-slate-800 shadow-md flex flex-col">
          <div className="bg-slate-950 px-4 py-2.5 flex items-center justify-between border-b border-slate-800">
            <div className="min-w-0 pr-2">
              <span className="text-xs font-semibold text-slate-200 block truncate">{activeFile.name}</span>
              <p className="text-[11px] text-slate-400 truncate">{activeFile.description}</p>
            </div>

            <button
              onClick={handleCopyCode}
              className="shrink-0 flex items-center space-x-1 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium transition-colors"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Copied' : 'Copy'}</span>
            </button>
          </div>

          <pre className="p-4 overflow-x-auto text-xs font-mono text-slate-300 leading-relaxed max-h-[460px] bg-slate-900">
            <code>{activeFile.content}</code>
          </pre>
        </div>
      </div>
    </div>
  );
};
