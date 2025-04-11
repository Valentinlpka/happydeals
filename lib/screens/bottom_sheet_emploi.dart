import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';

class ApplicationBottomSheet extends StatefulWidget {
  final String jobOfferId;
  final String companyId;
  final String jobTitle;
  final Function onApplicationSubmitted;

  const ApplicationBottomSheet({
    super.key,
    required this.jobOfferId,
    required this.companyId,
    required this.jobTitle,
    required this.onApplicationSubmitted,
  });

  @override
  State<ApplicationBottomSheet> createState() => _ApplicationBottomSheetState();
}

class _ApplicationBottomSheetState extends State<ApplicationBottomSheet> {
  String? companyName;
  String? companyLogo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.companyId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          companyName = data['name'] as String?;
          companyLogo = data['logo'] as String?;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue[700],
                  child: CircleAvatar(
                    radius: 23,
                    backgroundImage:
                        companyLogo != null ? NetworkImage(companyLogo!) : null,
                    child: companyLogo == null
                        ? const Icon(Icons.business, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.jobTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        companyName ?? 'Entreprise non trouvée',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              widget.onApplicationSubmitted();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Postuler maintenant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JobSearchProfilePage(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.blue[700]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Compléter mon profil',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
