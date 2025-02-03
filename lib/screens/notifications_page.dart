import 'package:flutter/material.dart';
import 'package:happy/models/notification_model.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              return NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const NotificationTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red[50],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: Colors.red[400]),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        // Implémenter la suppression de la notification
      },
      child: InkWell(
        onTap: () {
          context.read<NotificationProvider>().markAsRead(notification.id);
          _handleNotificationTap(context);
        },
        child: Container(
          color: notification.isRead ? Colors.transparent : Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        timeago.format(notification.createdAt, locale: 'fr'),
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
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Colors.orange;
      case NotificationType.event:
        return Colors.purple;
      case NotificationType.newFollower:
        return Colors.green;
      case NotificationType.newPost:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Icons.shopping_bag_outlined;
      case NotificationType.event:
        return Icons.event_outlined;
      case NotificationType.newFollower:
        return Icons.person_add_outlined;
      case NotificationType.newPost:
        return Icons.article_outlined;
    }
  }

  void _handleNotificationTap(BuildContext context) {
    if (notification.targetId == null) return;

    switch (notification.type) {
      case NotificationType.order:
        Navigator.pushNamed(context, '/orders/${notification.targetId}');
        break;
      case NotificationType.event:
        Navigator.pushNamed(context, '/events/${notification.targetId}');
        break;
      case NotificationType.newFollower:
        Navigator.pushNamed(context, '/profile/${notification.targetId}');
        break;
      case NotificationType.newPost:
        Navigator.pushNamed(context, '/posts/${notification.targetId}');
        break;
    }
  }
}
