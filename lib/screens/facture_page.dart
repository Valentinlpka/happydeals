import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class InvoiceViewerPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String invoiceId;

  const InvoiceViewerPage(
      {super.key, required this.pdfBytes, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Facture #$invoiceId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _savePDF(context),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printPDF(context),
          ),
        ],
      ),
      body: SfPdfViewer.memory(pdfBytes),
    );
  }

  Future<void> _savePDF(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/facture_$invoiceId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      final xFile = XFile(filePath, mimeType: 'application/pdf');
      await Share.shareXFiles(
        [xFile],
        text: 'Facture #$invoiceId',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture partagée avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du partage: $e')),
      );
    }
  }

  Future<void> _printPDF(BuildContext context) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Facture #$invoiceId',
    );
  }
}
