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

  @override
  void initState() {
    super.initState();
    // Reset login state when screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetLoginState();
    });
  }

  void _resetLoginState() {
    setState(() {
      _isOtpSent = false;
      _verificationId = null;
      _isLoading = false;
      _phoneController.clear();
      _otpController.clear();
    });
    
    // Ensure user is signed out when login screen is shown
    // This prevents auto-login after logout
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null || authProvider.isAuthenticated) {
      print('🔒 Forcing sign out on login screen - user should not be authenticated');
      authProvider.signOut();
    }
  }

  @override
  void dispose() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    authProvider.removeListener(_onAuthProviderChanged);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    print('🔘 Send OTP button clicked');
    try {
      String phoneNumber = _phoneController.text.trim();
      print('📞 Phone number entered: $phoneNumber');
      
      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your phone number')),
        );
        return;
      }

      // Validate phone number format (should start with +)
      if (!phoneNumber.startsWith('+')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter phone number with country code (e.g., +1234567890)'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Clear any previous errors
      authProvider.clearError();
      
      // Start listening to provider changes
      authProvider.addListener(_onAuthProviderChanged);
      
      await authProvider.verifyPhoneNumber(phoneNumber);

      // Wait a bit for callbacks to fire
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Don't check for auto-authentication - require OTP input
      // Auto-verification is disabled in AuthProvider
      
      // Check for errors or success
      _checkAuthState();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _onAuthProviderChanged() {
    if (!mounted) return;
    _checkAuthState();
  }

  void _checkAuthState() {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    
    if (authProvider.errorMessage != null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (authProvider.verificationId != null && !_isOtpSent) {
      setState(() {
        _verificationId = authProvider.verificationId;
        _isOtpSent = true;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (!authProvider.isLoading && _isLoading) {
      // Still loading but no response yet - might be taking time
      // Keep loading indicator
    }
  }

  Future<void> _verifyOTP() async {
    String otpCode = _otpController.text.trim();
    
    if (otpCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP code')),
      );
      return;
    }

    // Get verification ID from provider or local state
    String? verificationId = _verificationId ?? 
        Provider.of<app_auth.AuthProvider>(context, listen: false).verificationId;
    
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification session expired. Please request a new code.')),
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

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    
    bool success = await authProvider.signInWithOTP(
      verificationId,
      otpCode,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentSelectionScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Verification failed'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_android,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              const Text(
                'Enter your phone number',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll send you a verification code",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1234567890',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                enabled: !_isOtpSent,
              ),
              if (_isOtpSent) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    hintText: 'Enter 6-digit code',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<app_auth.AuthProvider>(context);
                  final isLoading = _isLoading || authProvider.isLoading;
                  
                  if (isLoading) {
                    return const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  return ElevatedButton(
                    onPressed: () {
                      print('🔘 Button pressed - isOtpSent: $_isOtpSent');
                      if (_isOtpSent) {
                        _verifyOTP();
                      } else {
                        _sendOTP();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(_isOtpSent ? 'Verify OTP' : 'Send OTP'),
                  );
                },
              ),
              if (_isOtpSent)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Change phone number'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

