import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pdf_document.dart';
import '../services/scanner_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import 'pdf_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfDocument> _allDocuments = [];
  List<PdfDocument> _filteredDocuments = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await StorageService.getDocuments();
    setState(() {
      _allDocuments = docs;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredDocuments = List.from(_allDocuments);
    } else {
      _filteredDocuments = _allDocuments
          .where((doc) =>
              doc.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  Future<void> _processScannedImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final defaultName =
          'Doc_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      final doc = await PdfService.createPdfFromImages(
        imagePaths: imagePaths,
        customTitle: defaultName,
      );

      await StorageService.saveDocument(doc);
      await _loadDocuments();

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PdfPreviewScreen(document: doc),
          ),
        ).then((_) => _loadDocuments());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startScan({bool allowGallery = true}) async {
    try {
      final imagePaths = await ScannerService.scanDocuments(
        maxPages: 50,
        allowGalleryImport: allowGallery,
      );

      if (imagePaths == null || imagePaths.isEmpty) {
        return; // User cancelled
      }

      await _processScannedImages(imagePaths);
    } on ScannerPermissionException catch (e) {
      if (!mounted) return;
      if (e.isPermanentlyDenied) {
        _showPermissionSettingsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Auto document scanner failed on device (e.g. ML Kit / Play Services issue)
      _showScannerFallbackDialog(e.toString());
    }
  }

  Future<void> _captureWithCamera() async {
    try {
      final imagePaths = await ScannerService.captureWithCamera();
      if (imagePaths == null || imagePaths.isEmpty) return;
      await _processScannedImages(imagePaths);
    } on ScannerPermissionException catch (e) {
      if (!mounted) return;
      if (e.isPermanentlyDenied) {
        _showPermissionSettingsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening camera: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final imagePaths = await ScannerService.pickFromGallery();
      if (imagePaths == null || imagePaths.isEmpty) return;
      await _processScannedImages(imagePaths);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting images: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange),
            SizedBox(width: 8),
            Text('Camera Permission'),
          ],
        ),
        content: const Text(
          'Camera permission is required to scan documents and take photos. Please enable Camera access in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showScannerFallbackDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Scanner Options'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The auto document scanner could not launch on this device (Google ML Kit may require Google Play Services or an active internet connection on first run).',
            ),
            SizedBox(height: 12),
            Text(
              'Would you like to take photos with your camera or import images from your gallery to create your PDF?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickFromGallery();
            },
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Gallery'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _captureWithCamera();
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  void _showScanOptionsModal() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Add Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.document_scanner,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: const Text(
                  'Auto Document Scanner',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Auto edge detection, crop & enhance'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startScan();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text(
                  'Standard Camera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Take photos directly with device camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureWithCamera();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade50,
                  child: const Icon(Icons.photo_library, color: Colors.purple),
                ),
                title: const Text(
                  'Import from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Pick existing photos or documents'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(PdfDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.deleteDocument(doc.id);
              _loadDocuments();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(PdfDocument doc) {
    final controller = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await StorageService.renameDocument(doc.id, newName);
                Navigator.pop(ctx);
                _loadDocuments();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QuickScan PDF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Auto Document Scanner',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Import from Gallery',
            onPressed: _isProcessing ? null : _pickFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh list',
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search and banner section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    // Quick Action Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scan Anything Instantly',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Auto edge-detection, perspective crop, and HD PDF creation.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () => _startScan(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: theme.colorScheme.primary,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text(
                                  'Scan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: _isProcessing ? null : _showScanOptionsModal,
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                tooltip: 'Scan options',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search documents...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _applyFilter();
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilter();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Document list section
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredDocuments.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadDocuments,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              itemCount: _filteredDocuments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = _filteredDocuments[index];
                                return _buildDocumentCard(doc);
                              },
                            ),
                          ),
              ),
            ],
          ),

          // Processing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Generating PDF document...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showScanOptionsModal,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan / Import'),
      ),
    );
  }

  Widget _buildDocumentCard(PdfDocument doc) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => PdfPreviewScreen(document: doc),
            ),
          ).then((_) => _loadDocuments());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail / Icon
              Container(
                width: 54,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: doc.thumbnailPath != null &&
                        File(doc.thumbnailPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(
                          File(doc.thumbnailPath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(doc.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          doc.fileSize,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu Options
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'share') {
                    Share.shareXFiles([XFile(doc.filePath)]);
                  } else if (value == 'rename') {
                    _showRenameDialog(doc);
                  } else if (value == 'delete') {
                    _confirmDelete(doc);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No documents yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point your camera at a book, receipt, or paper.\nThe app will auto-detect corners and scan it into PDF!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _startScan(),
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Auto Scan'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickFromGallery(),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
