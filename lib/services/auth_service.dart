import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parent.dart';
import '../utils/phone_utils.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Timeout durations
  static const Duration _signInTimeout = Duration(seconds: 30);
  static const Duration _firestoreTimeout = Duration(seconds: 20);

  /// Wraps an async operation with a timeout
  Future<T> _withTimeout<T>(
    Future<T> Function() operation,
    Duration timeout,
    String operationName,
  ) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          print('⏱️ Timeout: $operationName exceeded ${timeout.inSeconds}s');
          throw TimeoutException(
            '$operationName timed out after ${timeout.inSeconds} seconds',
            timeout,
          );
        },
      );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      print('❌ Error in $operationName: $e');
      rethrow;
    }
  }

  User? get currentUser => _auth.currentUser;

  /// Configure phone auth settings
  /// - Android: Prefer Play Integrity over reCAPTCHA
  /// - iOS: Enable app verification testing for simulators
  static Future<void> configurePhoneAuth() async {
    try {
      if (kDebugMode) {
        // Enable test mode for development/simulators
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        print('✅ Phone Auth configured for testing (debug mode)');
      }
      
      // Android: Prefer Play Integrity (no reCAPTCHA)
      await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: false);
      print('✅ Phone Auth configured successfully');
    } catch (e) {
      print('⚠️ Phone Auth configuration warning: $e');
      // Continue anyway - not critical
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential)? onVerificationCompleted,
  }) async {
    try {
      // Normalize phone number to E.164 format
      String normalizedPhone = PhoneUtils.normalizePhoneNumber(phoneNumber);
      
      print('🔐 Starting phone verification for: $normalizedPhone');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('⚠️ Auto-verification detected but disabled - requiring OTP input');
          // DISABLED: Don't auto-sign in - require OTP verification
          // This prevents bypassing OTP after logout
          if (onVerificationCompleted != null) {
            onVerificationCompleted(credential);
          }
          // Don't call _handleAutoVerification - require OTP
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.code} - ${e.message}');
          String errorMessage = _getUserFriendlyError(e.code);
          onError(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('📱 Verification code sent. ID: $verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ Auto-retrieval timeout. ID: $verificationId');
          // Store verification ID for auto-retrieval
          onCodeSent(verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
      
      print('📤 verifyPhoneNumber call completed');
    } catch (e, stackTrace) {
      print('💥 Exception in verifyPhoneNumber: $e');
      print('Stack trace: $stackTrace');
      onError('Unable to send verification code. Please try again.');
    }
  }

  String _getUserFriendlyError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'missing-client-identifier':
        return 'App configuration error. Please contact support.';
      case 'quota-exceeded':
        return 'Service temporarily unavailable. Please try again later.';
      case 'app-not-authorized':
        return 'App configuration error. Please contact support.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }


  /// Sign in with credential - simple wrapper with timeout
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    return await _withTimeout(
      () => _auth.signInWithCredential(credential),
      _signInTimeout,
      'signInWithCredential',
    );
  }

  /// Verify parent exists in Firestore - single attempt, no retries
  /// Retries are handled by the caller
  Future<Parent?> verifyParentInFirestore(String phoneNumber) async {
    try {
      // Try direct query with exact match
      QuerySnapshot querySnapshot = await _withTimeout(
        () => _firestore
            .collection('parents')
            .where('contactInfo', isEqualTo: phoneNumber)
            .limit(1)
            .get(),
        _firestoreTimeout,
        'Firestore query (contactInfo)',
      );

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return Parent.fromFirestore(data, doc.id);
        }
      }

      // If direct query fails, try normalized phone number matching
      QuerySnapshot allParents = await _withTimeout(
        () => _firestore.collection('parents').get(),
        _firestoreTimeout,
        'Firestore query (all parents)',
      );

      for (var doc in allParents.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        String contactInfo = data['contactInfo']?.toString() ?? '';
        
        if (PhoneUtils.arePhoneNumbersEqual(phoneNumber, contactInfo)) {
          return Parent.fromFirestore(data, doc.id);
        }
      }

      // No match found
      return null;
    } catch (e) {
      // Rethrow all errors - caller will handle retries
      rethrow;
    }
  }

  /// Sign out from Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
  }
}