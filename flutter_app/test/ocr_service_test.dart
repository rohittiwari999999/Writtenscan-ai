import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:writescan_ai/features/ocr/data/gemini_cloud_ocr_service.dart';
import 'package:writescan_ai/features/ocr/domain/ocr_service.dart';

void main() {
  group('OcrResult Model Tests', () {
    test('parses full backend JSON response properly', () {
      final json = {
        'success': true,
        'text': 'Line 1 of handwritten text\nLine 2 continued in cursive',
        'detectedLanguage': 'Hindi',
        'languageCode': 'hi',
        'confidenceScore': 95,
        'confidenceRating': 'HIGH',
        'wordCount': 9,
        'lineCount': 2,
        'warnings': ['Faint cursive handwriting at bottom margin'],
        'processingTimeMs': 1240,
      };

      final result = OcrResult.fromJson(json);
      expect(result.text, 'Line 1 of handwritten text\nLine 2 continued in cursive');
      expect(result.detectedLanguage, 'Hindi');
      expect(result.languageCode, 'hi');
      expect(result.confidenceScore, 95);
      expect(result.confidenceRating, 'HIGH');
      expect(result.wordCount, 9);
      expect(result.lineCount, 2);
      expect(result.warnings.length, 1);
      expect(result.processingTimeMs, 1240);
    });

    test('falls back safely when optional JSON properties are missing', () {
      final json = <String, dynamic>{
        'text': 'Hello World',
      };

      final result = OcrResult.fromJson(json);
      expect(result.text, 'Hello World');
      expect(result.detectedLanguage, 'English');
      expect(result.confidenceScore, 85);
      expect(result.confidenceRating, 'HIGH');
      expect(result.warnings, isEmpty);
    });
  });

  group('GeminiCloudOcrService Tests', () {
    test('checkServiceAvailability returns true when health endpoint is ok and configured', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'WriteScan AI OCR Engine',
              'model': 'gemini-3.8-flash',
              'configured': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      final isAvailable = await service.checkServiceAvailability();
      expect(isAvailable, isTrue);

      final health = await service.getHealthStatus();
      expect(health.isHealthy, isTrue);
      expect(health.isConfigured, isTrue);
      expect(health.model, 'gemini-3.8-flash');
    });

    test('getHealthStatus accurately captures missing key as unconfigured', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'WriteScan AI OCR Engine',
              'model': 'gemini-3.8-flash',
              'configured': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Server Error', 500);
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      final isAvailable = await service.checkServiceAvailability();
      expect(isAvailable, isFalse);

      final health = await service.getHealthStatus();
      expect(health.isHealthy, isTrue);
      expect(health.isConfigured, isFalse);
    });

    test('getSupportedLanguages parses list and falls back cleanly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/ocr/languages') {
          return http.Response(
            jsonEncode({
              'languages': [
                {
                  'code': 'hi',
                  'name': 'Hindi',
                  'nativeName': 'हिन्दी',
                  'script': 'Devanagari',
                  'supportLevel': 'Full',
                },
                {
                  'code': 'en',
                  'name': 'English',
                  'nativeName': 'English',
                  'script': 'Latin',
                  'supportLevel': 'Full',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Error', 500);
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      final langs = await service.getSupportedLanguages();
      expect(langs.length, 2);
      expect(langs.first.code, 'hi');
      expect(langs.first.nativeName, 'हिन्दी');
    });
  });
}
