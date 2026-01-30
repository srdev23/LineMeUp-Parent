import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/pickup_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

// Background message handler - defined in notification_service.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ Make sure google-services.json (Android) or GoogleService-Info.plist (iOS) is properly configured');
  }
  
  try {
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    print('⚠️ Notification service initialization failed: $e');
  }
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => PickupProvider()),
      ],
      child: MaterialApp(
        title: 'LineMeUp',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
