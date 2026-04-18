import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Conditionally import local notifications (not supported on web)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top‑level handler required by FCM for background/terminated messages.
/// Must be a top‑level function (not a class method).
/// Only used on mobile platforms.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Local notifications plugin — only used on mobile
  FlutterLocalNotificationsPlugin? _localNotifications;

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'foundit_notifications', // id
    'FoundIt Notifications', // name
    description: 'Notifications for lost & found items',
    importance: Importance.high,
  );

  /// Call once from main() after Firebase.initializeApp
  Future<void> initialize() async {
    // 1. Request permission (Android 13+ & iOS & Web)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // 2. Setup local notifications (mobile only)
    if (!kIsWeb) {
      _localNotifications = FlutterLocalNotificationsPlugin();

      await _localNotifications!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications!.initialize(initSettings);
    }

    // 3. Handle foreground messages → show local notification (mobile) or just log (web)
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // 4. Subscribe to broadcast topic (mobile only — not supported on web)
    if (!kIsWeb) {
      try {
        await _messaging.subscribeToTopic('all_users');
        debugPrint('[FCM] Subscribed to topic: all_users');
      } catch (e) {
        debugPrint('[FCM] Topic subscription failed (expected on web): $e');
      }
    }
  }

  // ─── Token Management ───────────────────────────────────────────────

  /// Persist the current FCM token to the user's Firestore document.
  /// Call after login / when authState changes to logged-in.
  Future<void> saveTokenForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // On web, getToken() may require a VAPID key — wrap in try/catch
      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
      debugPrint('[FCM] Token saved for ${user.uid}');

      // Listen for future token refreshes
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        debugPrint('[FCM] Token refreshed for ${currentUser.uid}');
      });
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  // ─── Local Notification Display ─────────────────────────────────────

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // On web, local notifications are not supported — FCM handles it natively
    if (kIsWeb || _localNotifications == null) {
      debugPrint('[FCM] Foreground message on web: ${notification.title}');
      return;
    }

    _localNotifications!.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ─── In-App Notification Writer ─────────────────────────────────────

  /// Write a notification document to Firestore so it appears in the
  /// Alerts / Notifications tab for the target user.
  ///
  /// [userId] — the recipient's UID.
  /// [title]  — notification headline.
  /// [body]   — notification detail text.
  /// [type]   — optional category tag (e.g. 'item_reported', 'claim_approved').
  static Future<void> sendInAppNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[Notif] In-app notification sent to $userId: $title');
  }

  /// Convenience: send a notification to every user (except the sender).
  /// Fetches all user UIDs from Firestore once and writes a notification for each.
  static Future<void> broadcastNotification({
    required String title,
    required String body,
    String type = 'general',
    String? excludeUserId,
  }) async {
    final usersSnap =
        await FirebaseFirestore.instance.collection('users').get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in usersSnap.docs) {
      if (doc.id == excludeUserId) continue;
      final ref = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(ref, {
        'userId': doc.id,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    debugPrint('[Notif] Broadcast notification sent: $title');
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Mark a single notification as read.
  static Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark all notifications for the current user as read.
  static Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Stream of unread notification count for the current user.
  static Stream<int> unreadCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
