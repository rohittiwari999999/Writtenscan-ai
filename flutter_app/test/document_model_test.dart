import 'package:flutter_test/flutter_test.dart';
import 'package:writescan_ai/features/history/domain/scanned_document.dart';
import 'package:writescan_ai/features/history/data/document_repository.dart';

void main() {
  group('ScannedDocument Model Tests', () {
    test('should properly serialize toMap and deserialize fromMap', () {
      final now = DateTime(2026, 10, 25, 12, 0, 0);
      final doc = ScannedDocument(
        id: 'doc_123',
        title: 'Meeting Notes Hindi',
        rawText: 'आज की बैठक में महत्वपूर्ण निर्णय लिए गए।',
        editedText: 'आज की बैठक में महत्वपूर्ण निर्णय लिए गए।',
        imagePath: '/data/user/0/com.writescan.ai/cache/scan.jpg',
        detectedLanguage: 'Hindi',
        confidenceScore: 94,
        wordCount: 8,
        createdAt: now,
        updatedAt: now,
      );

      final map = doc.toMap();
      expect(map['id'], 'doc_123');
      expect(map['title'], 'Meeting Notes Hindi');
      expect(map['raw_text'], 'आज की बैठक में महत्वपूर्ण निर्णय लिए गए।');
      expect(map['confidence_score'], 94);
      expect(map['detected_language'], 'Hindi');

      final reconstructed = ScannedDocument.fromMap(map);
      expect(reconstructed.id, doc.id);
      expect(reconstructed.title, doc.title);
      expect(reconstructed.rawText, doc.rawText);
      expect(reconstructed.confidenceScore, doc.confidenceScore);
      expect(reconstructed.detectedLanguage, doc.detectedLanguage);
      expect(reconstructed.createdAt, doc.createdAt);
    });

    test('copyWith updates specified fields while keeping others unchanged', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc_456',
        title: 'Original Title',
        rawText: 'Raw transcribed text',
        editedText: 'Raw transcribed text',
        detectedLanguage: 'English',
        confidenceScore: 88,
        wordCount: 3,
        createdAt: now,
        updatedAt: now,
      );

      final updated = doc.copyWith(
        title: 'New Title',
        editedText: 'Edited user modifications',
      );

      expect(updated.id, 'doc_456');
      expect(updated.title, 'New Title');
      expect(updated.editedText, 'Edited user modifications');
      expect(updated.rawText, 'Raw transcribed text');
      expect(updated.confidenceScore, 88);
    });
  });

  group('DocumentRetentionPolicy Tests', () {
    test('converts correctly between enum and key strings', () {
      expect(RetentionPolicyExt.fromKey('thirty_days'), DocumentRetentionPolicy.thirtyDays);
      expect(RetentionPolicyExt.fromKey('delete_on_export'), DocumentRetentionPolicy.deleteOnExport);
      expect(RetentionPolicyExt.fromKey('unknown'), DocumentRetentionPolicy.indefinite);

      expect(DocumentRetentionPolicy.indefinite.key, 'indefinite');
      expect(DocumentRetentionPolicy.thirtyDays.key, 'thirty_days');
      expect(DocumentRetentionPolicy.deleteOnExport.key, 'delete_on_export');
    });
  });
}
