import 'package:flutter/material.dart';
import 'package:happy/models/notification_model.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class TestNotificationPage extends StatelessWidget {
  const TestNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Test Notification',
        align: Alignment.center,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            final notificationProvider =
                Provider.of<NotificationProvider>(context, listen: false);

            notificationProvider.addNotification(
              title: 'Commande terminée',
              message: 'Votre commande est maintenant terminée',
              type: NotificationType.order,
              targetId: 'LhmtGdErhMLtnDV2Y4yD',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification de test envoyée !'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Envoyer une notification de test'),
        ),
      ),
    );
  }
}
