import 'package:flutter/material.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/models/notification_model.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialisation de timeago en français
    timeago.setLocaleMessages('fr', timeago.FrMessages());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.hasUnreadNotifications) {
                return TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  child: const Text('Tout marquer comme lu'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        align: Alignment.center,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          if (notificationProvider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notificationProvider.notifications.length,
            itemBuilder: (context, index) {
              final notification = notificationProvider.notifications[index];
              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red[50],
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Supprimer',
                        style: TextStyle(
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Supprimer la notification'),
                        content: const Text(
                            'Êtes-vous sûr de vouloir supprimer cette notification ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Supprimer'),
                          ),
                        ],
                      );
                    },
                  );
                  return result ?? false;
                },
                onDismissed: (direction) {
                  notificationProvider.deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification supprimée'),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () {},
                      ),
                    ),
                  );
                },
                child: InkWell(
                  onTap: () {
                    notificationProvider.markAsRead(notification.id);
                    _handleNotificationTap(context, notification);
                  },
                  child: Container(
                    color: notification.isRead
                        ? Colors.transparent
                        : Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(notification.type),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(notification.createdAt,
                                      locale: 'fr'),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 8, left: 8),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Colors.orange;
      case NotificationType.dealExpress:
        return Colors.green;
      case NotificationType.booking:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Icons.shopping_bag_outlined;
      case NotificationType.dealExpress:
        return Icons.eco_outlined;
      case NotificationType.booking:
        return Icons.event_outlined;
    }
  }

  void _handleNotificationTap(
      BuildContext context, NotificationModel notification) {
    if (notification.targetId == null) return;

    switch (notification.type) {
      case NotificationType.order:
        AppRouter.navigateTo(context, AppRouter.orderDetails,
            arguments: notification.targetId);
        break;
      case NotificationType.dealExpress:
        AppRouter.navigateTo(context, AppRouter.reservationDetails,
            arguments: notification.targetId);
        break;
      case NotificationType.booking:
        AppRouter.navigateTo(context, AppRouter.bookingDetails,
            arguments: notification.targetId);
        break;
    }
  }
}
