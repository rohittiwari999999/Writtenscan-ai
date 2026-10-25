import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../history/domain/scanned_document.dart';
import '../../history/data/document_repository.dart';

class DocumentEditorScreen extends ConsumerStatefulWidget {
  final ScannedDocument document;

  const DocumentEditorScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  bool _isSaving = false;
  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.document.editedText);
    _titleController = TextEditingController(text: widget.document.title);
    _calculateCounts(_textController.text);

    _textController.addListener(() {
      _calculateCounts(_textController.text);
    });
  }

  void _calculateCounts(String text) {
    final words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    setState(() {
      _wordCount = words;
      _charCount = text.length;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    final updated = widget.document.copyWith(
      title: _titleController.text.trim().isEmpty ? 'Untitled Scan' : _titleController.text.trim(),
      editedText: _textController.text,
      wordCount: _wordCount,
      updatedAt: DateTime.now(),
    );

    await ref.read(documentListProvider.notifier).save(updated);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saved to local history!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcribed text copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareAsText() {
    Share.share(
      _textController.text,
      subject: _titleController.text,
    );
  }

  Future<void> _exportAsTxt() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeTitle = _titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/$safeTitle.txt');
      await file.writeAsString(_textController.text);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _titleController.text,
        text: 'Exported handwritten text from WriteScan AI',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export TXT: $e')),
      );
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      final pdfDoc = pw.Document();
      final title = _titleController.text;
      final text = _textController.text;
      final dateStr = DateTime.now().toString().split('.').first;

      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'WriteScan AI',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Transcribed: $dateStr • ${widget.document.detectedLanguage} • ${widget.document.confidenceScore}% Confidence',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 14),
              pw.Text(
                text,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
              ),
            ];
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final safeTitle = _titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/$safeTitle.pdf');
      await file.writeAsBytes(await pdfDoc.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: _titleController.text,
        text: 'Exported handwritten document PDF from WriteScan AI',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description, color: Color(0xFF2563EB)),
                title: const Text('Export as Plain Text (.txt)'),
                subtitle: const Text('Lightweight plain text format'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsTxt();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Export as PDF Document (.pdf)'),
                subtitle: const Text('Formatted print-ready document'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('Share Raw Text'),
                subtitle: const Text('Send to WhatsApp, Gmail, Messages, etc.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsText();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Document Title',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Text',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onPressed: _showExportSheet,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Meta banner with confidence and metrics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.document.confidenceScore}% Confidence • ${widget.document.detectedLanguage}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  Text(
                    '$_wordCount words • $_charCount chars',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transcribed Text Editor Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Recognized handwriting will appear here...',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
