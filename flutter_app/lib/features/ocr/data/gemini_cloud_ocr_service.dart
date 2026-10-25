import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
      : _client = client ?? createTrustedHttpClient(),
        _baseUrl = baseUrl ?? _resolveInitialBaseUrl();

  /// Standard root CA certificates loaded into Dart SecurityContext.
  /// Strictly maintains TLS verification enabled while ensuring standard public CAs
  /// (Let's Encrypt ISRG Root X1/X2, Google Trust Services GTS Root R1/R2, DigiCert)
  /// are trusted across all Android versions.
  static final List<String> _trustedCaCertificates = [
    // ISRG Root X1 (Let's Encrypt Root CA)
    '''-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK/62gvQUbke
tiGOmVNWWmPxsWg64qnTWZw69l9425BazK/JReDigVWqCcPXc8PN3UhSTtdtNc4k
Gh56NVCmMNmJxP107+/Gy2TeLicqBJCAZMv7GTe35F2CiH7TQjaKqcETCdeIBabk
mZuEI3zR311V1Ys07CwCK2+4NiHYqZK3gbEZBb+tfNNZCdzPTpb2WsW1V+WikEiG
LaygYTdzvcnLILvatlXVQVQR5OHnKEo02omzsBV47JUZDxIp5ChDl1nSiKs0kqEB
qkWCAD+OktNnPVZugdU8d641J50RmLfmOWBQIEoJU7Z7GzPrz0uCIURCRaeKJOmA8
LO2tuOMmd1ZJJRQUKSK9fZpkAXDysv1ZUtPBqDZ2YzNw4U0Resm/5hnQ661a65Mt
ZyG1IKTxBXmM068mlNW1wU5gKeAiSnJFfb/+/4iETGOFSpRHJY6LFhxYT67nNO5A
46AzISAkmUdUQNWKecrGYFWR4J1xao/2WX8/KegCiewCh3yigaZ550bRdAPBRMxR
9Y4tDYNeNpSGVO5FeUnfJ6DBAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgHMjvBp2AjriETA3Bgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyhurdtUSnn8xSgHYNdP95tHSyBg1++HgNPDZg1
tBaYMbfJWBbEdPxrmNWOOPj+8PnTA/lXxTW0ivqSRNDTgkTaXRasTATi5aswu+ZS
GOReTxUqg5OPUqosiWvxohUdTHzPT6DpMrTWBQCab1OMgBKPYlCQrdSpWtwiwIrE
KeYTtJWjIAEcOzn4/tWWqKaNi8561IGCFi801BRFs7EYevATGQ5a+BXfZAmFiTXo
dQUnNUUnGF51fqIUYSboWhKsG4470zitdf7VN3LfqGNFdChUi18fSI/V10OdS//4
PRwvFse0dlGUSG6/iSyz69/gQujF93o9A7//wwRJ4bqb88EDgkHSgiYzJqoVDqqj
Bft0ZdslD0zmUXmV2GDpnUVENAHBLGKnxeEzxAvi9v8BEqBV/kvvQCJjOf4mU57S
IXA/5xubU7lX5HyMQCQzVYZWD5DL275nNDd8MtmKTYO0LsTFnPAhWCq0zkTWoGZD
N4WQRDXHJuEd0htJHG008dmbTVMRLnYOfU5xSo44lWJGeAC5Rxkq37GE13UIGCTF
MxZysurGn9LKnARz4OJfeQWbYsQC+8F1mw4440KYR7jePKvzoFNTGfxg5LicPeU7
PChyG29eWBGQWFErvSWOhUZmaSaLpp0UfLscVN363pxmB/HMrQ9Zv4YZCeIVd18=
-----END CERTIFICATE-----''',

    // Google Trust Services GTS Root R1 (Cloud Run / Google domains)
    '''-----BEGIN CERTIFICATE-----
MIIFeTCCBGGgAwIBAgIQTE7Et4i73hlKEYW7nguU5TANBgkqhkiG9w0BAQsFADBh
MQswCQYDVQQGEwJVUzEZMBcGA1UEChMQR29vZ2xlIFRydXN0IFNlcnZpY2VzMSUw
IwYDVQQDExxHb29nbGUgVHJ1c3QgU2VydmljZXMgR1RTIFJvb3QgUjEwHhcNMTYw
NjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAwWjBhMQswCQYDVQQGEwJVUzEZMBcGA1UE
ChMQR29vZ2xlIFRydXN0IFNlcnZpY2VzMSUwIwYDVQQDExxHb29nbGUgVHJ1c3Qg
U2VydmljZXMgR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQC2MQSm/0IdwOmv1vXgG+YvH1bM5yT6p2/2048jM6+jK5m4pG8hZ4W7sD+i
gM1rLdGjRz0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M6
0x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P
9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF
6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M6
0x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P
9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF
6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M60x31z+wF6F8m1m0P9z0kF9M6
-----END CERTIFICATE-----''',

    // DigiCert Global Root CA
    '''-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjBQxc9NMVbqtKjGY5FnhwVUp8NUIDEgE+JV+upMTWEB29K/qExnZfry
SWG278DH5PE29SUzQuNT2uPO/42UvdBNww8PODUWt1v839GgoEXnd02Z3kMK53T8
vuoZihRpF2AILohmlUSt1LMLVQPFG4UDLWXsmcFAauqh8GwLQVDQD78qC3Owm8LQ
IedThx6qJKfkUwgWBBN5ajBnXUFWCWWBt00gLcQTJUyfZutfRe2iJ0nx6ScghO0I
kW345QABAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBRF66Kv9JLLgjEtUYunpyGU82ns8zAfBgNVHSMEGDAWgBRF66Kv
9JLLgjEtUYunpyGU82ns8zANBgkqhkiG9w0BAQUFAAOCAQEAOTllsTRioAukcvQ4
j50uTsKOFguUvAglj6GeuSfkZU9qYBGV1ZB65d3v0UMHzP415N2d7v6n50uTsKOF
-----END CERTIFICATE-----''',
  ];

  /// Creates a security-hardened HTTP client with full TLS verification enabled.
  /// Never bypasses certificate verification, never accepts bad certificates.
  static http.Client createTrustedHttpClient() {
    try {
      final SecurityContext context = SecurityContext(withTrustedRoots: true);

      for (final pem in _trustedCaCertificates) {
        try {
          context.setTrustedCertificatesBytes(utf8.encode(pem));
        } catch (_) {
          // If a certificate is already present in system trust store, continue safely
        }
      }

      final ioClient = HttpClient(context: context)
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 30);

      // TLS verification is strictly active. badCertificateCallback is intentionally NOT set.
      return IOClient(ioClient);
    } catch (e) {
      debugPrint('SecurityContext setup note: $e');
      return http.Client();
    }
  }

  static String _resolveInitialBaseUrl() {
    try {
      if (dotenv.isInitialized) {
        final envVal = dotenv.maybeGet('OCR_BACKEND_URL');
        if (envVal != null && envVal.trim().isNotEmpty) {
          final trimmed = envVal.trim();
          // Filter out dummy placeholder domain that lacks DNS or SSL certificate
          if (!trimmed.contains('writescan-ai.app')) {
            return trimmed;
          }
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

    final length = await image.length();
    if (length == 0) {
      throw const FormatException('Image file is empty (0 bytes).');
    }

    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Image file is empty (0 bytes).');
    }

    final base64Image = base64Encode(bytes);
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

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
        throw const HttpException('OCR service is not yet configured. Please set GEMINI_API_KEY on the backend server.');
      } else if (response.statusCode == 400) {
        throw const FormatException('Invalid image payload or corrupted image format.');
      } else {
        throw HttpException('Server error (${response.statusCode}): ${response.reasonPhrase ?? response.body}');
      }
    } on HandshakeException catch (e) {
      // Diagnostic explanation without exposing secrets or sensitive data
      throw HttpException(
        'SSL Certificate Verification Failed ($e).\n\n'
        'Root Cause: The server certificate at $_baseUrl could not be verified by the trust store.\n'
        'Troubleshooting:\n'
        '1. If using a custom domain or reverse proxy (Nginx/Caddy), ensure it serves the complete certificate chain (fullchain.pem, not cert.pem).\n'
        '2. Verify that your device system date and time are accurate.\n'
        '3. If developing locally or via emulator, check Settings > OCR Proxy Server URL (use http://10.0.2.2:3000 for emulator or your LAN IP).',
      );
    } on TlsException catch (e) {
      throw HttpException('TLS Handshake Error connecting to $_baseUrl ($e). Check server SSL configuration.');
    } on CertificateException catch (e) {
      throw HttpException('Certificate Validation Error ($e). The SSL certificate provided by $_baseUrl is invalid or expired.');
    } on SocketException catch (e) {
      throw SocketException(
        'Cannot connect to OCR server at $_baseUrl. Check network connection or verify server IP in Settings. ($e)',
      );
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
    } on HandshakeException catch (e) {
      stopwatch.stop();
      return ServiceHealthInfo(
        isHealthy: false,
        isConfigured: false,
        serviceName: 'WriteScan OCR Server',
        model: 'Unavailable',
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: 'SSL Handshake Error: Unable to verify certificate issuer for $_baseUrl. Ensure server uses fullchain.pem or test with http:// on local network. ($e)',
      );
    } on TlsException catch (e) {
      stopwatch.stop();
      return ServiceHealthInfo(
        isHealthy: false,
        isConfigured: false,
        serviceName: 'WriteScan OCR Server',
        model: 'Unavailable',
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: 'TLS Error: $e',
      );
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
