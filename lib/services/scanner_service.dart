import 'dart:developer';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

class ScannerService {
  /// Launches the Google ML Kit Document Scanner
  /// Supports auto edge detection, auto-capture, perspective correction, and enhancement filters.
  static Future<List<String>?> scanDocuments({
    int maxPages = 50,
    bool allowGalleryImport = true,
  }) async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        isGalleryImportAllowed: allowGalleryImport,
      );
      if (pictures != null && pictures.isNotEmpty) {
        return pictures;
      }
      return null;
    } catch (e, stackTrace) {
      log('Scanner error: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
