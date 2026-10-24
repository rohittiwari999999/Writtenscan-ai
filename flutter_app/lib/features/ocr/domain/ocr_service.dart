import 'dart:io';

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

  Map<String, dynamic> toJson() => {
    'text': text,
    'detectedLanguage': detectedLanguage,
    'languageCode': languageCode,
    'confidenceScore': confidenceScore,
    'confidenceRating': confidenceRating,
    'wordCount': wordCount,
    'lineCount': lineCount,
    'warnings': warnings,
    'processingTimeMs': processingTimeMs,
  };
}

/// Language metadata model
class OcrLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String script;
  final String supportLevel; // Full, High, Medium, Experimental

  const OcrLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.script,
    required this.supportLevel,
  });

  factory OcrLanguage.fromJson(Map<String, dynamic> json) {
    return OcrLanguage(
      code: json['code'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String,
      script: json['script'] as String,
      supportLevel: json['supportLevel'] as String,
    );
  }
}

/// Abstract OCR Engine Interface.
/// Allows swapping between Google Vision Backend, ML Kit offline, or custom models.
abstract class OcrService {
  /// Recognize handwritten text from an image file
  Future<OcrResult> recognizeHandwriting(
    File image, {
    String? targetLanguage,
    bool preserveLayout = true,
  });

  /// Retrieve list of officially supported handwriting languages
  Future<List<OcrLanguage>> getSupportedLanguages();

  /// Check connectivity and backend OCR service availability
  Future<bool> checkServiceAvailability();

  /// Clean up any resources, clients, or caches
  void dispose();
}
