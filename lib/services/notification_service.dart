import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification helpers for the RTODA Flutter Web admin.
///
/// Firebase service-account credentials are NOT stored in the admin app.
/// Push delivery is handled by the Supabase Edge Function `rapid-handler`.
class NotificationService {
  static final SupabaseClient _db = Supabase.instance.client;

  static String? get currentAdminId => _db.auth.currentUser?.id;

  /// Send a push notification to one user's registered devices.
  static Future<void> sendPush({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    final response = await _db.functions.invoke(
      'rapid-handler',
      body: {
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
      },
    );
    await NotificationService.sendPush(
  userId: userId,
  title: 'Account Approved',
  message: 'Your RTODA account has been approved. You can now log in.',
  type: 'account_approved',
);
await NotificationService.sendPush(
  userId: userId,
  title: 'Account Rejected',
  message: 'Your RTODA account registration has been rejected.',
  type: 'account_rejected',
);

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Notification failed: ${response.data}');
    }
  }

  /// Send to every user with the supplied role.
  /// This requires rapid-handler to accept a `role` recipient.
  static Future<void> sendPushToRole({
    required String role,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    final response = await _db.functions.invoke(
      'rapid-handler',
      body: {
        'role': role,
        'title': title,
        'message': message,
        'type': type,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception('Role notification failed: ${response.data}');
    }
  }

  /// Real-time notifications for the currently logged-in admin.
  static Stream<List<AppNotification>> stream() {
    final adminId = currentAdminId;
    if (adminId == null) return const Stream.empty();

    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', adminId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.map(AppNotification.fromMap).toList(),
        );
  }

  /// Real-time unread count for the currently logged-in admin.
  static Stream<int> unreadCount() {
    final adminId = currentAdminId;
    if (adminId == null) return const Stream.empty();

    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', adminId)
        .map(
          (rows) => rows.where((row) => row['is_read'] != true).length,
        );
  }

  static Future<void> markAsRead(String id) async {
    final adminId = currentAdminId;
    if (adminId == null) return;

    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', adminId);
  }

  static Future<void> markAllAsRead() async {
    final adminId = currentAdminId;
    if (adminId == null) return;

    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', adminId)
        .eq('is_read', false);
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> data) {
    return AppNotification(
      id: '${data['id']}',
      title: '${data['title'] ?? 'Notification'}',
      message: '${data['message'] ?? ''}',
      type: '${data['type'] ?? 'general'}',
      isRead: data['is_read'] == true,
      createdAt: DateTime.tryParse(
        '${data['created_at'] ?? ''}',
      )?.toLocal(),
    );
  }
}
