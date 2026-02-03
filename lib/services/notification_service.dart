import 'dart:io';

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
      print('🔔 Starting notification service initialization...');
      
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      print('📱 FCM Permission Status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@drawable/ic_notification');
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
        print('✅ Local notifications plugin initialized');

        // Create Android notification channel with HIGH importance
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'pickup_channel',
          'Pickup Notifications',
          description: 'Notifications for pickup status updates',
          importance: Importance.max, // Changed to max for better visibility
          playSound: true,
          enableVibration: true,
          showBadge: true,
          enableLights: true,
          ledColor: Color(0xFF3B82F6),
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(channel);
          print('✅ Notification channel created: pickup_channel');
          
          // Request notification permission on Android 13+ (required for notifications to show)
          if (Platform.isAndroid) {
            final permissionGranted = await androidPlugin.requestNotificationsPermission();
            print('📱 Android notification permission: $permissionGranted');
          }
        }

        // Get and log FCM token (critical for debugging)
        // NOTE: On iOS simulator, this will fail because APNS tokens are not available
        String? token;
        try {
          token = await _messaging.getToken();
          if (token != null) {
            print('🔑 FCM Token: ${token.substring(0, 20)}...');
            print('✅ FCM token obtained successfully');
          } else {
            print('⚠️ FCM token is null - notifications may not work!');
          }
        } catch (e) {
          print('⚠️ Failed to get FCM token (iOS simulator doesn\'t support push notifications): $e');
          // Continue initialization - app can still work without notifications
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
          // Re-save token to Firestore if user is signed in
          if (_currentParentId != null) {
            saveTokenToFirestore(_currentParentId!);
          }
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        print('✅ Foreground message handler registered');

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
        print('✅ Background message handler registered');

        // Check if app was opened from a notification
        RemoteMessage? initialMessage =
            await _messaging.getInitialMessage();
        if (initialMessage != null) {
          print('📨 App opened from notification');
          _handleBackgroundMessage(initialMessage);
        }

        _initialized = true;
        print('✅ Notification service initialized successfully');
        
        // Test notification on initialization (helps verify setup)
        await _showTestNotification();
      } else {
        print('⚠️ Notification permission denied: ${settings.authorizationStatus}');
      }
    } catch (e, stackTrace) {
      print('❌ Notification service initialization error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Show a test notification to verify the setup works
  Future<void> _showTestNotification() async {
    try {
      await _showLocalNotification(
        title: 'LineMeUp Notifications',
        body: 'Notifications are set up and ready!',
      );
      print('✅ Test notification sent');
    } catch (e) {
      print('⚠️ Failed to send test notification: $e');
    }
  }

  void setStatusChangeCallback(PickupStateCallback? callback) {
    _onStatusChange = callback;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message received');
    print('  Title: ${message.notification?.title}');
    print('  Body: ${message.notification?.body}');
    print('  Data: ${message.data}');
    
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
      String? token;
      
      try {
        token = await _messaging.getToken();
        print('🔑 Attempting to save FCM token for parent: $parentId');
        
        if (token == null) {
          print('⚠️ FCM token is null, retrying...');
          // Sometimes token takes time to generate, especially on first launch
          await Future.delayed(const Duration(seconds: 2));
          token = await _messaging.getToken();
        }
      } catch (e) {
        print('⚠️ Cannot get FCM token (iOS simulator doesn\'t support push): $e');
        // Continue without token - app still works, just no notifications
        return;
      }
      
      if (token != null && parentId.isNotEmpty) {
        _currentParentId = parentId;
        print('🔑 FCM Token: ${token.substring(0, 30)}...');
        
        await _firestore.collection('parents').doc(parentId).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        });
        print('✅ FCM token saved successfully for parent: $parentId');
      } else {
        print('⚠️ FCM token is null or parentId is empty - skipping token save');
      }
    } catch (e, stackTrace) {
      print('❌ Error saving FCM token: $e');
      print('Stack trace: $stackTrace');
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
      print('⚠️ Cannot get FCM token (iOS simulator doesn\'t support push): $e');
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

  /// Check if notifications are enabled (for debugging)
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          print('📱 Android notifications enabled: $enabled');
          return enabled ?? false;
        }
      }
      
      final settings = await _messaging.getNotificationSettings();
      final enabled = settings.authorizationStatus == AuthorizationStatus.authorized;
      print('📱 FCM notifications authorized: $enabled');
      return enabled;
    } catch (e) {
      print('❌ Error checking notification status: $e');
      return false;
    }
  }

  /// Get detailed notification status (for debugging)
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      final token = await _messaging.getToken();
      
      bool androidEnabled = false;
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        androidEnabled = await androidPlugin?.areNotificationsEnabled() ?? false;
      }
      
      return {
        'initialized': _initialized,
        'fcmToken': token != null ? '${token.substring(0, 20)}...' : 'null',
        'fcmTokenFull': token,
        'authorizationStatus': settings.authorizationStatus.toString(),
        'androidNotificationsEnabled': androidEnabled,
        'alertSetting': settings.alert.toString(),
        'badgeSetting': settings.badge.toString(),
        'soundSetting': settings.sound.toString(),
        'currentParentId': _currentParentId,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

// Top-level function for background message handling
// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message handler triggered');
  print('  Title: ${message.notification?.title}');
  print('  Body: ${message.notification?.body}');
  print('  Data: ${message.data}');
  
  // Background messages are handled by Firebase automatically
  // The notification will be shown by the system using the metadata from AndroidManifest.xml
}
