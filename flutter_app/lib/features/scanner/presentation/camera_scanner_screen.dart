import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../ocr/data/gemini_cloud_ocr_service.dart';
import '../../history/domain/scanned_document.dart';
import '../../document_editor/presentation/document_editor_screen.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiCloudOcrService _ocrService = GeminiCloudOcrService();
  bool _isLoading = false;
  String _selectedLanguage = 'auto';

  Future<void> _processImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );
      if (photo == null) return;

      setState(() {
        _isLoading = true;
      });

      final File imageFile = File(photo.path);
      final result = await _ocrService.recognizeHandwriting(
        imageFile,
        targetLanguage: _selectedLanguage,
      );

      if (!mounted) return;

      final doc = ScannedDocument(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        title: '${result.detectedLanguage} Note',
        rawText: result.text,
        editedText: result.text,
        imagePath: photo.path,
        detectedLanguage: result.detectedLanguage,
        confidenceScore: result.confidenceScore,
        wordCount: result.wordCount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentEditorScreen(document: doc),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transcription error: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WriteScan AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Transcribing handwriting with Gemini Vision...',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner,
                      size: 72,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Scan Handwritten Notes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Convert photos of notebooks, recipes, letters & forms into editable text.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    onPressed: () => _processImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture with Camera'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _processImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Import from Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
