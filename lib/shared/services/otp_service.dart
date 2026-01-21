import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate 6-digit OTP
  static String generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send OTP via email (implement with your email service)
  static Future<void> sendOTPEmail(String email, String otp) async {
    // TODO: Implement email sending using a service like SendGrid, AWS SES, etc.
    // For now, we'll just print it (in production, send actual email)
    print('OTP for $email: $otp');
    
    // Store OTP in Firestore with expiry
    await _firestore.collection('otp_codes').doc(email).set({
      'code': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 5)),
      ),
      'verified': false,
    });
  }

  // Mark user as OTP verified
  static Future<void> markOTPVerified(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'otpVerified': true,
      'otpVerifiedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if user has verified OTP
  static Future<bool> isOTPVerified(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['otpVerified'] ?? false;
  }
}