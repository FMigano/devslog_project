import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Terms & Conditions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            '1. Acceptance of Terms',
            'By accessing and using DevsLog, you accept and agree to be bound by the terms and provision of this agreement.',
          ),
          _buildSection(
            '2. User Registration',
            'You must register for an account to access certain features. You agree to:\n'
            '• Provide accurate and complete information\n'
            '• Maintain the security of your password\n'
            '• Accept responsibility for all activities under your account\n'
            '• Notify us immediately of any unauthorized use',
          ),
          _buildSection(
            '3. User Content',
            'You retain ownership of content you post. By posting, you grant DevsLog:\n'
            '• A worldwide, non-exclusive license to use your content\n'
            '• The right to display, distribute, and promote your content\n'
            '• You are responsible for your content and its legality',
          ),
          _buildSection(
            '4. Prohibited Activities',
            'You agree NOT to:\n'
            '• Post spam, malicious code, or harmful content\n'
            '• Harass, abuse, or harm other users\n'
            '• Impersonate others or misrepresent affiliation\n'
            '• Violate intellectual property rights\n'
            '• Attempt to gain unauthorized access to our systems',
          ),
          _buildSection(
            '5. Privacy Policy',
            'We collect and use your data as described in our Privacy Policy. This includes:\n'
            '• Email address for authentication\n'
            '• Profile information you provide\n'
            '• Usage data and analytics\n'
            '• We do not sell your personal information',
          ),
          _buildSection(
            '6. Content Moderation',
            'We reserve the right to:\n'
            '• Review and moderate all posted content\n'
            '• Remove content that violates our policies\n'
            '• Suspend or terminate accounts for violations\n'
            '• Admin approval may be required for posts',
          ),
          _buildSection(
            '7. Intellectual Property',
            'The DevsLog platform, including design, code, and branding is protected by copyright and other laws. You may not:\n'
            '• Copy or modify the platform\n'
            '• Reverse engineer our code\n'
            '• Use our branding without permission',
          ),
          _buildSection(
            '8. Disclaimer of Warranties',
            'DevsLog is provided "AS IS" without warranties of any kind. We do not guarantee:\n'
            '• Uninterrupted or error-free service\n'
            '• Accuracy or reliability of content\n'
            '• Security of data transmission',
          ),
          _buildSection(
            '9. Limitation of Liability',
            'We are not liable for:\n'
            '• Indirect or consequential damages\n'
            '• Loss of data or profits\n'
            '• User-generated content\n'
            '• Third-party actions',
          ),
          _buildSection(
            '10. Account Termination',
            'We may terminate or suspend your account:\n'
            '• For violations of these terms\n'
            '• For prolonged inactivity\n'
            '• At our discretion with notice\n'
            'You may delete your account at any time',
          ),
          _buildSection(
            '11. Changes to Terms',
            'We reserve the right to modify these terms at any time. Continued use after changes constitutes acceptance of new terms.',
          ),
          _buildSection(
            '12. Contact Information',
            'For questions about these terms, contact us at:\n'
            'Email: support@devslog.com\n'
            'Website: www.devslog.com',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.infoColor),
                    const SizedBox(width: 8),
                    Text(
                      'Last Updated',
                      style: TextStyle(
                        color: AppTheme.infoColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These terms were last updated on January 18, 2026',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}