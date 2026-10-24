class ScannedDocument {
  final String id;
  final String title;
  final String rawText;
  final String editedText;
  final String? imagePath;
  final String? thumbnailBase64;
  final String detectedLanguage;
  final int confidenceScore;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScannedDocument({
    required this.id,
    required this.title,
    required this.rawText,
    required this.editedText,
    this.imagePath,
    this.thumbnailBase64,
    required this.detectedLanguage,
    required this.confidenceScore,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
  });

  ScannedDocument copyWith({
    String? id,
    String? title,
    String? rawText,
    String? editedText,
    String? imagePath,
    String? thumbnailBase64,
    String? detectedLanguage,
    int? confidenceScore,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      rawText: rawText ?? this.rawText,
      editedText: editedText ?? this.editedText,
      imagePath: imagePath ?? this.imagePath,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'raw_text': rawText,
      'edited_text': editedText,
      'image_path': imagePath,
      'thumbnail_base64': thumbnailBase64,
      'detected_language': detectedLanguage,
      'confidence_score': confidenceScore,
      'word_count': wordCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    return ScannedDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      rawText: map['raw_text'] as String,
      editedText: map['edited_text'] as String,
      imagePath: map['image_path'] as String?,
      thumbnailBase64: map['thumbnail_base64'] as String?,
      detectedLanguage: map['detected_language'] as String? ?? 'English',
      confidenceScore: map['confidence_score'] as int? ?? 0,
      wordCount: map['word_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
