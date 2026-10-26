import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../ocr/data/ocr_engine_manager.dart';
import '../../history/domain/scanned_document.dart';
import '../../history/data/document_repository.dart';
import '../../document_editor/presentation/document_editor_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class CameraScannerScreen extends ConsumerStatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  ConsumerState<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends ConsumerState<CameraScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  late OcrEngineManager _ocrManager;
  bool _isLoading = false;
  String _loadingStep = '';
  String _selectedLanguage = 'auto';

  final List<Map<String, String>> _languages = const [
    {'code': 'auto', 'label': 'Auto Detect (All Languages)'},
    {'code': 'en', 'label': 'English (Cursive & Print)'},
    {'code': 'hi', 'label': 'Hindi (हिन्दी - Devanagari)'},
    {'code': 'mr', 'label': 'Marathi (मराठी)'},
    {'code': 'bn', 'label': 'Bengali (বাংলা)'},
    {'code': 'ta', 'label': 'Tamil (தமிழ்)'},
    {'code': 'te', 'label': 'Telugu (తెలుగు)'},
    {'code': 'gu', 'label': 'Gujarati (ગુજરાતી)'},
    {'code': 'kn', 'label': 'Kannada (ಕನ್ನಡ)'},
    {'code': 'ml', 'label': 'Malayalam (മലയാളം)'},
    {'code': 'pa', 'label': 'Punjabi (ਪੰਜਾਬੀ)'},
    {'code': 'ur', 'label': 'Urdu (اردو)'},
    {'code': 'es', 'label': 'Spanish (Español)'},
    {'code': 'fr', 'label': 'French (Français)'},
    {'code': 'de', 'label': 'German (Deutsch)'},
  ];

  @override
  void initState() {
    super.initState();
    _ocrManager = OcrEngineManager();
    _ocrManager.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ocrManager.dispose();
    super.dispose();
  }

  bool _isPickingImage = false;

  Future<void> _handleImageSelection(ImageSource source) async {
    if (_isPickingImage || _isLoading) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );

      if (!mounted) return;

      // Handle user cancellation gracefully without error popups
      if (photo == null) {
        setState(() {
          _isPickingImage = false;
        });
        return;
      }

      final file = File(photo.path);
      if (!await file.exists()) {
        setState(() {
          _isPickingImage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected image file was not found on device storage.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final length = await file.length();
      if (length == 0) {
        setState(() {
          _isPickingImage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected image is empty (0 bytes). Please choose another photo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isPickingImage = false;
      });

      _showImagePreviewDialog(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPickingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access image: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showImagePreviewDialog(File imageFile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Document Preview & Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 220,
                  color: Colors.grey.shade100,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(
                  labelText: 'Recognition Language',
                  prefixIcon: const Icon(Icons.language),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang['code'],
                    child: Text(lang['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLanguage = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _runOcr(imageFile);
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Enhance & Recognize Handwriting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runOcr(File imageFile) async {
    final isOffline = _ocrManager.engineType == OcrEngineType.onDevice;
    setState(() {
      _isLoading = true;
      _loadingStep = isOffline
          ? 'Running Inbuilt On-Device OCR (100% Offline)...'
          : 'Connecting to Cloud Gemini Vision...';
    });

    try {
      setState(() {
        _loadingStep = isOffline
            ? 'Transcribing handwriting accurately on-device...'
            : 'Transcribing handwriting & preserving layout...';
      });

      await _ocrManager.initialize();

      final result = await _ocrManager.recognizeHandwriting(
        imageFile,
        targetLanguage: _selectedLanguage,
      );

      if (!mounted) return;

      setState(() {
        _loadingStep = 'Finalizing document...';
      });

      final doc = ScannedDocument(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        title: '${result.detectedLanguage} Note',
        rawText: result.text,
        editedText: result.text,
        imagePath: imageFile.path,
        detectedLanguage: result.detectedLanguage,
        confidenceScore: result.confidenceScore,
        wordCount: result.wordCount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save automatically into DocumentRepository
      await ref.read(documentListProvider.notifier).save(doc);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentEditorScreen(document: doc),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStep = '';
        });
      }
    }
  }

  void _showErrorDialog(String errorMsg) {
    final isConnectionError = errorMsg.contains('10.0.2.2') ||
        errorMsg.contains('Cannot connect') ||
        errorMsg.contains('SocketException') ||
        errorMsg.contains('SSL Certificate');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Recognition Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMsg, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnectionError ? 'Quick Fix for Physical Phone:' : 'Tips:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnectionError
                          ? '• 10.0.2.2 only works in the PC Emulator.\n• For a physical phone, connect phone & PC to same Wi-Fi and enter http://YOUR_PC_IP:3000 in Settings.\n• Or enter your free Gemini API Key in Settings to transcribe directly without needing a PC!'
                          : '• Ensure good lighting and high contrast.\n• Check network connection or verify Backend URL in Settings tab.',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) {
                _ocrManager.initialize().then((_) {
                  if (mounted) setState(() {});
                });
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadSampleNote(bool isHindi) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sampleFile = File('${tempDir.path}/sample_${isHindi ? "hi" : "en"}.png');

      // Create a clean sample note canvas image using 1x1 transparent PNG fallback or byte generator
      const base64Png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      await sampleFile.writeAsBytes(base64Decode(base64Png));

      setState(() {
        _selectedLanguage = isHindi ? 'hi' : 'en';
      });

      if (!mounted) return;
      _runOcr(sampleFile);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sample load error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnDevice = _ocrManager.engineType == OcrEngineType.onDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WriteScan AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) {
                _ocrManager.initialize().then((_) {
                  if (mounted) setState(() {});
                });
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnDevice ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isOnDevice ? Colors.green.shade300 : Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnDevice ? Icons.offline_pin : Icons.bolt,
                    size: 14,
                    color: isOnDevice ? Colors.green.shade800 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnDevice ? 'Inbuilt Offline OCR' : 'Cloud Gemini',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnDevice ? Colors.green.shade900 : Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStep,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Deciphering handwriting strokes and script structure...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Scanner Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, const Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade900.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.document_scanner,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Handwriting to Text Generator',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan handwritten notes, Devanagari Hindi, cursive memos, and classroom boards.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Language selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.translate, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLanguage,
                              isDense: true,
                              isExpanded: true,
                              items: _languages.map((l) {
                                return DropdownMenuItem(
                                  value: l['code'],
                                  child: Text(
                                    l['label']!,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedLanguage = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: _isLoading || _isPickingImage
                        ? null
                        : () => _handleImageSelection(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 22),
                    label: const Text(
                      'Capture with Camera',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Import from Gallery Button - High contrast, pristine white surface with royal blue border & typography
                  ElevatedButton.icon(
                    onPressed: _isLoading || _isPickingImage
                        ? null
                        : () => _handleImageSelection(ImageSource.gallery),
                    icon: _isPickingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : const Icon(Icons.photo_library_outlined, size: 22, color: Color(0xFF2563EB)),
                    label: Text(
                      _isPickingImage ? 'Opening Gallery...' : 'Import from Gallery',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2563EB),
                      elevation: 1,
                      shadowColor: Colors.black12,
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Sample Tests
                  const Text(
                    'Quick Test with Sample Notes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _loadSampleNote(true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hindi Note',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Devanagari script',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _loadSampleNote(false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Text('📝', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'English Note',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Cursive note',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
