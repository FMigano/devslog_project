import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/register_page.dart';
import '../../admin/pages/admin_login_page.dart';
import '../../home/pages/home_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final ScrollController _scrollController;
  int _logoTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    
    // Reset counter if more than 2 seconds passed since last tap
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    
    _lastTapTime = now;

    // If tapped 5 times quickly, navigate to admin login
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.currentUser != null) {
      return const HomePage();
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: _handleLogoTap,
              onLongPress: () {
                // Alternative: Long press to access admin
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.code, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleLogoTap,
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                );
              },
              child: Text(
                'DevsLog',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: Text(
              'Login',
              style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Sign Up'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(context),
            _buildAboutSection(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height - 80,
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DevsLog',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.darkPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Where Developers Connect & Collaborate',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.darkTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Join thousands of developers sharing knowledge, solving problems,\nand building the future together.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.darkTextSecondary,
                              height: 1.6,
                            ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.rocket_launch),
                            label: const Text('Get Started'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _scrollController.animateTo(
                                MediaQuery.of(context).size.height - 80,
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text('About Us'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.darkPrimary,
                              side: const BorderSide(
                                color: AppTheme.darkPrimary,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 80),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onLongPress: () {
                        // Hidden admin access via long press on icon
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                        );
                      },
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.darkPrimary.withOpacity(0.3),
                              AppTheme.darkPrimary.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.code,
                            size: 200,
                            color: AppTheme.darkPrimary.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: AppTheme.darkSurface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppTheme.darkPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'About DevsLog',
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'DevsLog is a modern forum platform built with Flutter and Firebase,\ndesigned to connect developers worldwide.',
                style: TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 18,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              Text(
                'Development Team',
                style: TextStyle(
                  color: AppTheme.darkPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTeamCard(
                      'Developer',
                      'Frederick Allen Migano',
                      Icons.code,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTeamCard(
                      'Project Manager',
                      'Charles Collantes',
                      Icons.manage_accounts,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Researchers',
                style: TextStyle(
                  color: AppTheme.darkPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildTeamCard(
                      'Researcher',
                      'Kathleen Santos',
                      Icons.search,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTeamCard(
                      'Researcher',
                      'Alisson Paris',
                      Icons.search,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTeamCard(
                      'Researcher',
                      'David Nonan',
                      Icons.search,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Text(
                'Built with Flutter 🚀',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border(
          top: BorderSide(color: AppTheme.darkDivider),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and Description
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.darkPrimary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.code,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'DevsLog',
                              style: TextStyle(
                                color: AppTheme.darkTextPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'A modern forum platform for developers\nto connect, share, and collaborate.',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Quick Links
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Links',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFooterLink('Home', () {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }),
                        _buildFooterLink('About Us', () {
                          _scrollController.animateTo(
                            MediaQuery.of(context).size.height - 80,
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeInOut,
                          );
                        }),
                        _buildFooterLink('Sign Up', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterPage(),
                            ),
                          );
                        }),
                        _buildFooterLink('Login', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Categories
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFooterLink('General', null),
                        _buildFooterLink('Web Development', null),
                        _buildFooterLink('Mobile Development', null),
                        _buildFooterLink('Backend', null),
                        _buildFooterLink('AI/ML', null),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Connect
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.code_outlined),
                              color: AppTheme.darkPrimary,
                              onPressed: () async {
                                final Uri url = Uri.parse('https://github.com/FMigano/devslog_project');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              tooltip: 'GitHub',
                            ),
                            IconButton(
                              icon: const Icon(Icons.language),
                              color: AppTheme.darkPrimary,
                              onPressed: () {},
                              tooltip: 'Website',
                            ),
                            IconButton(
                              icon: const Icon(Icons.email_outlined),
                              color: AppTheme.darkPrimary,
                              onPressed: () async {
                                final Uri emailUri = Uri(
                                  scheme: 'mailto',
                                  path: 'devslogproject@gmail.com',
                                  query: 'subject=DevsLog Inquiry',
                                );
                                if (await canLaunchUrl(emailUri)) {
                                  await launchUrl(emailUri);
                                }
                              },
                              tooltip: 'Email',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Divider(color: AppTheme.darkDivider),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2026 DevsLog. All rights reserved.',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.flutter_dash,
                        color: AppTheme.darkPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Built with Flutter',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 14,
            decoration: onTap != null ? TextDecoration.underline : null,
            decorationColor: AppTheme.darkTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(String role, String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkPrimary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.darkPrimary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            role,
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
