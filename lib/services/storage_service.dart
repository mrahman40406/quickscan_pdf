import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_document.dart';

class StorageService {
  static const String _storageKey = 'quickscan_saved_documents';

  /// Retrieves list of saved documents, filtering out any whose files were deleted externally.
  static Future<List<PdfDocument>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    final List<PdfDocument> documents = [];
    for (final jsonStr in jsonList) {
      try {
        final doc = PdfDocument.fromJson(jsonStr);
        final file = File(doc.filePath);
        if (await file.exists()) {
          documents.add(doc);
        }
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return documents;
  }

  /// Saves a newly generated PDF document to history
  static Future<void> saveDocument(PdfDocument doc) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await getDocuments();
    // Insert at beginning for reverse-chronological order
    docs.insert(0, doc);

    final jsonList = docs.map((d) => d.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  /// Deletes a document from history and removes the file from disk
  static Future<void> deleteDocument(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await getDocuments();

    final toRemove = docs.firstWhere((d) => d.id == id, orElse: () => docs.first);
    final file = File(toRemove.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    docs.removeWhere((d) => d.id == id);
    final jsonList = docs.map((d) => d.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  /// Renames a document and its file on disk
  static Future<void> renameDocument(String id, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await getDocuments();

    final index = docs.indexWhere((d) => d.id == id);
    if (index != -1) {
      final oldDoc = docs[index];
      final oldFile = File(oldDoc.filePath);

      final parentDir = oldFile.parent.path;
      final sanitized = newTitle.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final newFilePath = '$parentDir/$sanitized.pdf';

      if (await oldFile.exists()) {
        await oldFile.rename(newFilePath);
      }

      docs[index] = PdfDocument(
        id: oldDoc.id,
        title: newTitle,
        filePath: newFilePath,
        pageCount: oldDoc.pageCount,
        fileSize: oldDoc.fileSize,
        createdAt: oldDoc.createdAt,
        thumbnailPath: oldDoc.thumbnailPath,
      );

      final jsonList = docs.map((d) => d.toJson()).toList();
      await prefs.setStringList(_storageKey, jsonList);
    }
  }
}
