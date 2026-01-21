import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/otp_service.dart';
import '../../home/pages/home_page.dart';

class OTPVerificationPage extends StatefulWidget {
  const OTPVerificationPage({super.key});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  Timer? _timer;
  int _countdown = 300; // 5 minutes
  String? _generatedOTP;

  @override
  void initState() {
    super.initState();
    _sendOTP();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        Fluttertoast.showToast(
          msg: 'OTP expired. Please request a new one.',
          backgroundColor: AppTheme.warningColor,
        );
      }
    });
  }

  Future<void> _sendOTP() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userEmail = authService.currentUser?.email;
      
      if (userEmail == null) return;

      // Generate 6-digit OTP
      final otp = OTPService.generateOTP();
      _generatedOTP = otp;

      // Send OTP via email (you'll need to implement email service)
      await OTPService.sendOTPEmail(userEmail, otp);

      Fluttertoast.showToast(
        msg: '📱 OTP sent to your email',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to send OTP: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _verifyOTP() async {
    final enteredOTP = _controllers.map((c) => c.text).join();
    
    if (enteredOTP.length != 6) {
      Fluttertoast.showToast(
        msg: 'Please enter complete OTP',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (enteredOTP == _generatedOTP) {
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Mark user as OTP verified in Firestore
        await OTPService.markOTPVerified(authService.currentUser!.uid);

        Fluttertoast.showToast(
          msg: '✅ Account verified successfully!',
          backgroundColor: AppTheme.successColor,
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: '❌ Invalid OTP. Please try again.',
          backgroundColor: AppTheme.errorColor,
        );
        
        // Clear all fields
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Verification failed: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkBackground,
              AppTheme.darkSurface,
              AppTheme.darkSurfaceVariant,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 8,
                  color: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: AppTheme.darkDivider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // OTP Icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.darkPrimary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_clock,
                            size: 64,
                            color: AppTheme.darkPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Enter OTP',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'We\'ve sent a 6-digit code to your email',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // OTP Input Fields
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 50,
                              child: TextFormField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppTheme.darkSurfaceVariant,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.darkDivider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.darkDivider),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.darkPrimary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  
                                  // Auto-verify when all fields are filled
                                  if (index == 5 && value.isNotEmpty) {
                                    final allFilled = _controllers.every(
                                      (c) => c.text.isNotEmpty,
                                    );
                                    if (allFilled) {
                                      _verifyOTP();
                                    }
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 24),

                        // Timer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _countdown < 60
                                ? AppTheme.errorColor.withOpacity(0.1)
                                : AppTheme.darkSurfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _countdown < 60
                                  ? AppTheme.errorColor
                                  : AppTheme.darkDivider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 16,
                                color: _countdown < 60
                                    ? AppTheme.errorColor
                                    : AppTheme.darkTextSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(_countdown),
                                style: TextStyle(
                                  color: _countdown < 60
                                      ? AppTheme.errorColor
                                      : AppTheme.darkTextPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Verify Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend OTP
                        TextButton(
                          onPressed: _countdown == 0
                              ? () {
                                  _sendOTP();
                                  setState(() => _countdown = 300);
                                  _startCountdown();
                                }
                              : null,
                          child: Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: _countdown == 0
                                  ? AppTheme.darkPrimary
                                  : AppTheme.darkTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}