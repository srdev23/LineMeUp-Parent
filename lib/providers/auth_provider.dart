import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/parent.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  Parent? _currentParent;
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;

  Parent? get currentParent => _currentParent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentParent != null;
  String? get verificationId => _verificationId;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      if (user == null) {
        _currentParent = null;
        notifyListeners();
      } else {
        // User is signed in, verify parent exists
        // This handles auto-verification case
        if (_currentParent == null) {
          await _verifyParent(user.phoneNumber ?? '');
        }
      }
    });
  }

  Future<void> _verifyParent(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _currentParent = null;
      notifyListeners();
      return;
    }
    
    try {
      Parent? parent = await _authService.verifyCurrentUser();
      if (parent != null) {
        _currentParent = parent;
        notifyListeners();
      } else {
        // Parent not found, sign out
        await signOut();
      }
    } catch (e) {
      _currentParent = null;
      notifyListeners();
    }
  }

  Future<void> verifyPhoneNumber(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _verificationId = null;
    notifyListeners();

    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error;
        _verificationId = null;
        notifyListeners();
      },
      onVerificationCompleted: (credential) async {
        // Handle auto-verification (Android)
        print('✅ Auto-verification callback triggered');
        try {
          // Sign in with the credential first
          await _authService.signInWithCredential(credential);
          
          // Wait a bit for auth state to update
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Now verify parent
          Parent? parent = await _authService.verifyCurrentUser();
          if (parent != null) {
            _currentParent = parent;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          } else {
            _isLoading = false;
            _errorMessage = 'Your phone number is not registered with the school.';
            await signOut();
            notifyListeners();
          }
        } catch (e) {
          print('❌ Auto-verification error: $e');
          _isLoading = false;
          _errorMessage = 'Verification failed: ${e.toString()}';
          await signOut();
          notifyListeners();
        }
      },
    );
  }

  Future<bool> signInWithOTP(String verificationId, String smsCode) async {
    if (verificationId.isEmpty || smsCode.isEmpty) {
      _errorMessage = 'Verification ID or OTP code is missing';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Parent? parent = await _authService.signInWithOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      if (parent == null) {
        _errorMessage = 'Your phone number is not registered with the school.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentParent = parent;
      _isLoading = false;
      _errorMessage = null;
      _verificationId = null; // Clear verification ID after successful login
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Sign in failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'code-expired':
        return 'Verification code expired. Please request a new code.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentParent = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

