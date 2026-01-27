import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parent.dart';
import '../utils/phone_utils.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

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


  Future<Parent?> signInWithOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // Create credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Sign in
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        await signOut();
        return null;
      }

      String phoneNumber = userCredential.user!.phoneNumber ?? '';
      
      if (phoneNumber.isEmpty) {
        await signOut();
        return null;
      }

      // Verify parent exists in Firestore
      return await _verifyParentInFirestore(phoneNumber);
    } on FirebaseAuthException {
      await signOut();
      rethrow;
    } catch (e) {
      await signOut();
      rethrow;
    }
  }

  Future<Parent?> _verifyParentInFirestore(String phoneNumber) async {
    try {
      // First, try direct query with exact match
      QuerySnapshot querySnapshot = await _firestore
          .collection('parents')
          .where('contactInfo', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          return Parent.fromFirestore(data, doc.id);
        }
      }

      // If direct query fails, try matching with normalized phone numbers
      // This handles cases where phone number formats differ
      QuerySnapshot allParents = await _firestore
          .collection('parents')
          .get();

      for (var doc in allParents.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        String contactInfo = data['contactInfo']?.toString() ?? '';
        
        // Compare phone numbers (handles different formats)
        if (PhoneUtils.arePhoneNumbersEqual(phoneNumber, contactInfo)) {
          return Parent.fromFirestore(data, doc.id);
        }
      }

      // If no match found, sign out
      await signOut();
      return null;
    } catch (e) {
      await signOut();
      return null;
    }
  }

  // Verify parent when user is already signed in (for auto-verification)
  Future<Parent?> verifyCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null || user.phoneNumber == null) {
      return null;
    }
    
    return await _verifyParentInFirestore(user.phoneNumber!);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Sign in with credential (for auto-verification)
  Future<void> signInWithCredential(PhoneAuthCredential credential) async {
    await _auth.signInWithCredential(credential);
  }
}
