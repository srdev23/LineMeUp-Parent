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

  bool _isExplicitSignIn = false; // Track if sign-in was explicit (via OTP)
  bool _isSigningOut = false; // Track if we're in the process of signing out

  void _init() {
    _authService.authStateChanges.listen((user) async {
      // Ignore auth state changes during sign out process
      if (_isSigningOut) {
        return;
      }
      
      if (user == null) {
        _currentParent = null;
        _isExplicitSignIn = false;
        notifyListeners();
      } else {
        // Only verify parent if this was an explicit sign-in via OTP
        // Don't auto-verify on unexpected auth state changes
        if (_isExplicitSignIn && _currentParent == null) {
          await _verifyParent(user.phoneNumber ?? '');
        } else if (!_isExplicitSignIn) {
          // User is signed in but not via explicit OTP - sign them out
          // This prevents auto-login after logout or from auto-verification
          print('⚠️ Unexpected auth state - signing out to require OTP');
          _isSigningOut = true;
          await signOut();
          _isSigningOut = false;
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
        // DISABLE auto-verification - require OTP input
        // This prevents bypassing OTP verification
        print('⚠️ Auto-verification detected but disabled - OTP required');
        // Don't sign in automatically - user must enter OTP
        // The verification ID will be sent via codeSent callback
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
      // Mark as explicit sign-in before verifying
      _isExplicitSignIn = true;
      
      Parent? parent = await _authService.signInWithOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      if (parent == null) {
        _isExplicitSignIn = false;
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
      _isExplicitSignIn = false;
      _errorMessage = _getAuthErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isExplicitSignIn = false;
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
    _isSigningOut = true;
    _isExplicitSignIn = false;
    _verificationId = null;
    _currentParent = null;
    _errorMessage = null;
    
    try {
      await _authService.signOut();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

