import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/goup_chat_search_screen.dart';

class CompanyMessageBottomSheet extends StatelessWidget {
  final Company company;
  final String currentUserId;

  const CompanyMessageBottomSheet({
    super.key,
    required this.company,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Nouvelle conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          _buildOption(
            context: context,
            icon: Icons.person_outline,
            title: 'Message privé',
            subtitle: 'Démarrer une conversation avec ${company.name}',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationDetailScreen(
                    otherUserName: company.name,
                    otherUserId: company.id, // ID de l'entreprise
                    isNewConversation:
                        true, // Important pour indiquer nouvelle conversation
                    conversationId: '', // ID vide car pas encore créée
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildOption(
            context: context,
            icon: Icons.group_outlined,
            title: 'Créer un groupe',
            subtitle:
                'Créer un groupe avec ${company.name} et d\'autres participants',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatSearchScreen(
                    preselectedCompany: company,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(26 * 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
