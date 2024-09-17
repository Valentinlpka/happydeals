import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/services/order_service.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrderService _orderService = OrderService();
  late Future<Orders> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _orderService.getOrder(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: FutureBuilder<Orders>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildBottomBar(snapshot.data!);
          }
          return const SizedBox.shrink();
        },
      ),
      appBar: AppBar(
        title: const Text('Détails de la commande',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Orders>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Commande non trouvée'));
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(order),
                  const SizedBox(height: 24),
                  _buildOrderStatus(order),
                  const SizedBox(height: 24),
                  _buildPickupCode(order),
                  const SizedBox(height: 24),
                  _buildPickupInfo(order),
                  const SizedBox(height: 24),
                  _buildOrderItems(order),
                  const SizedBox(height: 24),
                  _buildOrderSummary(order),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(Orders order) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
          width: 0.4,
          color: Colors.black26,
        ))),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.blue[800]),
              ),
              onPressed: () async {
                await MapsLauncher.launchQuery(order.pickupAddress);
              },
              child: const Text("S'y rendre"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #${order.id.substring(0, 8)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Passée le ${DateFormat('dd/MM/yyyy à HH:mm').format(order.createdAt)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Facture'),
            onPressed: () => _generateInvoice(order),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateInvoice(Orders order) async {
    final pdf = pw.Document();

    // Chargez votre logo
    final ByteData logoData = await rootBundle.load('assets/mon_logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    // Chargez la police personnalisée
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(pw.MemoryImage(logoBytes), width: 100),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE',
                          style: pw.TextStyle(
                              font: ttf,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Commande #${order.id.substring(0, 8)}',
                          style: pw.TextStyle(font: ttf)),
                      pw.Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}',
                          style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Adresse de retrait:',
                  style:
                      pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
              pw.Text(order.pickupAddress, style: pw.TextStyle(font: ttf)),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Article', ttf, isHeader: true),
                      _buildTableCell('Quantité', ttf, isHeader: true),
                      _buildTableCell('Prix unitaire HT', ttf, isHeader: true),
                      _buildTableCell('Total HT', ttf, isHeader: true),
                    ],
                  ),
                  ...order.items.map((item) {
                    final priceHT =
                        item.price / 1.2; // Supposons une TVA de 20%
                    return pw.TableRow(
                      children: [
                        _buildTableCell(item.name, ttf),
                        _buildTableCell(item.quantity.toString(), ttf),
                        _buildTableCell('${priceHT.toStringAsFixed(2)}€', ttf),
                        _buildTableCell(
                            '${(priceHT * item.quantity).toStringAsFixed(2)}€',
                            ttf),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Total HT: ${(order.totalPrice / 1.2).toStringAsFixed(2)}€',
                          style: pw.TextStyle(font: ttf)),
                      pw.Text(
                          'TVA (20%): ${(order.totalPrice - (order.totalPrice / 1.2)).toStringAsFixed(2)}€',
                          style: pw.TextStyle(font: ttf)),
                      pw.Text(
                          'Total TTC: ${order.totalPrice.toStringAsFixed(2)}€',
                          style: pw.TextStyle(
                              font: ttf, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();

    if (kIsWeb) {
      // Pour le web
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, "_blank");
      html.Url.revokeObjectUrl(url);
    } else {
      // Pour mobile
      final output = await getTemporaryDirectory();
      final file =
          File('${output.path}/facture_${order.id.substring(0, 8)}.pdf');
      await file.writeAsBytes(pdfBytes);
      OpenFile.open(file.path);
    }
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderStatus(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statut de la commande',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_getStatusIcon(order.status),
                  color: _getStatusColor(order.status)),
              const SizedBox(width: 8),
              Text(
                _getStatusText(order.status),
                style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (order.status == 'en préparation') ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(value: 0.5),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItems(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Articles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        color:
                            item.image != '' ? Colors.white : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.image != ''
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CachedNetworkImage(imageUrl: item.image),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Quantité: ${item.quantity}'),
                          Text(
                              '${(item.price * item.quantity).toStringAsFixed(2)}€'),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total'),
              Text('${order.totalPrice.toStringAsFixed(2)}€'),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Frais de livraison'),
              Text('0.00€'),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${order.totalPrice.toStringAsFixed(2)}€',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupInfo(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations de retrait',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Adresse: ${order.pickupAddress}'),
        ],
      ),
    );
  }

  Widget _buildPickupCode(Orders order) {
    return order.pickupCode != null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Code de retrait',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${order.pickupCode}',
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox();
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'payée':
        return Icons.payment;
      case 'en préparation':
        return Icons.inventory;
      case 'prête à être retirée':
        return Icons.store;
      case 'terminée':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'payée':
        return Colors.blue;
      case 'en préparation':
        return Colors.orange;
      case 'prête à être retirée':
        return Colors.green;
      case 'terminée':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return "Payé";

      case 'en préparation':
        return "En préparation";
      case 'prête à être retirée':
        return "Prête à être retirée";
      case 'terminée':
        return "Terminée";
      default:
        return "Default";
    }
  }
}
