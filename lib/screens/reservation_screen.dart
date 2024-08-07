import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';

class ReservationScreen extends StatefulWidget {
  final ExpressDeal deal;

  const ReservationScreen({super.key, required this.deal});

  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  String? companyName;
  String? companyAddress;
  bool isLoading = false;

  Future<void> _handlePayment() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      if (widget.deal.basketCount <= 0) {
        throw Exception("Le stock est vide");
      }

      final functions = FirebaseFunctions.instance;
      final result =
          await functions.httpsCallable('createPaymentAndReservation').call({
        'dealId': widget.deal.id,
        'amount': (widget.deal.price * 100).round(),
        'currency': 'eur',
        'isWeb': kIsWeb,
      });

      final clientSecret = result.data['clientSecret'];
      final paymentIntentId = result.data['paymentIntentId'];

      // Initialiser la feuille de paiement
      await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Deals Nord',
      ));

      // Afficher la feuille de paiement
      await Stripe.instance.presentPaymentSheet();

      // Si nous arrivons ici, le paiement a réussi
      print(paymentIntentId);

      await _confirmReservation(paymentIntentId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Une erreur est survenue : $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _confirmReservation(String paymentIntentId) async {
    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('confirmReservation').call({
        'dealId': widget.deal.id,
        'paymentIntentId': paymentIntentId,
      });

      if (result.data['success']) {
        _showReservationSuccessDialog(result.data['validationCode']);
      } else {
        throw Exception("La confirmation de la réservation a échoué");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Erreur lors de la confirmation de la réservation: $e')),
      );
    }
  }

  void _showReservationSuccessDialog(String validationCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réservation réussie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre code de validation est :'),
              const SizedBox(height: 10),
              Text(
                validationCode,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Présentez ce code au commerçant lors du retrait.'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
  }

  Future<void> _fetchCompanyDetails() async {
    try {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.deal.companyId)
          .get();

      if (companyDoc.exists) {
        final data = companyDoc.data() as Map<String, dynamic>;
        setState(() {
          companyName = data['name'] as String?;
          final address = data['adress'] as Map<String, dynamic>?;
          if (address != null) {
            companyAddress =
                '${address['adresse']}, ${address['code_postal']} ${address['ville']}';
          }
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching company details: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.blue[800])),
            onPressed: isLoading ? null : _handlePayment,
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Payer et Réserver'),
          ),
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Réservation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(context),
                      const SizedBox(
                        height: 50,
                      ),
                      _buildTotalSection(context)
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capitalizeFirstLetter(
                companyName ?? "Nom de l'entreprise non disponible"),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.shopping_bag_outlined, widget.deal.basketType),
          const SizedBox(
            height: 10,
          ),
          _buildInfoRow(Icons.access_time,
              'À récupérer le ${DateFormat('dd/MM/yyyy à HH:mm').format(widget.deal.pickupTime)}'),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.location_on, companyAddress ?? 'Adresse non disponible'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${widget.deal.price.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
        ),
      ],
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return SafeArea(
      child: ElevatedButton(
        onPressed: isLoading ? null : _handlePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        child: const Text(
          'Payer',
        ),
      ),
    );
  }
}
