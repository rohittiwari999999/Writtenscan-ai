import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../history/domain/scanned_document.dart';

class DocumentEditorScreen extends StatefulWidget {
  final ScannedDocument document;

  const DocumentEditorScreen({super.key, required this.document});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.document.editedText);
    _titleController = TextEditingController(text: widget.document.title);
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  void _shareText() {
    Share.share(
      _textController.text,
      subject: _titleController.text,
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
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareText,
          ),
          IconButton(
            icon: Icon(_isSaved ? Icons.check : Icons.save),
            tooltip: 'Save',
            onPressed: () {
              setState(() {
                _isSaved = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document saved locally!')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.document.confidenceScore}% Confidence • ${widget.document.detectedLanguage}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Recognized text...',
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
