import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../ocr/data/gemini_cloud_ocr_service.dart';
import '../../history/domain/scanned_document.dart';
import '../../history/data/document_repository.dart';
import '../../document_editor/presentation/document_editor_screen.dart';

class CameraScannerScreen extends ConsumerStatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  ConsumerState<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends ConsumerState<CameraScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  late GeminiCloudOcrService _ocrService;
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
    _ocrService = GeminiCloudOcrService();
    _ocrService.loadPersistedUrl();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (photo == null) return;

      if (!mounted) return;
      _showImagePreviewDialog(File(photo.path));
    } catch (e) {
      if (!mounted) return;
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
    setState(() {
      _isLoading = true;
      _loadingStep = 'Connecting to Gemini Vision 3.8 Flash...';
    });

    try {
      setState(() {
        _loadingStep = 'Transcribing handwriting & preserving layout...';
      });

      // Reload any custom backend URL saved by user
      await _ocrService.loadPersistedUrl();

      final result = await _ocrService.recognizeHandwriting(
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMsg),
            const SizedBox(height: 12),
            const Text(
              'Tips:\n• Ensure good lighting and high contrast.\n• Check network connection or verify Backend URL in Settings tab.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WriteScan AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  'Gemini 3.8 Flash',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
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
                    onPressed: () => _handleImageSelection(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture with Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () => _handleImageSelection(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Import from Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: const Color(0xFF0F172A),
                      side: BorderSide(color: Colors.grey.shade300),
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
