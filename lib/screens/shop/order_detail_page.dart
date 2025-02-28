import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/facture_page.dart';
import 'package:happy/services/order_service.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrderService _orderService = OrderService();
  late Future<Orders> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _orderService.getOrder(widget.orderId);
  }

  double safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FutureBuilder<Orders>(
          future: _orderFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const CustomAppBar(title: '', align: Alignment.centerLeft);
            final order = snapshot.data!;

            return CustomAppBar(
              title: 'Commande #${order.id.substring(0, 8)}',
              align: Alignment.center,
              actions: [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.black),
                  onPressed: () => _generateInvoice(order),
                ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<Orders>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState();
          }
          if (!snapshot.hasData) {
            return _buildNotFoundState();
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatusBanner(order),
                const SizedBox(height: 24),
                _buildOrderItems(order),
                const SizedBox(height: 24),
                _buildPickupInfo(order),
                const SizedBox(height: 24),
                _buildOrderSummary(order),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildNavigationFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusBanner(Orders order) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _getStatusColor(order.status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(order.status),
              color: _getStatusColor(order.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statut',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                _getStatusText(order.status),
                style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderItems(Orders order) {
    return _buildSection(
      title: 'Articles commandés',
      icon: Icons.shopping_bag,
      child: Column(
        children: order.items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.image != ''
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.image,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (item.variantAttributes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.variantAttributes.entries
                                      .map((e) => '${e.key}: ${e.value}')
                                      .join(', '),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${item.appliedPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    color:
                                        item.originalPrice != item.appliedPrice
                                            ? Colors.green
                                            : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (item.originalPrice != item.appliedPrice)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      '${item.originalPrice.toStringAsFixed(2)}€',
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Quantité: ${item.quantity}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildPickupInfo(Orders order) {
    return _buildSection(
      title: 'Informations de retrait',
      icon: Icons.location_on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.pickupCode != null) ...[
            Row(
              children: [
                Icon(Icons.qr_code, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code de retrait',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${order.pickupCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adresse',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      order.pickupAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Orders order) {
    return _buildSection(
      title: 'Récapitulatif',
      icon: Icons.receipt_long,
      child: Column(
        children: [
          _buildSummaryRow('Sous-total',
              '${safeParseDouble(order.subtotal).toStringAsFixed(2)}€'),
          if (order.totalDiscount > 0)
            _buildSummaryRow(
              'Réductions sur produits',
              '-${order.totalDiscount.toStringAsFixed(2)}€',
              isDiscount: true,
            ),
          if (order.promoCode != null && order.discountAmount != null)
            _buildSummaryRow(
              'Code promo (${order.promoCode})',
              '-${order.discountAmount!.toStringAsFixed(2)}€',
              isDiscount: true,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          _buildSummaryRow(
            'TVA',
            '${_calculateTotalVAT(order.items).toStringAsFixed(2)}€',
            isBold: true,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Total',
            '${order.totalPrice.toStringAsFixed(2)}€',
            isBold: true,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight:
                  isBold || isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight:
                  isBold || isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : isTotal
                      ? Colors.blue[800]
                      : null,
            ),
          ),
        ],
      ),
    );
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
      case 'paid':
        return Colors.blue;
      case 'en préparation':
        return Colors.orange;
      case 'prête à être retirée':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return "Payée";
      case 'en préparation':
        return "En préparation";
      case 'prête à être retirée':
        return "Prête à être retirée";
      case 'completed':
        return "Terminée";
      default:
        return "Statut inconnus";
    }
  }

  Future<void> _generateInvoice(Orders order) async {
    final pdf = pw.Document();

    // Récupérer les informations de l'entreprise
    final entrepriseDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(order.entrepriseId)
        .get();

    if (!entrepriseDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Impossible de générer la facture : entreprise non trouvée')),
      );
      return;
    }

    final entrepriseData = entrepriseDoc.data()!;

    // Charger la police
    final fontData = await rootBundle.load("assets/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // Télécharger le logo de l'entreprise
    Uint8List? logoBytes;
    try {
      if (entrepriseData['logo'] != null && entrepriseData['logo'].isNotEmpty) {
        final response = await http.get(Uri.parse(entrepriseData['logo']));
        if (response.statusCode == 200) {
          logoBytes = response.bodyBytes;
        }
      }
    } catch (e) {
      print('Erreur lors du chargement du logo: $e');
    }

    // Informations de l'entreprise
    final companyInfo = {
      'name': entrepriseData['name'] ?? '',
      'address':
          '${entrepriseData['adresse'] ?? ''}, ${entrepriseData['code_postal'] ?? ''} ${entrepriseData['ville'] ?? ''}, ${entrepriseData['pays'] ?? ''}',
      'phone': entrepriseData['phone'] ?? '',
      'email': entrepriseData['email'] ?? '',
      'website': entrepriseData['website'] ?? '',
      'siret': entrepriseData['siret'] ?? '',
    };

    // Style de texte
    pw.TextStyle textStyle(
            {double size = 10,
            pw.FontWeight weight = pw.FontWeight.normal,
            PdfColor color = PdfColors.black}) =>
        pw.TextStyle(
            font: ttf, fontSize: size, fontWeight: weight, color: color);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête moderne
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Logo et infos entreprise
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoBytes != null)
                          pw.Container(
                            height: 60,
                            child: pw.Image(pw.MemoryImage(logoBytes)),
                          ),
                        pw.SizedBox(height: 10),
                        pw.Text(companyInfo['name']!,
                            style: textStyle(
                                size: 16, weight: pw.FontWeight.bold)),
                        pw.Text('Tél: ${companyInfo['phone']}',
                            style:
                                textStyle(size: 9, color: PdfColors.grey700)),
                        pw.Text('Email: ${companyInfo['email']}',
                            style:
                                textStyle(size: 9, color: PdfColors.grey700)),
                        pw.Text('SIRET: ${companyInfo['siret']}',
                            style:
                                textStyle(size: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    // Numéro de facture et date
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('FACTURE',
                              style: textStyle(
                                  size: 24,
                                  weight: pw.FontWeight.bold,
                                  color: PdfColors.blue800)),
                          pw.SizedBox(height: 5),
                          pw.Text('N° ${order.id.substring(0, 8)}',
                              style: textStyle(size: 12)),
                          pw.Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}',
                              style: textStyle(size: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),

                // Adresse de retrait
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Adresse de retrait',
                          style: textStyle(weight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text(order.pickupAddress, style: textStyle()),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Tableau des articles avec nouveau design
                _buildModernItemsTable(order, textStyle),
                pw.SizedBox(height: 20),

                // Totaux avec nouveau design
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      child: _buildModernTotalsSection(order, textStyle),
                    ),
                  ],
                ),

                // Pied de page
                pw.Expanded(child: pw.SizedBox()),
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 20),
                  decoration: const pw.BoxDecoration(
                    border:
                        pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Merci de votre confiance !',
                        style: textStyle(color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvoiceViewerPage(
          pdfBytes: pdfBytes,
          invoiceId: order.id.substring(0, 8),
        ),
      ),
    );
  }

  pw.Widget _buildModernItemsTable(
    Orders order,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle,
  ) {
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300),
        bottom: pw.BorderSide(color: PdfColors.grey300),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableHeader('Article', textStyle),
            _buildTableHeader('Variante', textStyle),
            _buildTableHeader('Qté', textStyle),
            _buildTableHeader('Prix unitaire', textStyle),
            _buildTableHeader('TVA', textStyle),
            _buildTableHeader('Total TTC', textStyle),
          ],
        ),
        ...order.items.map((item) {
          final priceHT = item.originalPrice / (1 + (item.tva / 100));
          final priceTTC = item.originalPrice;
          final reduction = item.originalPrice - item.appliedPrice;

          return pw.TableRow(
            children: [
              _buildTableCell(item.name, textStyle),
              _buildTableCell(
                item.variantAttributes.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
                textStyle,
              ),
              _buildTableCell(item.quantity.toString(), textStyle),
              _buildTableCell(
                reduction > 0
                    ? '${priceHT.toStringAsFixed(2)}€\n-${(reduction / (1 + (item.tva / 100))).toStringAsFixed(2)}€'
                    : '${priceHT.toStringAsFixed(2)}€',
                textStyle,
                reduction > 0 ? PdfColors.green : null,
              ),
              _buildTableCell('${item.tva}%', textStyle),
              _buildTableCell(
                reduction > 0
                    ? '${(priceTTC * item.quantity).toStringAsFixed(2)}€\n-${(reduction * item.quantity).toStringAsFixed(2)}€'
                    : '${(priceTTC * item.quantity).toStringAsFixed(2)}€',
                textStyle,
                reduction > 0 ? PdfColors.green : null,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableHeader(
      String text,
      pw.TextStyle Function({
        double size,
        pw.FontWeight weight,
        PdfColor color,
      }) textStyle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: textStyle(weight: pw.FontWeight.bold, color: PdfColors.blue800),
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle, [
    PdfColor? color,
  ]) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: textStyle(color: color ?? PdfColors.black),
      ),
    );
  }

  pw.Widget _buildModernTotalsSection(
    Orders order,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle,
  ) {
    final totalHT = _calculateTotalHT(order.items);
    final totalTVA = _calculateTotalVAT(order.items);

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildTotalRow(
              'Total HT:', '${totalHT.toStringAsFixed(2)}€', textStyle),
          if (order.totalDiscount > 0)
            _buildTotalRow(
              'Réductions:',
              '-${order.totalDiscount.toStringAsFixed(2)}€',
              textStyle,
              PdfColors.green,
            ),
          if (order.discountAmount != null)
            _buildTotalRow(
              'Code promo:',
              '-${order.discountAmount!.toStringAsFixed(2)}€',
              textStyle,
              PdfColors.green,
            ),
          _buildTotalRow('TVA:', '${totalTVA.toStringAsFixed(2)}€', textStyle),
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: _buildTotalRow(
                'Total TTC:',
                '${order.totalPrice.toStringAsFixed(2)}€',
                textStyle,
                PdfColors.blue800,
                true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    String value,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle, [
    PdfColor? color,
    bool isBold = false,
  ]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: textStyle(
                  weight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: textStyle(
                  weight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color ?? PdfColors.black)),
        ],
      ),
    );
  }

  double _calculateTotalHT(List<OrderItem> items) {
    return items.fold(
      0,
      (sum, item) {
        double priceHT = item.originalPrice / (1 + (item.tva / 100));
        return sum + (priceHT * item.quantity);
      },
    );
  }

  double _calculateTotalVAT(List<OrderItem> items) {
    return items.fold(
      0,
      (sum, item) {
        double priceHT = item.originalPrice / (1 + (item.tva / 100));
        double priceTTC = item.originalPrice;
        return sum + ((priceTTC - priceHT) * item.quantity);
      },
    );
  }

  Widget _buildNavigationFAB() {
    return FutureBuilder<Orders>(
      future: _orderFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final order = snapshot.data!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.directions),
            label: const Text("S'y rendre"),
            onPressed: () => MapsLauncher.launchQuery(order.pickupAddress),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Une erreur est survenue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Commande non trouvée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
