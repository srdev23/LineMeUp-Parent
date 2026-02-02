import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Callback type for status change notifications
typedef PickupStateCallback = void Function(String title, String body);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _currentParentId;
  PickupStateCallback? _onStatusChange;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings iosSettings =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // Create Android notification channel
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'pickup_channel',
          'Pickup Notifications',
          description: 'Notifications for pickup status updates',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

        // Check if app was opened from a notification
        RemoteMessage? initialMessage =
            await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleBackgroundMessage(initialMessage);
        }

        _initialized = true;
        print('✅ Notification service initialized successfully');
      } else {
        print('⚠️ Notification permission denied');
      }
    } catch (e) {
      print('❌ Notification service initialization error: $e');
    }
  }

  void setStatusChangeCallback(PickupStateCallback? callback) {
    _onStatusChange = callback;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message received: ${message.notification?.title}');
    // Show local notification when app is in foreground
    // Use Firebase notification data or fallback to local notification
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Pickup Update',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    } else if (message.data.isNotEmpty) {
      // Handle data-only messages
      _showLocalNotification(
        title: message.data['title'] ?? 'Pickup Update',
        body: message.data['body'] ?? '',
        payload: message.data.toString(),
      );
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('📨 Background message received: ${message.notification?.title}');
    // Handle notification tap when app is in background
    // The navigation will be handled by the app when it opens
    if (_onStatusChange != null) {
      _onStatusChange!(
        message.notification?.title ?? 'Pickup Update',
        message.notification?.body ?? '',
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    // Handle notification tap
    // Navigation will be handled by the app state
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Android notification icon must be white/transparent (monochrome)
    // The small icon (icon parameter) must be white/transparent
    // The large icon can be colored and will show in expanded notification
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pickup_channel',
      'Pickup Notifications',
      channelDescription: 'Notifications for pickup status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@drawable/ic_notification', // Small icon - MUST be white/transparent
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Large icon - can be colored
      color: Color(0xFF3B82F6), // Tint color for the small icon
      colorized: true, // Enable color tinting
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show notification for status changes
  Future<void> showStatusNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    await _showLocalNotification(title: title, body: body);
  }

  // Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String parentId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null && parentId.isNotEmpty) {
        _currentParentId = parentId;
        await _firestore.collection('parents').doc(parentId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved for parent: $parentId');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // Remove FCM token from Firestore
  Future<void> removeTokenFromFirestore() async {
    try {
      if (_currentParentId != null && _currentParentId!.isNotEmpty) {
        await _firestore.collection('parents').doc(_currentParentId).update({
          'fcmToken': FieldValue.delete(),
        });
        _currentParentId = null;
        print('✅ FCM token removed');
      }
    } catch (e) {
      print('❌ Error removing FCM token: $e');
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message handler: ${message.notification?.title}');
  // Background messages are handled by Firebase automatically
  // Local notifications will be shown by the system
}
