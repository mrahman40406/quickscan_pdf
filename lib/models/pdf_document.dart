import 'dart:convert';

class PdfDocument {
  final String id;
  String title;
  final String filePath;
  final int pageCount;
  final String fileSize;
  final DateTime createdAt;
  final String? thumbnailPath;

  PdfDocument({
    required this.id,
    required this.title,
    required this.filePath,
    required this.pageCount,
    required this.fileSize,
    required this.createdAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'pageCount': pageCount,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'thumbnailPath': thumbnailPath,
    };
  }

  factory PdfDocument.fromMap(Map<String, dynamic> map) {
    return PdfDocument(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled Document',
      filePath: map['filePath'] ?? '',
      pageCount: map['pageCount']?.toInt() ?? 1,
      fileSize: map['fileSize'] ?? '0 KB',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      thumbnailPath: map['thumbnailPath'],
    );
  }

  String toJson() => json.encode(toMap());

  factory PdfDocument.fromJson(String source) =>
      PdfDocument.fromMap(json.decode(source));
}
