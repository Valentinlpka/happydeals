import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/facture_page.dart';
import 'package:happy/services/order_service.dart';
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
    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Colors.grey[300],
              height: 1.0,
            ),
          ),
          title: const Text(
            'Détail de la commande',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: FutureBuilder<Orders>(
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
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderHeader(order),
                      _buildOrderStatus(order),
                      _buildPickupCode(order),
                      _buildPickupInfo(order),
                      _buildOrderItems(order),
                      _buildOrderSummary(order),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
            ),
          ),
        ),
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
              if (isSmallScreen || !kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Facture'),
                    onPressed: () => _generateInvoice(order),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue[800],
                    ),
                  ),
                )
            ],
          ),
          if (!isSmallScreen && kIsWeb)
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

  Widget _buildOrderItems(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Articles',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
                              child: Image.network(item.image),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Quantité: ${item.quantity}'),
                          if (item.variantAttributes.isNotEmpty)
                            Text(
                              item.variantAttributes.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', '),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          if (item.originalPrice != item.appliedPrice)
                            Text(
                              '${item.originalPrice.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          Text(
                            '${item.appliedPrice.toStringAsFixed(2)}€',
                            style: TextStyle(
                              color: item.originalPrice != item.appliedPrice
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          Text(
                            'Total: ${(item.appliedPrice * item.quantity).toStringAsFixed(2)}€',
                          ),
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

  Widget _buildOrderStatus(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statut de la commande',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _getStatusIcon(order.status),
                color: _getStatusColor(order.status),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(order.status),
                style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildPickupInfo(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations de retrait',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
                const Text(
                  'Code de retrait',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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

  Widget _buildOrderSummary(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récapitulatif',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total'),
              Text('${safeParseDouble(order.subtotal).toStringAsFixed(2)}€'),
            ],
          ),
          if (order.totalDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Réductions sur produits',
                    style: TextStyle(color: Colors.green)),
                Text(
                  '-${order.totalDiscount.toStringAsFixed(2)}€',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ],
          if (order.promoCode != null && order.discountAmount != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Code promo (${order.promoCode})'),
                Text('-${order.discountAmount!.toStringAsFixed(2)}€'),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TVA', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '${_calculateTotalVAT(order.items).toStringAsFixed(2)}€',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${order.totalPrice.toStringAsFixed(2)}€',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
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
      case 'payée':
        return "Payée";
      case 'en préparation':
        return "En préparation";
      case 'prête à être retirée':
        return "Prête à être retirée";
      case 'terminée':
        return "Terminée";
      default:
        return "Statut inconnu";
    }
  }

  double _calculateTotalHT(List<OrderItem> items) {
    return items.fold(
      0,
      (sum, item) =>
          sum + (item.appliedPrice / (1 + (item.tva / 100))) * item.quantity,
    );
  }

  double _calculateTotalVAT(List<OrderItem> items) {
    return items.fold(
      0,
      (sum, item) {
        double prixHT = item.appliedPrice / (1 + (item.tva / 100));
        return sum + ((item.appliedPrice - prixHT) * item.quantity);
      },
    );
  }

  Future<void> _generateInvoice(Orders order) async {
    final pdf = pw.Document();

    // Charger le logo
    final ByteData logoData = await rootBundle.load('assets/mon_logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    // Charger la police
    final fontData = await rootBundle.load("assets/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    // Informations de la société
    final companyInfo = {
      'name': 'Votre Société',
      'address': '123 Rue Principale, 75000 Paris',
      'phone': '+33 1 23 45 67 89',
      'email': 'contact@votresociete.com',
      'website': 'www.votresociete.com',
      'siret': '123 456 789 00012',
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
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(pw.MemoryImage(logoBytes), width: 100),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE',
                          style:
                              textStyle(size: 24, weight: pw.FontWeight.bold)),
                      pw.Text('N° ${order.id.substring(0, 8)}',
                          style: textStyle()),
                      pw.Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}',
                          style: textStyle()),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Infos société
              _buildCompanyInfoSection(companyInfo, textStyle),
              pw.SizedBox(height: 20),

              // Adresse de retrait
              pw.Text('Adresse de retrait:',
                  style: textStyle(weight: pw.FontWeight.bold)),
              pw.Text(order.pickupAddress, style: textStyle()),
              pw.SizedBox(height: 20),

              // Tableau des articles
              _buildItemsTable(order, textStyle),
              pw.SizedBox(height: 20),

              // Totaux
              _buildTotalsSection(order, textStyle),
            ],
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

  pw.Widget _buildCompanyInfoSection(
    Map<String, String> companyInfo,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: companyInfo.entries.map((entry) {
          return pw.Text(
            '${entry.key == 'name' ? '' : '${entry.key}: '}${entry.value}',
            style: entry.key == 'name'
                ? textStyle(weight: pw.FontWeight.bold)
                : textStyle(),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildItemsTable(
    Orders order,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Article', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell('Variante', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell('Quantité', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell(
                'Prix unitaire HT', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell('TVA', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell(
                'Prix unitaire TTC', textStyle(weight: pw.FontWeight.bold)),
            _buildTableCell('Total TTC', textStyle(weight: pw.FontWeight.bold)),
          ],
        ),
        ...order.items.map((item) {
          final priceHT = item.appliedPrice / (1 + (item.tva / 100));
          return pw.TableRow(
            children: [
              _buildTableCell(item.name, textStyle()),
              _buildTableCell(
                item.variantAttributes.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
                textStyle(),
              ),
              _buildTableCell(item.quantity.toString(), textStyle()),
              _buildTableCell('${priceHT.toStringAsFixed(2)}€', textStyle()),
              _buildTableCell('${item.tva}%', textStyle()),
              _buildTableCell(
                  '${item.appliedPrice.toStringAsFixed(2)}€', textStyle()),
              _buildTableCell(
                '${(item.appliedPrice * item.quantity).toStringAsFixed(2)}€',
                textStyle(),
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: style),
    );
  }

  pw.Widget _buildTotalsSection(
    Orders order,
    pw.TextStyle Function({
      double size,
      pw.FontWeight weight,
      PdfColor color,
    }) textStyle,
  ) {
    final totalHT = _calculateTotalHT(order.items);
    final totalTVA = _calculateTotalVAT(order.items);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('Total HT: ${totalHT.toStringAsFixed(2)}€', style: textStyle()),
        if (order.totalDiscount > 0)
          pw.Text(
            'Réductions: -${order.totalDiscount.toStringAsFixed(2)}€',
            style: textStyle(color: PdfColors.green),
          ),
        if (order.discountAmount != null)
          pw.Text(
            'Code promo: -${order.discountAmount!.toStringAsFixed(2)}€',
            style: textStyle(color: PdfColors.green),
          ),
        pw.Text(
          'Total TVA: ${totalTVA.toStringAsFixed(2)}€',
          style: textStyle(),
        ),
        pw.Divider(color: PdfColors.black),
        pw.Text(
          'Total TTC: ${order.totalPrice.toStringAsFixed(2)}€',
          style: textStyle(weight: pw.FontWeight.bold, size: 12),
        ),
      ],
    );
  }
}
