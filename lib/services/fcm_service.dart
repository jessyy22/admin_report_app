import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // PUT YOUR FIREBASE WEB PUSH CERTIFICATE KEY HERE
  static const String vapidKey = 'BLuPu2z89enGsle-jEDTnJpDw9BQ-hXyh85PYKsR5XUI_7k5UY7_dNlD7F95GFy3CUazRO0A4WwL25IGtlq-R3s';

  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint('FCM: No logged-in admin.');
      return;
    }

    // Ask browser for notification permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'FCM permission: ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.denied) {
      debugPrint('FCM: Notification permission denied.');
      return;
    }

    // Get browser FCM token
    final token = await _messaging.getToken(
      vapidKey: vapidKey,
    );

    if (token == null || token.isEmpty) {
      debugPrint('FCM: No token received.');
      return;
    }

    debugPrint('FCM TOKEN: $token');

    await _saveToken(user.id, token);

    // Keep token updated
    _messaging.onTokenRefresh.listen((newToken) async {
      final currentUser = _supabase.auth.currentUser;

      if (currentUser == null) return;

      await _saveToken(
        currentUser.id,
        newToken,
      );
    });
  }

  Future<void> _saveToken(
    String userId,
    String token,
  ) async {
    await _supabase.from('user_devices').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform': 'web',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,fcm_token',
    );

    debugPrint('FCM token saved to user_devices.');
  }
}