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
    path: 'flutter_app/lib/features/ocr/domain/ocr_service.dart',
    name: 'ocr_service.dart',
    lang: 'dart',
    description: 'Requirement 3: Clean OCR service abstraction interface and typed result models',
    content: `import 'dart:io';

/// Model representing recognized handwritten OCR output
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

/// Abstract OCR Engine Interface.
/// Allows swapping between Google Vision Backend, ML Kit, or specialized models.
abstract class OcrService {
  Future<OcrResult> recognizeHandwriting(
    File image, {
    String? targetLanguage,
    bool preserveLayout = true,
  });

  Future<List<OcrLanguage>> getSupportedLanguages();
  Future<bool> checkServiceAvailability();
  void dispose();
}`,
  },
  {
    path: 'flutter_app/lib/features/ocr/data/gemini_cloud_ocr_service.dart',
    name: 'gemini_cloud_ocr_service.dart',
    lang: 'dart',
    description: 'Production OCR service calling the secure backend proxy with timeouts and error handling',
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
    if (!await image.exists()) {
      throw const FileSystemException('Selected image does not exist.');
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final uri = Uri.parse('$_baseUrl/api/ocr/recognize');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'imageBase64': base64Image,
            'mimeType': mimeType,
            'language': targetLanguage ?? 'auto',
            'preserveLayout': preserveLayout,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return OcrResult.fromJson(body);
      }
      throw Exception(body['message'] ?? 'Handwriting recognition failed.');
    } else {
      throw HttpException('Server error (\${response.statusCode}): \${response.body}');
    }
  }

  @override
  Future<bool> checkServiceAvailability() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['configured'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}`,
  },
  {
    path: 'flutter_app/pubspec.yaml',
    name: 'pubspec.yaml',
    lang: 'yaml',
    description: 'Compatible Flutter dependencies (Riverpod, GoRouter, Camera, SQLite, PDF, uCrop)',
    content: `name: writescan_ai
description: "WriteScan AI - Production-Ready Handwriting to Text Generator Mobile App"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.0.0
  camera: ^0.10.6
  image_picker: ^1.1.0
  image_cropper: ^6.0.0
  image: ^4.2.0
  http: ^1.2.1
  flutter_dotenv: ^5.1.0
  sqflite: ^2.3.3+1
  path_provider: ^2.1.3
  pdf: ^3.10.8
  share_plus: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.2

flutter:
  uses-material-design: true`,
  },
  {
    path: 'flutter_app/android/app/src/main/AndroidManifest.xml',
    name: 'AndroidManifest.xml',
    lang: 'xml',
    description: 'Android Camera, Storage, and Scoped Media permissions with uCrop registration',
    content: `<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.writescan.ai">

    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

    <application
        android:label="WriteScan AI"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/LaunchTheme"
            android:hardwareAccelerated="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <activity
            android:name="com.yalantis.ucrop.UCropActivity"
            android:screenOrientation="portrait"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
    </application>
</manifest>`,
  },
];

export const FlutterCodeHubTab: React.FC = () => {
  const [selectedFileIdx, setSelectedFileIdx] = useState(0);
  const [copied, setCopied] = useState(false);

  const activeFile = FLUTTER_FILES[selectedFileIdx];

  const handleCopyCode = () => {
    navigator.clipboard.writeText(activeFile.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-5xl mx-auto w-full flex flex-col space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <span>Flutter Android Source &amp; Build Hub</span>
            <span className="text-xs px-2.5 py-0.5 rounded-full bg-indigo-100 text-indigo-800 dark:bg-indigo-950/60 dark:text-indigo-300 font-semibold">
              Android-Ready
            </span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Modular Flutter architecture with Riverpod, Camera, SQLite, and Gemini OCR client
          </p>
        </div>
      </div>

      {/* Build & Compilation Quick Command Strip */}
      <div className="bg-slate-900 text-slate-200 rounded-2xl p-4 font-mono text-xs shadow-md border border-slate-800">
        <div className="flex items-center justify-between pb-2 mb-2 border-b border-slate-800 text-slate-400">
          <span className="flex items-center gap-1.5 font-sans font-semibold text-white">
            <Terminal className="w-4 h-4 text-emerald-400" />
            <span>Terminal Compilation Commands</span>
          </span>
          <span className="text-[11px]">Flutter 3.19+ • API Level 34</span>
        </div>
        <div className="space-y-1.5 text-slate-300">
          <div><span className="text-emerald-400 font-bold">$</span> cd flutter_app &amp;&amp; flutter pub get</div>
          <div><span className="text-emerald-400 font-bold">$</span> flutter run  <span className="text-slate-500"># Run in debug on emulator/device</span></div>
          <div><span className="text-emerald-400 font-bold">$</span> flutter build apk --release  <span className="text-slate-500"># Generates production APK</span></div>
          <div><span className="text-emerald-400 font-bold">$</span> flutter build appbundle --release  <span className="text-slate-500"># For Google Play Store submission</span></div>
        </div>
      </div>

      {/* Code Browser Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
        {/* File List */}
        <div className="lg:col-span-4 bg-white dark:bg-slate-800 rounded-2xl p-3 border border-slate-200 dark:border-slate-700/60 shadow-sm space-y-1">
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 px-3 py-1 block">
            Flutter Project Files
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
            <div>
              <span className="text-xs font-semibold text-slate-200">{activeFile.name}</span>
              <p className="text-[11px] text-slate-400">{activeFile.description}</p>
            </div>

            <button
              onClick={handleCopyCode}
              className="flex items-center space-x-1 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium transition-colors"
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
