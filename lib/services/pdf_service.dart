import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pdf_document.dart';

class PdfService {
  /// Converts a list of scanned image file paths into a high-quality PDF document.
  static Future<PdfDocument> createPdfFromImages({
    required List<String> imagePaths,
    String? customTitle,
  }) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final imageBytes = await file.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    // Default title format: QuickScan_YYYYMMDD_HHMMSS
    final now = DateTime.now();
    final defaultTitle = 'QuickScan_${DateFormat('yyyyMMdd_HHmmss').format(now)}';
    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : defaultTitle;

    // Get storage directory
    final appDir = await getApplicationDocumentsDirectory();
    final saveDirectory = Directory('${appDir.path}/QuickScanPDF');
    if (!await saveDirectory.exists()) {
      await saveDirectory.create(recursive: true);
    }

    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
    final filePath = '${saveDirectory.path}/$sanitizedTitle.pdf';
    final file = File(filePath);

    // Write PDF bytes
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    // Calculate file size
    final fileSize = _formatBytes(bytes.length);

    return PdfDocument(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      filePath: filePath,
      pageCount: imagePaths.length,
      fileSize: fileSize,
      createdAt: now,
      thumbnailPath: imagePaths.isNotEmpty ? imagePaths.first : null,
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
