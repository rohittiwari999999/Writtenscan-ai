import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ocr_service.dart';
import 'mlkit_on_device_ocr_service.dart';
import 'gemini_cloud_ocr_service.dart';

enum OcrEngineType {
  onDevice, // 100% Inbuilt standalone on-device OCR (Zero API, Offline)
  cloudGemini, // Cloud-based Gemini Multimodal Vision OCR
}

extension OcrEngineTypeExt on OcrEngineType {
  String get displayName {
    switch (this) {
      case OcrEngineType.onDevice:
        return 'Inbuilt On-Device OCR (Offline / No API Key)';
      case OcrEngineType.cloudGemini:
        return 'Cloud Gemini Vision OCR';
    }
  }

  String get shortName {
    switch (this) {
      case OcrEngineType.onDevice:
        return 'Inbuilt Offline OCR';
      case OcrEngineType.cloudGemini:
        return 'Cloud Gemini';
    }
  }

  String get key {
    switch (this) {
      case OcrEngineType.onDevice:
        return 'on_device';
      case OcrEngineType.cloudGemini:
        return 'cloud_gemini';
    }
  }

  static OcrEngineType fromKey(String? key) {
    if (key == 'cloud_gemini') {
      return OcrEngineType.cloudGemini;
    }
    // Default to Inbuilt On-Device Standalone OCR
    return OcrEngineType.onDevice;
  }
}

class OcrEngineManager implements OcrService {
  static const String _prefKey = 'writescan_ocr_engine_type';

  final MlKitOnDeviceOcrService _onDeviceService;
  final GeminiCloudOcrService _cloudService;
  OcrEngineType _engineType = OcrEngineType.onDevice;

  OcrEngineManager({
    MlKitOnDeviceOcrService? onDeviceService,
    GeminiCloudOcrService? cloudService,
  })  : _onDeviceService = onDeviceService ?? MlKitOnDeviceOcrService(),
        _cloudService = cloudService ?? GeminiCloudOcrService();

  OcrEngineType get engineType => _engineType;
  MlKitOnDeviceOcrService get onDeviceService => _onDeviceService;
  GeminiCloudOcrService get cloudService => _cloudService;

  OcrService get activeService {
    return _engineType == OcrEngineType.onDevice ? _onDeviceService : _cloudService;
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_prefKey);
      _engineType = OcrEngineTypeExt.fromKey(key);
      await _cloudService.loadPersistedUrl();
    } catch (_) {}
  }

  Future<void> setEngineType(OcrEngineType type) async {
    _engineType = type;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, type.key);
    } catch (_) {}
  }

  /// Check if Cloud Gemini OCR is available (via direct API key or reachable backend proxy)
  Future<bool> isCloudGeminiConfigured() async {
    if (_cloudService.isDirectApiMode) return true;
    try {
      return await _cloudService.checkServiceAvailability();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<OcrResult> recognizeHandwriting(
    File image, {
    String? targetLanguage,
    bool preserveLayout = true,
  }) async {
    // 1. If explicit Cloud Gemini mode is active, call it directly
    if (_engineType == OcrEngineType.cloudGemini) {
      return _cloudService.recognizeHandwriting(
        image,
        targetLanguage: targetLanguage,
        preserveLayout: preserveLayout,
      );
    }

    // 2. Run Inbuilt On-Device OCR
    final onDeviceResult = await _onDeviceService.recognizeHandwriting(
      image,
      targetLanguage: targetLanguage,
      preserveLayout: preserveLayout,
    );

    // If on-device produced valid substantive text, return immediately
    if (onDeviceResult.text.trim().isNotEmpty && onDeviceResult.text.trim().length > 3) {
      return onDeviceResult;
    }

    // 3. Smart Automatic Fallback:
    // If on-device produced no legible text (common for cursive Hindi handwriting),
    // and Cloud Gemini Vision is configured, seamlessly transcribe with Cloud Gemini!
    final hasCloud = await isCloudGeminiConfigured();
    if (hasCloud) {
      try {
        final cloudResult = await _cloudService.recognizeHandwriting(
          image,
          targetLanguage: targetLanguage,
          preserveLayout: preserveLayout,
        );
        if (cloudResult.text.trim().isNotEmpty) {
          return cloudResult;
        }
      } catch (_) {
        // Suppress fallback error and return onDeviceResult
      }
    }

    return onDeviceResult;
  }

  @override
  Future<List<OcrLanguage>> getSupportedLanguages() {
    return activeService.getSupportedLanguages();
  }

  @override
  Future<bool> checkServiceAvailability() {
    return activeService.checkServiceAvailability();
  }

  @override
  void dispose() {
    _onDeviceService.dispose();
    _cloudService.dispose();
  }
}

final ocrEngineManagerProvider = Provider<OcrEngineManager>((ref) {
  final manager = OcrEngineManager();
  manager.initialize();
  ref.onDispose(() => manager.dispose());
  return manager;
});
