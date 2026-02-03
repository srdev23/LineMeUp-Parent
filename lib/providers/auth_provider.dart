import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/parent.dart';

/// Clean, simple auth provider with NO race conditions
/// Design principles:
/// 1. Auth state listener is PASSIVE - only clears state, never makes decisions
/// 2. All sign-in logic is centralized in signInWithOTP
/// 3. No complex coordination flags
/// 4. Clear error handling
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  // Simple state
  Parent? _currentParent;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;
  Timer? _verifyTimeoutTimer;
  
  // Getters
  Parent? get currentParent => _currentParent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentParent != null;
  String? get verificationId => _verificationId;

  AuthProvider() {
    _initAuthListener();
  }

  /// PASSIVE auth state listener - only clears state when user signs out
  /// Does NOT try to verify, sign out, or make any decisions
  void _initAuthListener() {
    _authService.authStateChanges.listen((user) {
      print('🔔 Auth state changed: user=${user != null ? "signed in" : "null"}');
      
      // Only clear state when user signs out
      // Don't do anything else to avoid race conditions
      if (user == null && _currentParent != null) {
        print('👤 User signed out, clearing parent state');
        _currentParent = null;
        notifyListeners();
      }
    });
  }

  /// Request OTP code
  Future<void> verifyPhoneNumber(String phoneNumber) async {
    _verifyTimeoutTimer?.cancel();
    
    _isLoading = true;
    _errorMessage = null;
    _verificationId = null;
    notifyListeners();

    // Safety timeout
    bool timedOut = false;
    _verifyTimeoutTimer = Timer(const Duration(seconds: 65), () {
      if (_verificationId == null && !timedOut) {
        timedOut = true;
        _isLoading = false;
        _errorMessage = 'Request timed out. Please try again.';
        notifyListeners();
      }
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        _verifyTimeoutTimer?.cancel();
        if (!timedOut) {
          print('✅ Verification code sent');
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        }
      },
      onError: (error) {
        _verifyTimeoutTimer?.cancel();
        if (!timedOut) {
          print('❌ Verification failed: $error');
          _isLoading = false;
          _errorMessage = error;
          _verificationId = null;
          notifyListeners();
        }
      },
      onVerificationCompleted: (credential) async {
        print('⚠️ Auto-verification detected but disabled');
      },
    );
  }

  /// Sign in with OTP - ALL sign-in logic in ONE place
  Future<bool> signInWithOTP(String verificationId, String smsCode) async {
    if (verificationId.isEmpty || smsCode.isEmpty) {
      _errorMessage = 'Please enter the verification code.';
      notifyListeners();
      return false;
    }

    print('🔐 Starting sign-in process...');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Sign in to Firebase
      print('1️⃣ Signing in to Firebase...');
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      UserCredential userCredential = await _authService.signInWithCredential(credential);
      
      if (userCredential.user == null || userCredential.user!.phoneNumber == null) {
        throw Exception('Invalid user credentials');
      }

      String phoneNumber = userCredential.user!.phoneNumber!;
      print('✅ Firebase sign-in successful: $phoneNumber');

      // Step 2: Wait for auth token to propagate
      print('2️⃣ Waiting for auth token to propagate...');
      await Future.delayed(const Duration(milliseconds: 1500));

      // Step 3: Verify parent exists in Firestore with retries
      print('3️⃣ Verifying parent in Firestore...');
      Parent? parent = await _verifyParentWithRetries(phoneNumber);

      if (parent == null) {
        print('❌ Parent not found in Firestore');
        // Clean up: sign out from Firebase
        await _authService.signOut();
        _errorMessage = 'This phone number is not registered. Please contact your school.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Step 4: Success! Set up the session
      print('✅ Parent found: ${parent.name}');
      _currentParent = parent;
      _verificationId = null;
      
      // Step 5: Save FCM token and show welcome notification
      try {
        await NotificationService().saveTokenToFirestore(parent.id);
        await NotificationService().showStatusNotification(
          title: 'Welcome!',
          body: "You're signed in to LineMeUp.",
        );
      } catch (e) {
        print('⚠️ Failed to save FCM token: $e');
      }

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      print('🎉 Sign-in completed successfully!');
      return true;

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase auth error: ${e.code}');
      await _authService.signOut();
      _errorMessage = _getAuthErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
      
    } on TimeoutException catch (e) {
      print('⏱️ Timeout error: $e');
      await _authService.signOut();
      _errorMessage = 'Request timed out. Please check your connection and try again.';
      _isLoading = false;
      notifyListeners();
      return false;
      
    } catch (e) {
      print('❌ Unexpected error: $e');
      await _authService.signOut();
      _errorMessage = 'Unable to sign in. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify parent exists in Firestore with automatic retries
  Future<Parent?> _verifyParentWithRetries(String phoneNumber, {int attempt = 1}) async {
    const maxAttempts = 4;
    
    try {
      print('🔍 Verification attempt $attempt/$maxAttempts');
      return await _authService.verifyParentInFirestore(phoneNumber);
    } catch (e) {
      print('❌ Attempt $attempt failed: $e');
      
      // If permission denied and we have retries left, wait and retry
      if (e.toString().contains('permission-denied') && attempt < maxAttempts) {
        final delayMs = 1000 * attempt; // 1s, 2s, 3s
        print('⏳ Waiting ${delayMs}ms before retry $attempt/$maxAttempts');
        await Future.delayed(Duration(milliseconds: delayMs));
        return await _verifyParentWithRetries(phoneNumber, attempt: attempt + 1);
      }
      
      // Out of retries or other error
      return null;
    }
  }

  /// Sign out - simple and clean
  Future<void> signOut() async {
    print('🚪 Signing out...');
    
    _verifyTimeoutTimer?.cancel();
    _verifyTimeoutTimer = null;
    
    // Remove FCM token
    if (_currentParent != null) {
      try {
        await NotificationService().removeTokenFromFirestore();
      } catch (e) {
        print('⚠️ Failed to remove FCM token: $e');
      }
    }
    
    // Clear state
    _currentParent = null;
    _errorMessage = null;
    _verificationId = null;
    
    // Sign out from Firebase
    try {
      await _authService.signOut();
      print('✅ Signed out successfully');
    } catch (e) {
      print('❌ Sign-out error: $e');
    }
    
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Incorrect code. Please check and try again.';
      case 'session-expired':
        return 'Session expired. Please request a new code.';
      case 'code-expired':
        return 'Code expired. Please request a new code.';
      case 'invalid-credential':
        return 'Incorrect code. Please check and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Unable to verify. Please try again.';
    }
  }
}
