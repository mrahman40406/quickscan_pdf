import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_document.dart';
import '../services/storage_service.dart';

class PdfPreviewScreen extends StatefulWidget {
  final PdfDocument document;

  const PdfPreviewScreen({super.key, required this.document});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late PdfDocument currentDoc;

  @override
  void initState() {
    super.initState();
    currentDoc = widget.document;
  }

  void _shareDocument() {
    Share.shareXFiles(
      [XFile(currentDoc.filePath)],
      text: 'Document: ${currentDoc.title}',
    );
  }

  void _openInExternalApp() async {
    final result = await OpenFilex.open(currentDoc.filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showRenameDialog() {
    final textController = TextEditingController(text: currentDoc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter new name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                await StorageService.renameDocument(currentDoc.id, newName);
                setState(() {
                  currentDoc.title = newName;
                });
                if (mounted) Navigator.pop(ctx);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentDoc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _showRenameDialog,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareDocument,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open with...',
            onPressed: _openInExternalApp,
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => File(currentDoc.filePath).readAsBytes(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '${currentDoc.title}.pdf',
        previewPageMargin: const EdgeInsets.all(16),
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading PDF preview...'),
            ],
          ),
        ),
      ),
    );
  }
}
