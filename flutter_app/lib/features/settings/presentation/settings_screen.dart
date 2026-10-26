import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ocr/data/ocr_engine_manager.dart';
import '../../ocr/data/gemini_cloud_ocr_service.dart';
import '../../history/data/document_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  late OcrEngineManager _ocrManager;

  OcrEngineType _engineType = OcrEngineType.onDevice;
  bool _isTesting = false;
  bool _isTestingApiKey = false;
  bool _obscureApiKey = true;
  ServiceHealthInfo? _lastHealthInfo;
  DocumentRetentionPolicy _retentionPolicy = DocumentRetentionPolicy.indefinite;
  String _defaultLanguage = 'auto';

  @override
  void initState() {
    super.initState();
    _ocrManager = OcrEngineManager();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _ocrManager.initialize();
    final prefs = await SharedPreferences.getInstance();
    var savedUrl = prefs.getString('custom_ocr_backend_url') ?? _ocrManager.cloudService.baseUrl;
    if (savedUrl.contains('writescan-ai.app')) {
      savedUrl = 'http://10.0.2.2:3000';
      await prefs.setString('custom_ocr_backend_url', savedUrl);
    }
    final savedLang = prefs.getString('default_ocr_language') ?? 'auto';
    final savedApiKey = prefs.getString('user_gemini_api_key') ?? '';

    final repo = ref.read(documentRepositoryProvider);
    final policy = await repo.getRetentionPolicy();

    if (mounted) {
      setState(() {
        _engineType = _ocrManager.engineType;
        _urlController.text = savedUrl;
        _apiKeyController.text = savedApiKey;
        _ocrManager.cloudService.updateBaseUrl(savedUrl);
        if (savedApiKey.isNotEmpty) {
          _ocrManager.cloudService.setDirectApiKey(savedApiKey);
        }
        _defaultLanguage = savedLang;
        _retentionPolicy = policy;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _ocrManager.dispose();
    super.dispose();
  }

  Future<void> _switchEngineType(OcrEngineType type) async {
    await _ocrManager.setEngineType(type);
    setState(() {
      _engineType = type;
      _lastHealthInfo = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == OcrEngineType.onDevice
                ? '✅ Inbuilt Standalone OCR active (100% Offline, No API Key).'
                : 'Switched to Cloud Gemini Vision OCR mode.',
          ),
          backgroundColor: type == OcrEngineType.onDevice ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    final currentUrl = _urlController.text.trim();
    if (currentUrl.isNotEmpty) {
      _ocrManager.cloudService.updateBaseUrl(currentUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_ocr_backend_url', currentUrl);
    }

    final info = await _ocrManager.cloudService.getHealthStatus();

    if (!mounted) return;
    setState(() {
      _lastHealthInfo = info;
      _isTesting = false;
    });
  }

  Future<void> _saveAndTestApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Gemini API Key.')),
      );
      return;
    }

    setState(() {
      _isTestingApiKey = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_gemini_api_key', key);
    _ocrManager.cloudService.setDirectApiKey(key);

    final info = await _ocrManager.cloudService.getHealthStatus();

    if (!mounted) return;
    setState(() {
      _lastHealthInfo = info;
      _isTestingApiKey = false;
    });

    if (info.isHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Connected to Google Gemini Vision!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gemini Key verification failed: ${info.errorMessage ?? "Invalid key"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_gemini_api_key');
    _apiKeyController.clear();
    _ocrManager.cloudService.setDirectApiKey(null);
    setState(() {
      _lastHealthInfo = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleared Gemini API Key. Switched back to Backend Server mode.')),
      );
    }
  }

  Future<void> _updateRetentionPolicy(DocumentRetentionPolicy policy) async {
    final repo = ref.read(documentRepositoryProvider);
    await repo.setRetentionPolicy(policy);
    setState(() {
      _retentionPolicy = policy;
    });
    ref.read(documentListProvider.notifier).loadDocuments();
  }

  Future<void> _updateDefaultLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_ocr_language', code);
    setState(() {
      _defaultLanguage = code;
    });
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Local Documents?'),
        content: const Text('This will delete all saved scans and transcription history on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(documentRepositoryProvider);
              await repo.clearAll();
              ref.read(documentListProvider.notifier).loadDocuments();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All local documents cleared.')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Diagnostics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Primary OCR Engine Selection Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _engineType == OcrEngineType.onDevice
                    ? Colors.green.shade400
                    : Colors.blue.shade300,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _engineType == OcrEngineType.onDevice
                            ? Icons.offline_pin
                            : Icons.cloud_done_outlined,
                        color: _engineType == OcrEngineType.onDevice
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'OCR Processing Engine',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Inbuilt Standalone OCR (Selected by default)
                  InkWell(
                    onTap: () => _switchEngineType(OcrEngineType.onDevice),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _engineType == OcrEngineType.onDevice
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _engineType == OcrEngineType.onDevice
                              ? Colors.green.shade600
                              : Colors.grey.shade300,
                          width: _engineType == OcrEngineType.onDevice ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<OcrEngineType>(
                            value: OcrEngineType.onDevice,
                            groupValue: _engineType,
                            activeColor: Colors.green.shade700,
                            onChanged: (val) {
                              if (val != null) _switchEngineType(val);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Inbuilt On-Device OCR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Recommended',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '• 100% Offline • Zero API Keys • Instant Processing\n'
                                  '• Standalone: No PC server, Wi-Fi, or internet required\n'
                                  '• Transcribes handwriting in English, Hindi, Devanagari, Latin & CJK scripts',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Cloud Gemini Vision OCR
                  InkWell(
                    onTap: () => _switchEngineType(OcrEngineType.cloudGemini),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _engineType == OcrEngineType.cloudGemini
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _engineType == OcrEngineType.cloudGemini
                              ? Colors.blue.shade600
                              : Colors.grey.shade300,
                          width: _engineType == OcrEngineType.cloudGemini ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<OcrEngineType>(
                            value: OcrEngineType.cloudGemini,
                            groupValue: _engineType,
                            activeColor: Colors.blue.shade700,
                            onChanged: (val) {
                              if (val != null) _switchEngineType(val);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cloud Gemini Vision OCR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Requires network connection to your Node.js proxy server or Google Gemini API Key.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Inbuilt Engine Detail Card (Displayed when onDevice is active)
          if (_engineType == OcrEngineType.onDevice) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.shade200),
              ),
              color: Colors.green.shade50.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Inbuilt Offline Mode Active',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'WriteScan AI is running completely standalone. All handwriting and document scans are processed locally on your phone\'s neural hardware.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.wifi_off, size: 14, color: Colors.green),
                          label: const Text('100% Offline', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                        ),
                        Chip(
                          avatar: const Icon(Icons.vpn_key_off, size: 14, color: Colors.green),
                          label: const Text('Zero API Key', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                        ),
                        Chip(
                          avatar: const Icon(Icons.speed, size: 14, color: Colors.green),
                          label: const Text('Instant On-Device', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Cloud Engine Cards (Displayed when cloudGemini is active)
          if (_engineType == OcrEngineType.cloudGemini) ...[
            // Live Backend Status & Health Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _lastHealthInfo == null
                      ? Colors.grey.shade200
                      : (_lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                          ? Colors.green.shade300
                          : Colors.orange.shade300),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastHealthInfo == null
                              ? Icons.sensors
                              : (_lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                                  ? Icons.check_circle
                                  : Icons.warning_amber_rounded),
                          color: _lastHealthInfo == null
                              ? Colors.blue.shade700
                              : (_lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                                  ? Colors.green.shade600
                                  : Colors.orange.shade800),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'OCR Backend Connectivity',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_lastHealthInfo != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                                  ? 'Connected'
                                  : 'Disconnected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _lastHealthInfo!.isHealthy && _lastHealthInfo!.isConfigured
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'OCR Proxy Server URL:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'http://192.168.x.x:3000 or http://10.0.2.2:3000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Reset to default emulator URL',
                          onPressed: () {
                            _urlController.text = 'http://10.0.2.2:3000';
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_urlController.text.contains('10.0.2.2')) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Physical Phone Notice: "10.0.2.2" only works inside PC emulators. If testing on a real phone, use "Local LAN" (same Wi-Fi) or "Direct Gemini API" below.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.wifi, size: 14),
                          label: const Text('Local LAN (192.168.1.x)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _urlController.text = 'http://192.168.1.100:3000';
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.wifi, size: 14),
                          label: const Text('Local LAN (192.168.0.x)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _urlController.text = 'http://192.168.0.100:3000';
                            setState(() {});
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.android, size: 14),
                          label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _urlController.text = 'http://10.0.2.2:3000';
                            setState(() {});
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.network_check, size: 18),
                        label: Text(_isTesting ? 'Testing Ping...' : 'Test Backend Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (_lastHealthInfo != null && !_ocrManager.cloudService.isDirectApiMode) ...[
                      const Divider(height: 24),
                      Text(
                        'Verified Model: ${_lastHealthInfo!.model}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Roundtrip Latency: ${_lastHealthInfo!.latencyMs} ms',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (_lastHealthInfo!.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Connection Diagnostic:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lastHealthInfo!.errorMessage!,
                                style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Direct Gemini API Mode
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _ocrManager.cloudService.isDirectApiMode ? Colors.purple.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Direct Gemini API (Optional)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_ocrManager.cloudService.isDirectApiMode)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your Gemini API key to run Cloud OCR directly from your phone.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'AIzaSy...',
                        labelText: 'Your Gemini API Key (Stored Locally On-Device)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingApiKey ? null : _saveAndTestApiKey,
                            icon: _isTestingApiKey
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, size: 16),
                            label: Text(_isTestingApiKey ? 'Verifying...' : 'Save & Activate Key'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        if (_ocrManager.cloudService.isDirectApiMode) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _clearApiKey,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Clear Key'),
                          ),
                        ],
                      ],
                    ),
                    if (_ocrManager.cloudService.isDirectApiMode && _lastHealthInfo != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Direct Engine: Google Gemini Vision 2.5 Flash (${_lastHealthInfo!.latencyMs}ms)',
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // OCR Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'OCR & Recognition',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: Color(0xFF2563EB)),
                  title: const Text('Default Recognition Script'),
                  subtitle: Text(_defaultLanguage == 'hi'
                      ? 'Hindi (हिन्दी - Devanagari)'
                      : (_defaultLanguage == 'en' ? 'English' : 'Auto Detect')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String>(
                              title: const Text('Auto Detect (All Languages)'),
                              value: 'auto',
                              groupValue: _defaultLanguage,
                              onChanged: (val) {
                                Navigator.pop(ctx);
                                if (val != null) _updateDefaultLanguage(val);
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Hindi (हिन्दी - Devanagari)'),
                              value: 'hi',
                              groupValue: _defaultLanguage,
                              onChanged: (val) {
                                Navigator.pop(ctx);
                                if (val != null) _updateDefaultLanguage(val);
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('English (Cursive & Print)'),
                              value: 'en',
                              groupValue: _defaultLanguage,
                              onChanged: (val) {
                                Navigator.pop(ctx);
                                if (val != null) _updateDefaultLanguage(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF2563EB)),
                  title: const Text('Document Retention Policy'),
                  subtitle: Text(_retentionPolicy.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: DocumentRetentionPolicy.values.map((pol) {
                            return RadioListTile<DocumentRetentionPolicy>(
                              title: Text(pol.displayName),
                              value: pol,
                              groupValue: _retentionPolicy,
                              onChanged: (val) {
                                Navigator.pop(ctx);
                                if (val != null) _updateRetentionPolicy(val);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Security & Architecture
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Security & Privacy',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.security, color: Colors.green),
                  title: Text('API Key Zero-Exposure'),
                  subtitle: Text('Gemini API key is held exclusively on the server proxy. No secrets are embedded in the mobile APK.'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.cloud_off, color: Colors.blue),
                  title: Text('Zero Cloud Retention'),
                  subtitle: Text('Document images are processed in-flight for OCR transcription only and are never stored on cloud servers.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Clear All Local Data', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Purge all documents saved on this device'),
                  onTap: _confirmClearData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('WriteScan AI'),
              subtitle: Text('Version 1.0.0+1 • Model: Google Gemini Vision 3.8 Flash'),
            ),
          ),
        ],
      ),
    );
  }
}
