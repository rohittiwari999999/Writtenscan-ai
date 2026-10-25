import 'dart:convert';
import 'dart:io';
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

    test('getHealthStatus captures SSL HandshakeException safely with clear diagnostic', () async {
      final mockClient = MockClient((request) async {
        throw const HandshakeException(
          'Handshake error in client: CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate (handshake.cc:393)',
        );
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'https://custom-ocr-domain.internal',
      );

      final health = await service.getHealthStatus();
      expect(health.isHealthy, isFalse);
      expect(health.isConfigured, isFalse);
      expect(health.errorMessage, isNotNull);
      expect(health.errorMessage, contains('SSL Handshake Error'));
      expect(health.errorMessage, contains('fullchain.pem'));
    });

    test('getHealthStatus captures SocketException gracefully when backend is unreachable', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused (OS Error: Connection refused, errno = 111)');
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://10.0.2.2:3000',
      );

      final health = await service.getHealthStatus();
      expect(health.isHealthy, isFalse);
      expect(health.isConfigured, isFalse);
      expect(health.errorMessage, isNotNull);
      expect(health.errorMessage, contains('Connection refused'));
    });

    test('recognizeHandwriting returns OcrResult on successful 200 response', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final tempFile = File('${tempDir.path}/sample.jpg');
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/ocr/recognize');
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        expect(decoded['mimeType'], 'image/jpeg');
        expect(decoded['language'], 'hi');
        expect(decoded['preserveLayout'], isTrue);

        return http.Response(
          jsonEncode({
            'success': true,
            'text': 'नमस्ते दुनिया\nयह हस्तलिखित पाठ है।',
            'detectedLanguage': 'Hindi',
            'languageCode': 'hi',
            'confidenceScore': 94,
            'confidenceRating': 'HIGH',
            'wordCount': 6,
            'lineCount': 2,
            'warnings': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      final result = await service.recognizeHandwriting(tempFile, targetLanguage: 'hi');
      expect(result.text, contains('नमस्ते दुनिया'));
      expect(result.detectedLanguage, 'Hindi');
      expect(result.confidenceScore, 94);
    });

    test('recognizeHandwriting throws FileSystemException when file does not exist', () async {
      final nonExistentFile = File('/non_existent_path/fake_image.jpg');
      final service = GeminiCloudOcrService(
        client: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(
        service.recognizeHandwriting(nonExistentFile),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('recognizeHandwriting throws FormatException when file is 0 bytes', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_empty_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final emptyFile = File('${tempDir.path}/empty.jpg');
      await emptyFile.writeAsBytes([]);

      final service = GeminiCloudOcrService(
        client: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(
        service.recognizeHandwriting(emptyFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('recognizeHandwriting throws HttpException on 503 (GEMINI_API_KEY missing)', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_503_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final sampleFile = File('${tempDir.path}/sample.jpg');
      await sampleFile.writeAsBytes([0x01, 0x02, 0x03]);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Backend OCR service is not configured with GEMINI_API_KEY'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(
        service.recognizeHandwriting(sampleFile),
        throwsA(predicate((e) => e is HttpException && e.message.contains('GEMINI_API_KEY'))),
      );
    });

    test('recognizeHandwriting throws FormatException on 400 (Bad image payload)', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_400_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final sampleFile = File('${tempDir.path}/corrupt.jpg');
      await sampleFile.writeAsBytes([0x01, 0x02, 0x03]);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Invalid image format'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(
        service.recognizeHandwriting(sampleFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('recognizeHandwriting translates HandshakeException into diagnostic SSL message', () async {
      final tempDir = await Directory.systemTemp.createTemp('ocr_ssl_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final sampleFile = File('${tempDir.path}/sample.jpg');
      await sampleFile.writeAsBytes([0x01, 0x02, 0x03]);

      final mockClient = MockClient((request) async {
        throw const HandshakeException(
          'Handshake error in client: CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate (handshake.cc:393)',
        );
      });

      final service = GeminiCloudOcrService(
        client: mockClient,
        baseUrl: 'https://writescan-ai.app',
      );

      await expectLater(
        service.recognizeHandwriting(sampleFile),
        throwsA(predicate((e) =>
            e is HttpException &&
            e.message.contains('SSL Certificate Verification Failed') &&
            e.message.contains('fullchain.pem'))),
      );
    });
  });
}
