import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../home/pages/home_page.dart'; // Add this import

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  Timer? _timer;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.currentUser?.reload();
      
      if (authService.currentUser?.emailVerified ?? false) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: '✅ Email verified successfully!',
            backgroundColor: AppTheme.successColor,
          );
          
          // Navigate directly to home page instead of login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Email not verified yet. Please check your inbox.',
          backgroundColor: AppTheme.warningColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error checking verification: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_countdown > 0) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.currentUser?.sendEmailVerification();
      
      Fluttertoast.showToast(
        msg: '✉️ Verification email sent!',
        backgroundColor: AppTheme.successColor,
      );
      
      _startCountdown();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to send email: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userEmail = authService.currentUser?.email ?? '';

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
                        // Email Icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.darkPrimary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mark_email_unread,
                            size: 64,
                            color: AppTheme.darkPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Verify Your Email',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'We\'ve sent a verification link to:',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.darkDivider),
                          ),
                          child: Text(
                            userEmail,
                            style: TextStyle(
                              color: AppTheme.darkPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.infoColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.infoColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.infoColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Check your spam folder if you don\'t see the email',
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Check Verification Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _checkVerification,
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
                                    'I\'ve Verified My Email',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend Button
                        TextButton(
                          onPressed: _countdown > 0 || _isLoading
                              ? null
                              : _resendVerification,
                          child: Text(
                            _countdown > 0
                                ? 'Resend in $_countdown seconds'
                                : 'Resend Verification Email',
                            style: TextStyle(
                              color: _countdown > 0
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.darkPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sign Out Button
                        OutlinedButton(
                          onPressed: () async {
                            await authService.signOut();
                            if (mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.darkDivider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Sign Out'),
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