import 'package:flutter/material.dart';
import 'services/notification_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.unreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => _openNotifications(context),
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 27,
                color: Color(0xff333333),
              ),
            ),

            // Unread badge
            if (count > 0)
              Positioned(
                right: 2,
                top: 1,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OPEN ALL NOTIFICATIONS
  // ============================================================

  void _openNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 460,
            height: 600,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    10,
                    12,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'All Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      TextButton(
                        onPressed: () async {
                          try {
                            await NotificationService.markAllAsRead();
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to mark notifications as read: $e',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Mark all as read'),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Notification list
                Expanded(
                  child: StreamBuilder<List<AppNotification>>(
                    stream: NotificationService.stream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Unable to load notifications.\n\n'
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }

                      final notifications = snapshot.data ?? [];

                      if (notifications.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          return _notificationCard(
                            context,
                            notifications[index],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationCard(
    BuildContext context,
    AppNotification notification,
  ) {
    return InkWell(
      onTap: () async {
        // Mark notification as read
        if (!notification.isRead) {
          try {
            await NotificationService.markAsRead(
              notification.id,
            );
          } catch (e) {
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unable to update notification: $e',
                ),
              ),
            );

            return;
          }
        }

        if (!context.mounted) return;

        // Show notification details
        _showNotificationDetails(
          context,
          notification,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white
              : const Color(0xffEAF7EF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? Colors.grey.shade200
                : const Color(0xffB7DFC5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getColor(notification.type).withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(notification.type),
                color: _getColor(notification.type),
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            // Notification text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w500
                          : FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Unread dot
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(
                  top: 5,
                  left: 6,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xff079447),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetails(
    BuildContext context,
    AppNotification notification,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getColor(notification.type)
                              .withOpacity(.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIcon(notification.type),
                          color: _getColor(notification.type),
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const Divider(),

                  const SizedBox(height: 18),

                  // Notification label
                  const Text(
                    'NOTIFICATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Full notification message
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notification type
                  Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Type: ${notification.type}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Notification time
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff079447),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'report':
      case 'new_report':
        return Icons.receipt_long_rounded;

      case 'sos':
        return Icons.warning_rounded;

      case 'driver':
      case 'account':
      case 'account_approved':
      case 'account_rejected':
      case 'registration':
      case 'user':
        return Icons.person_rounded;

      case 'operator':
        return Icons.badge_rounded;

      case 'tricycle':
        return Icons.electric_rickshaw_rounded;

      case 'complaint':
        return Icons.report_problem_rounded;

      case 'violation':
        return Icons.warning_rounded;

      case 'fare':
        return Icons.price_change_rounded;

      case 'announcement':
        return Icons.campaign_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  // ============================================================
  // NOTIFICATION COLOR
  // ============================================================

  Color _getColor(String type) {
    switch (type.toLowerCase()) {
      case 'report':
      case 'new_report':
        return Colors.blue;

      case 'sos':
        return Colors.red;

      case 'driver':
      case 'account':
      case 'account_approved':
      case 'registration':
        return Colors.blue;

      case 'account_rejected':
        return Colors.red;

      case 'operator':
        return Colors.orange;

      case 'tricycle':
        return Colors.green;

      case 'complaint':
      case 'violation':
        return Colors.red;

      case 'user':
        return Colors.purple;

      case 'fare':
        return Colors.teal;

      case 'announcement':
        return Colors.indigo;

      default:
        return const Color(0xff005C2A);
    }
  }

  // ============================================================
  // TIME AGO
  // ============================================================

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Just now';

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.month}/${date.day}/${date.year}';
  }
}

