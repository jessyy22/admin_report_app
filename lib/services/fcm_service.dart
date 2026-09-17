<<<<<<< HEAD
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  // PUT YOUR FIREBASE WEB PUSH CERTIFICATE KEY HERE
  static const String vapidKey = 'BLuPu2z89enGsle-jEDTnJpDw9BQ-hXyh85PYKsR5XUI_7k5UY7_dNlD7F95GFy3CUazRO0A4WwL25IGtlq-R3s';
=======
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final SupabaseClient _supabase = Supabase.instance.client;
>>>>>>> 2b2e721582bc328acc2155f64bd974a0c37b9131

  Future<void> initialize() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
<<<<<<< HEAD
      debugPrint('FCM: No logged-in admin.');
      return;
    }

    // Ask browser for notification permission
=======
      debugPrint('FCM: No logged-in user.');
      return;
    }

    // Request notification permission
>>>>>>> 2b2e721582bc328acc2155f64bd974a0c37b9131
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

<<<<<<< HEAD
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
=======
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied.');
      return;
    }

    // Get FCM token
    final token = await _messaging.getToken();

    if (token == null) {
      debugPrint('FCM token is null.');
>>>>>>> 2b2e721582bc328acc2155f64bd974a0c37b9131
      return;
    }

    debugPrint('FCM TOKEN: $token');

<<<<<<< HEAD
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
=======
    // Save token to Supabase
    await _saveToken(userId: user.id, token: token);

    // Listen for token changes
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM TOKEN REFRESHED: $newToken');

      await _saveToken(userId: user.id, token: newToken);
    });
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    String platform;

    if (kIsWeb) {
      platform = 'web';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      platform = 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = 'ios';
    } else {
      platform = 'unknown';
    }

    try {
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,fcm_token');

      debugPrint('FCM token saved successfully.');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }
}
>>>>>>> 2b2e721582bc328acc2155f64bd974a0c37b9131
