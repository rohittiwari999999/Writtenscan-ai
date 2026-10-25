import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ocr_service.dart';

class ServiceHealthInfo {
  final bool isHealthy;
  final bool isConfigured;
  final String serviceName;
  final String model;
  final int latencyMs;
  final String? errorMessage;

  const ServiceHealthInfo({
    required this.isHealthy,
    required this.isConfigured,
    required this.serviceName,
    required this.model,
    required this.latencyMs,
    this.errorMessage,
  });
}

class GeminiCloudOcrService implements OcrService {
  final http.Client _client;
  String _baseUrl;
  static const Duration _timeout = Duration(seconds: 45);
  static const String _defaultUrl = 'http://10.0.2.2:3000';

  GeminiCloudOcrService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveInitialBaseUrl();

  static String _resolveInitialBaseUrl() {
    try {
      if (dotenv.isInitialized) {
        final envVal = dotenv.maybeGet('OCR_BACKEND_URL');
        if (envVal != null && envVal.trim().isNotEmpty) {
          return envVal.trim();
        }
      }
    } catch (e) {
      debugPrint('Error reading .env in OCR service: $e');
    }
    return _defaultUrl;
  }

  /// Get the currently configured base URL
  String get baseUrl => _baseUrl;

  /// Update base URL dynamically (e.g. from Settings screen)
  void updateBaseUrl(String newUrl) {
    if (newUrl.trim().isNotEmpty) {
      _baseUrl = newUrl.trim();
      if (_baseUrl.endsWith('/')) {
        _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
      }
    }
  }

  /// Load custom server URL from SharedPreferences
  Future<void> loadPersistedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_ocr_backend_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        updateBaseUrl(savedUrl);
      }
    } catch (_) {}
  }

  @override
  Future<OcrResult> recognizeHandwriting(
    File image, {
    String? targetLanguage,
    bool preserveLayout = true,
  }) async {
    if (!await image.exists()) {
      throw const FileSystemException('Selected image file does not exist on device storage.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Image file is empty (0 bytes).');
    }

    final base64Image = base64Encode(bytes);
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final uri = Uri.parse('$_baseUrl/api/ocr/recognize');

    try {
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
        final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return OcrResult.fromJson(body);
        } else {
          throw Exception(body['message'] ?? 'Handwriting recognition returned an unsuccessful state.');
        }
      } else if (response.statusCode == 503) {
        throw const HttpException('OCR service is not yet configured. Please set GEMINI_API_KEY on the backend.');
      } else if (response.statusCode == 400) {
        throw const FormatException('Invalid image payload or corrupted image format.');
      } else {
        throw HttpException('Server error (${response.statusCode}): ${response.body}');
      }
    } on SocketException catch (e) {
      throw SocketException('Cannot connect to OCR server at $_baseUrl. Check network connection or verify server IP in Settings. ($e)');
    }
  }

  @override
  Future<List<OcrLanguage>> getSupportedLanguages() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/ocr/languages');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['languages'] as List<dynamic>? ?? [];
        return list.map((e) => OcrLanguage.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Fallback default language catalog with Indian and international languages
    return const [
      OcrLanguage(code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect', script: 'Any', supportLevel: 'Full'),
      OcrLanguage(code: 'en', name: 'English', nativeName: 'English', script: 'Latin (Cursive & Print)', supportLevel: 'Full'),
      OcrLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', script: 'Devanagari', supportLevel: 'Full'),
      OcrLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', script: 'Bengali-Assamese', supportLevel: 'High'),
      OcrLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी', script: 'Devanagari', supportLevel: 'High'),
      OcrLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', script: 'Tamil', supportLevel: 'High'),
      OcrLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', script: 'Telugu', supportLevel: 'High'),
      OcrLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', script: 'Gujarati', supportLevel: 'High'),
      OcrLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', script: 'Kannada', supportLevel: 'High'),
      OcrLanguage(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', script: 'Malayalam', supportLevel: 'High'),
      OcrLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', script: 'Gurmukhi', supportLevel: 'High'),
      OcrLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', script: 'Nastaliq / Arabic', supportLevel: 'Medium'),
      OcrLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', script: 'Latin', supportLevel: 'Full'),
      OcrLanguage(code: 'fr', name: 'French', nativeName: 'Français', script: 'Latin', supportLevel: 'Full'),
      OcrLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', script: 'Latin', supportLevel: 'Full'),
    ];
  }

  @override
  Future<bool> checkServiceAvailability() async {
    final status = await getHealthStatus();
    return status.isHealthy && status.isConfigured;
  }

  /// Live ping to backend returning detailed connectivity info
  Future<ServiceHealthInfo> getHealthStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ServiceHealthInfo(
          isHealthy: data['status'] == 'ok',
          isConfigured: data['configured'] == true,
          serviceName: data['service'] as String? ?? 'WriteScan AI OCR Engine',
          model: data['model'] as String? ?? 'gemini-3.8-flash',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return ServiceHealthInfo(
          isHealthy: false,
          isConfigured: false,
          serviceName: 'WriteScan OCR Server',
          model: 'Unavailable',
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ServiceHealthInfo(
        isHealthy: false,
        isConfigured: false,
        serviceName: 'WriteScan OCR Server',
        model: 'Unavailable',
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _client.close();
  }
}
