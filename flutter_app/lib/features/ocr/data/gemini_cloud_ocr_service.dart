import 'dart:convert';
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
    } on SocketException {
      throw const SocketException('Cannot connect to OCR server. Check your network connection.');
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

    // Fallback default language catalog
    return const [
      OcrLanguage(code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect', script: 'Any', supportLevel: 'Full'),
      OcrLanguage(code: 'en', name: 'English', nativeName: 'English', script: 'Latin', supportLevel: 'Full'),
      OcrLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', script: 'Devanagari', supportLevel: 'Full'),
      OcrLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', script: 'Bengali', supportLevel: 'High'),
      OcrLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी', script: 'Devanagari', supportLevel: 'High'),
      OcrLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', script: 'Tamil', supportLevel: 'High'),
      OcrLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', script: 'Telugu', supportLevel: 'High'),
    ];
  }

  @override
  Future<bool> checkServiceAvailability() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 6));
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
}
