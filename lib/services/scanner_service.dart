import 'dart:developer';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerPermissionException implements Exception {
  final String message;
  final bool isPermanentlyDenied;

  const ScannerPermissionException(
    this.message, {
    this.isPermanentlyDenied = false,
  });

  @override
  String toString() => message;
}

class ScannerService {
  /// Requests camera permission and launches the Document Scanner.
  ///
  /// Supports auto edge detection, perspective correction, and enhancement filters.
  /// Throws [ScannerPermissionException] if camera permission is denied.
  static Future<List<String>?> scanDocuments({
    int maxPages = 50,
    bool allowGalleryImport = true,
  }) async {
    // 1. Explicitly request camera runtime permission
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      throw const ScannerPermissionException(
        'Camera permission is permanently denied. Please allow camera access in App Settings.',
        isPermanentlyDenied: true,
      );
    }
    if (!status.isGranted) {
      throw const ScannerPermissionException(
        'Camera permission is required to scan documents.',
        isPermanentlyDenied: false,
      );
    }

    // 2. Launch Document Scanner
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        scannerSource: allowGalleryImport
            ? ScannerSource.cameraAndGallery
            : ScannerSource.camera,
        androidScannerMode: AndroidScannerMode.full,
      );
      if (pictures != null && pictures.isNotEmpty) {
        return pictures;
      }
      return null;
    } catch (e, stackTrace) {
      log('Scanner error: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Direct fallback to capture a photo using standard device camera
  static Future<List<String>?> captureWithCamera() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      throw const ScannerPermissionException(
        'Camera permission is permanently denied. Please allow camera access in App Settings.',
        isPermanentlyDenied: true,
      );
    }
    if (!status.isGranted) {
      throw const ScannerPermissionException(
        'Camera permission is required to take photos.',
        isPermanentlyDenied: false,
      );
    }

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (photo != null) {
      return [photo.path];
    }
    return null;
  }

  /// Direct import one or more photos from the device gallery
  static Future<List<String>?> pickFromGallery({int maxPages = 50}) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 95,
      limit: maxPages,
    );
    if (images.isNotEmpty) {
      return images.map((img) => img.path).toList();
    }
    return null;
  }
}
