import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart' as app_auth;
import 'student_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;
  app_auth.AuthProvider? _authProviderForListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetLoginState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache provider so dispose() can remove listener without using context
    _authProviderForListener ??= Provider.of<app_auth.AuthProvider>(context, listen: false);
  }

  void _resetLoginState() {
    if (!mounted) return;
    setState(() {
      _isOtpSent = false;
      _verificationId = null;
      _isLoading = false;
      _phoneController.clear();
      _otpController.clear();
    });

    final authProvider = _authProviderForListener;
    if (authProvider == null || !mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null || authProvider.isAuthenticated) {
      authProvider.signOut();
    }
  }

  @override
  void dispose() {
    // Use cached reference only; never use context in dispose
    _authProviderForListener?.removeListener(_onAuthProviderChanged);
    _authProviderForListener = null;
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showSnackBar({
    required String message,
    bool isError = false,
    bool isSuccess = false,
    IconData? icon,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ??
                  (isError
                      ? Icons.error_outline_rounded
                      : isSuccess
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded),
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : isSuccess
                ? const Color(0xFF10B981)
                : const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  Future<void> _sendOTP() async {
    try {
      String phoneNumber = _phoneController.text.trim();

      if (phoneNumber.isEmpty) {
        _showSnackBar(
          message: 'Please enter your phone number',
          isError: true,
        );
        return;
      }

      // Validate phone number format (should start with +)
      if (!phoneNumber.startsWith('+')) {
        _showSnackBar(
          message: 'Please include your country code (e.g., +1)',
          isError: true,
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);

      // Clear any previous errors
      authProvider.clearError();

      // Start listening to provider changes (keep ref so we can remove in dispose without context)
      _authProviderForListener = authProvider;
      authProvider.addListener(_onAuthProviderChanged);

      await authProvider.verifyPhoneNumber(phoneNumber);

      // Wait a bit for callbacks to fire
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Check for errors or success
      _checkAuthState();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(
          message: 'Something went wrong. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _onAuthProviderChanged() {
    if (!mounted) return;
    _checkAuthState();
  }

  void _checkAuthState() {
    if (!mounted) return;
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);

    if (authProvider.errorMessage != null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        message: authProvider.errorMessage!,
        isError: true,
      );
    } else if (authProvider.verificationId != null && !_isOtpSent) {
      if (!mounted) return;
      setState(() {
        _verificationId = authProvider.verificationId;
        _isOtpSent = true;
        _isLoading = false;
      });

      _showSnackBar(
        message: 'Verification code sent!',
        isSuccess: true,
        icon: Icons.sms_rounded,
      );
    } else if (!authProvider.isLoading && _isLoading) {
      // Still loading but no response yet - might be taking time
      // Keep loading indicator
    }
  }

  Future<void> _verifyOTP() async {
    String otpCode = _otpController.text.trim();

    if (otpCode.isEmpty) {
      _showSnackBar(
        message: 'Please enter the verification code',
        isError: true,
      );
      return;
    }

    if (otpCode.length < 6) {
      _showSnackBar(
        message: 'Please enter the complete 6-digit code',
        isError: true,
      );
      return;
    }

    // Get verification ID from provider or local state
    String? verificationId = _verificationId ??
        Provider.of<app_auth.AuthProvider>(context, listen: false)
            .verificationId;

    if (verificationId == null || verificationId.isEmpty) {
      _showSnackBar(
        message: 'Session expired. Please request a new code.',
        isError: true,
      );
      setState(() {
        _isOtpSent = false;
        _otpController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);

    bool success = false;
    try {
      // Wrap with timeout as a safety net (provider also has timeouts)
      success = await authProvider.signInWithOTP(
        verificationId,
        otpCode,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ UI-level timeout: signInWithOTP exceeded 15s');
          if (mounted) {
            _showSnackBar(
              message: 'Request timed out. Please check your connection and try again.',
              isError: true,
            );
          }
          return false;
        },
      );
    } catch (e) {
      print('❌ Error in _verifyOTP: $e');
      if (mounted) {
        _showSnackBar(
          message: authProvider.errorMessage ?? 'Verification failed. Please try again.',
          isError: true,
        );
      }
    } finally {
      // Always clear loading state, even on timeout or error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (!mounted) return;

    if (success) {
      // Remove listener before navigating so we don't use context after route is replaced
      authProvider.removeListener(_onAuthProviderChanged);
      _authProviderForListener = null;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo and Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOtpSent
                          ? 'Enter the code we sent to your phone'
                          : 'Sign in with your phone number',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Phone Number Input
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isOtpSent,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '+1 234 567 8900',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_rounded,
                            color: _isOtpSent
                                ? Colors.grey[400]
                                : Theme.of(context).primaryColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: _isOtpSent
                              ? Colors.grey[100]
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          // Clear error when user changes phone number
                          final authProvider =
                              Provider.of<app_auth.AuthProvider>(
                                  context,
                                  listen: false);
                          if (authProvider.errorMessage != null) {
                            authProvider.clearError();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // OTP Input (shown after sending OTP)
              if (_isOtpSent) ...[
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '• • • • • •',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w400,
                            letterSpacing: 8,
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Action Button
              Builder(
                builder: (context) {
                  final authProvider =
                      Provider.of<app_auth.AuthProvider>(context);
                  final isLoading = _isLoading || authProvider.isLoading;

                  return SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (_isOtpSent) {
                                _verifyOTP();
                              } else {
                                _sendOTP();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isOtpSent
                                      ? Icons.verified_user_rounded
                                      : Icons.send_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isOtpSent ? 'Verify Code' : 'Send Code',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),

              // Change phone number button
              if (_isOtpSent) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      final authProvider = Provider.of<app_auth.AuthProvider>(
                          context,
                          listen: false);
                      // Clear error when changing phone number
                      authProvider.clearError();
                      setState(() {
                        _isOtpSent = false;
                        _otpController.clear();
                        _verificationId = null;
                      });
                    },
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    label: Text(
                      'Change phone number',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Help text
              Center(
                child: Text(
                  'By signing in, you agree to our Terms of Service',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
