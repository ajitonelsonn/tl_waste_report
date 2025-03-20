// lib/screens/otp_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const routeName = '/otp-verification';
  
  final String email;
  final String username;
  final bool isRegistration; // Flag to determine if this is for registration or regular verification

  const OtpVerificationScreen({
    Key? key,
    required this.email,
    required this.username,
    this.isRegistration = true, // Default to registration flow
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCount = 0;
  int _remainingSeconds = 60;
  Timer? _resendTimer;
  int _attemptsLeft = 3;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers and focus nodes for each digit
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    
    // Start the resend timer
    _startResendTimer();
  }

  @override
  void dispose() {
    // Clean up controllers and focus nodes
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    
    // Cancel timer
    _resendTimer?.cancel();
    
    super.dispose();
  }
  
  // Start the timer for resend cooldown
  void _startResendTimer() {
    _remainingSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Get the entered OTP
  String _getEnteredOTP() {
    return _controllers.map((controller) => controller.text).join();
  }

  // Verify OTP
  Future<void> _verifyOTP() async {
    if (_isVerifying) return;
  
    final enteredOTP = _getEnteredOTP();
  
    if (enteredOTP.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits';
      });
      return;
    }
  
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
  
    try {
      // Use the appropriate verification endpoint based on isRegistration flag
      Map<String, dynamic> response;
      
      if (widget.isRegistration) {
        // Registration verification
        response = await _apiService.verifyRegistration(
          email: widget.email,
          otp: enteredOTP,
        );
      } else {
        // Regular account verification
        response = await _apiService.verifyOtp(
          email: widget.email,
          otp: enteredOTP,
        );
      }
      
      if (response['success']) {
        // Save the token and user data
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Save auth data from response
        await authProvider.saveAuthDataFromResponse(response);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
        }
      } else {
        if (response.containsKey('attempts_left')) {
          setState(() {
            _attemptsLeft = response['attempts_left'];
            _errorMessage = response['message'] ?? 'Verification failed';
          });
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Verification failed';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to server. Please check your internet connection.';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  // Resend OTP
  Future<void> _resendOTP() async {
    if (_isResending || _remainingSeconds > 0) return;
    
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });
    
    try {
      // Call appropriate resend/send OTP endpoint
      Map<String, dynamic> response;
      
      if (widget.isRegistration) {
        // Resend OTP for registration
        response = await _apiService.resendRegistrationOtp(
          email: widget.email,
        );
      } else {
        // Send OTP for existing account
        response = await _apiService.sendOtp(
          email: widget.email,
          username: widget.username,
        );
      }
      
      if (response['success']) {
        // Reset controllers
        for (var controller in _controllers) {
          controller.clear();
        }
        
        setState(() {
          _resendCount++;
        });
        
        // Set focus to first field
        _focusNodes[0].requestFocus();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Restart the timer
        _startResendTimer();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send new OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resending OTP. Please try again later.';
      });
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: const Icon(
                    Icons.mark_email_read,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                FadeInDown(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Verify Your Email',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'We\'ve sent a 6-digit OTP to ${widget.email}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // OTP input fields
                FadeInDown(
                  delay: const Duration(milliseconds: 600),
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                      (index) => SizedBox(
                        width: 40,
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: theme.primaryColor),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                          ),
                          onChanged: (value) {
                            // Move to next/previous field when typing
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            
                            // Auto-verify when all fields are filled
                            if (value.isNotEmpty && index == 5) {
                              _verifyOTP();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Error message
                if (_errorMessage != null)
                  FadeInDown(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                          if (_attemptsLeft < 3 && _errorMessage!.contains('Invalid OTP'))
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Attempts left: $_attemptsLeft',
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Verify button
                FadeInDown(
                  delay: const Duration(milliseconds: 800),
                  duration: const Duration(milliseconds: 500),
                  child: CustomButton(
                    text: 'Verify OTP',
                    icon: Icons.check_circle,
                    onPressed: _verifyOTP,
                    isLoading: _isVerifying,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend link
                FadeInDown(
                  delay: const Duration(milliseconds: 900),
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text(
                        'Please check your spam folder if it doesn\'t appear in your inbox.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Didn\'t receive the OTP?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: _remainingSeconds == 0 ? _resendOTP : null,
                            child: Text(
                              _remainingSeconds > 0
                                  ? 'Resend in ${_remainingSeconds}s'
                                  : 'Resend OTP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _remainingSeconds == 0
                                    ? theme.primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Resend count
                if (_resendCount > 0)
                  FadeInDown(
                    delay: const Duration(milliseconds: 1000),
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      'OTP resent $_resendCount ${_resendCount == 1 ? 'time' : 'times'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}