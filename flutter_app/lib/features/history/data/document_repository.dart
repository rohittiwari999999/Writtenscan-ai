import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/scanned_document.dart';

enum DocumentRetentionPolicy {
  indefinite,
  thirtyDays,
  deleteOnExport,
}

extension RetentionPolicyExt on DocumentRetentionPolicy {
  String get displayName {
    switch (this) {
      case DocumentRetentionPolicy.indefinite:
        return 'Keep Indefinitely';
      case DocumentRetentionPolicy.thirtyDays:
        return 'Auto-delete after 30 days';
      case DocumentRetentionPolicy.deleteOnExport:
        return 'Delete after Export';
    }
  }

  String get key {
    switch (this) {
      case DocumentRetentionPolicy.indefinite:
        return 'indefinite';
      case DocumentRetentionPolicy.thirtyDays:
        return 'thirty_days';
      case DocumentRetentionPolicy.deleteOnExport:
        return 'delete_on_export';
    }
  }

  static DocumentRetentionPolicy fromKey(String? key) {
    switch (key) {
      case 'thirty_days':
        return DocumentRetentionPolicy.thirtyDays;
      case 'delete_on_export':
        return DocumentRetentionPolicy.deleteOnExport;
      default:
        return DocumentRetentionPolicy.indefinite;
    }
  }
}

class DocumentRepository {
  static const String _storageKey = 'writescan_documents_v1';
  static const String _retentionKey = 'writescan_retention_policy';

  Future<List<ScannedDocument>> getAllDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> rawList = jsonDecode(jsonString) as List<dynamic>;
      final docs = rawList
          .map((item) => ScannedDocument.fromMap(item as Map<String, dynamic>))
          .toList();

      // Check retention expiry
      final policy = await getRetentionPolicy();
      if (policy == DocumentRetentionPolicy.thirtyDays) {
        final now = DateTime.now();
        final filtered = docs.where((doc) {
          return now.difference(doc.createdAt).inDays <= 30;
        }).toList();
        if (filtered.length != docs.length) {
          await _saveAll(filtered);
          return filtered;
        }
      }

      // Sort newest first
      docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDocument(ScannedDocument doc) async {
    final docs = await getAllDocuments();
    final index = docs.indexWhere((d) => d.id == doc.id);
    if (index >= 0) {
      docs[index] = doc;
    } else {
      docs.insert(0, doc);
    }
    await _saveAll(docs);
  }

  Future<void> deleteDocument(String id) async {
    final docs = await getAllDocuments();
    docs.removeWhere((d) => d.id == id);
    await _saveAll(docs);
  }

  Future<ScannedDocument?> duplicateDocument(String id) async {
    final docs = await getAllDocuments();
    final matchIndex = docs.indexWhere((d) => d.id == id);
    if (matchIndex < 0) return null;

    final orig = docs[matchIndex];
    final dup = orig.copyWith(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: '${orig.title} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    docs.insert(0, dup);
    await _saveAll(docs);
    return dup;
  }

  Future<List<ScannedDocument>> searchDocuments(String query) async {
    final docs = await getAllDocuments();
    if (query.trim().isEmpty) return docs;
    final lower = query.toLowerCase();
    return docs.where((d) {
      return d.title.toLowerCase().contains(lower) ||
          d.editedText.toLowerCase().contains(lower) ||
          d.detectedLanguage.toLowerCase().contains(lower);
    }).toList();
  }

  Future<DocumentRetentionPolicy> getRetentionPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_retentionKey);
    return RetentionPolicyExt.fromKey(key);
  }

  Future<void> setRetentionPolicy(DocumentRetentionPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_retentionKey, policy.key);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveAll(List<ScannedDocument> docs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = docs.map((d) => d.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}

// Global Riverpod Providers for Document Repository & State
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

class DocumentListNotifier extends StateNotifier<AsyncValue<List<ScannedDocument>>> {
  final DocumentRepository _repo;

  DocumentListNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAllDocuments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(ScannedDocument doc) async {
    await _repo.saveDocument(doc);
    await loadDocuments();
  }

  Future<void> delete(String id) async {
    await _repo.deleteDocument(id);
    await loadDocuments();
  }

  Future<void> duplicate(String id) async {
    await _repo.duplicateDocument(id);
    await loadDocuments();
  }

  Future<void> search(String query) async {
    try {
      final filtered = await _repo.searchDocuments(query);
      state = AsyncValue.data(filtered);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final documentListProvider =
    StateNotifierProvider<DocumentListNotifier, AsyncValue<List<ScannedDocument>>>((ref) {
  final repo = ref.watch(documentRepositoryProvider);
  return DocumentListNotifier(repo);
});
