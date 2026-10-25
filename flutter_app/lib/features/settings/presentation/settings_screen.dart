import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late GeminiCloudOcrService _ocrService;

  bool _isTesting = false;
  bool _isTestingApiKey = false;
  bool _obscureApiKey = true;
  ServiceHealthInfo? _lastHealthInfo;
  DocumentRetentionPolicy _retentionPolicy = DocumentRetentionPolicy.indefinite;
  String _defaultLanguage = 'auto';

  @override
  void initState() {
    super.initState();
    _ocrService = GeminiCloudOcrService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var savedUrl = prefs.getString('custom_ocr_backend_url') ?? _ocrService.baseUrl;
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
        _urlController.text = savedUrl;
        _apiKeyController.text = savedApiKey;
        _ocrService.updateBaseUrl(savedUrl);
        if (savedApiKey.isNotEmpty) {
          _ocrService.setDirectApiKey(savedApiKey);
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
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    final currentUrl = _urlController.text.trim();
    if (currentUrl.isNotEmpty) {
      _ocrService.updateBaseUrl(currentUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_ocr_backend_url', currentUrl);
    }

    final info = await _ocrService.getHealthStatus();

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
    _ocrService.setDirectApiKey(key);

    final info = await _ocrService.getHealthStatus();

    if (!mounted) return;
    setState(() {
      _lastHealthInfo = info;
      _isTestingApiKey = false;
    });

    if (info.isHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Connected to Google Gemini Vision! Standalone mode active.'),
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
    _ocrService.setDirectApiKey(null);
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

                  // Quick presets for convenience
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
                  if (_lastHealthInfo != null && !_ocrService.isDirectApiMode) ...[
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

          // Direct Gemini API Mode (Standalone - Ideal for physical devices & 5G)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _ocrService.isDirectApiMode ? Colors.purple.shade300 : Colors.grey.shade200,
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
                          'Direct Gemini API (Standalone Mode)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_ocrService.isDirectApiMode)
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
                    'Best for Physical Phones & Mobile Data (5G/4G). '
                    'Enter your Gemini API key to run OCR directly from your phone without needing a PC server running.',
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
                      if (_ocrService.isDirectApiMode) ...[
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
                  if (_ocrService.isDirectApiMode && _lastHealthInfo != null) ...[
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
