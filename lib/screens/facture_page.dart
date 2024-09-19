import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:universal_html/html.dart' as html;

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
      if (kIsWeb) {
        // Pour le web, utilisez le téléchargement direct
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'facture_$invoiceId.pdf';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        // Pour les plateformes mobiles, utilisez le code existant
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/facture_$invoiceId.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        final xFile = XFile(filePath, mimeType: 'application/pdf');
        await Share.shareXFiles(
          [xFile],
          text: 'Facture #$invoiceId',
        );
      }

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
