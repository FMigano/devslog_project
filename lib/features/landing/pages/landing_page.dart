import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/register_page.dart';
import '../../admin/pages/admin_login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  int _logoTapCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToAbout() {
    _scrollController.animateTo(
      MediaQuery.of(context).size.height * 2,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  void _showAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroSection(),
                _buildFeaturesSection(),
                _buildStatsSection(),
                _buildAboutUsSection(),
                _buildCTASection(),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      title: Row(
        children: [
          GestureDetector(
            onLongPress: _showAdminLogin,
            onTap: () {
              setState(() => _logoTapCount++);
              if (_logoTapCount >= 7) {
                _logoTapCount = 0;
                _showAdminLogin();
              }
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _logoTapCount = 0);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.code, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          const Text('DevsLog', style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
          child: const Text('Login'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            );
          },
          child: const Text('Sign Up'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: MediaQuery.of(context).size.height - 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withAlpha(26),
            AppTheme.accentColor.withAlpha(26),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ).animate().fadeIn(duration: 600.ms).slideX(),
                      const SizedBox(height: 16),
                      Text(
                        AppConstants.appTagline,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ).animate().fadeIn(delay: 200.ms).slideX(),
                      const SizedBox(height: 24),
                      Text(
                        'Join thousands of developers sharing knowledge, solving problems, and building the future together.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                              );
                            },
                            icon: const Icon(Icons.rocket_launch),
                            label: const Text('Get Started'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            ),
                          ).animate().fadeIn(delay: 600.ms).scale(),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: _scrollToAbout,
                            icon: const Icon(Icons.info_outline),
                            label: const Text('About Us'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            ),
                          ).animate().fadeIn(delay: 800.ms).scale(),
                        ],
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.of(context).size.width > 800)
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onLongPress: _showAdminLogin,
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(200),
                          ),
                          child: const Icon(
                            Icons.code,
                            size: 200,
                            color: AppTheme.primaryColor,
                          ),
                        ).animate().scale(duration: 1000.ms),
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

  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.forum,
        'title': 'Interactive Forums',
        'description': 'Engage in meaningful discussions with developers worldwide',
      },
      {
        'icon': Icons.code,
        'title': 'Code Sharing',
        'description': 'Share and discover code snippets, projects, and solutions',
      },
      {
        'icon': Icons.school,
        'title': 'Learn & Grow',
        'description': 'Access tutorials, guides, and expert knowledge',
      },
      {
        'icon': Icons.people,
        'title': 'Community',
        'description': 'Connect with like-minded developers and build your network',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'Why Choose DevsLog?',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you need to grow as a developer',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              Wrap(
                spacing: 32,
                runSpacing: 32,
                children: features.map((feature) {
                  return SizedBox(
                    width: 250,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                feature['icon'] as IconData,
                                size: 40,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              feature['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feature['description'] as String,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(13),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('10K+', 'Developers'),
              _buildStatItem('50K+', 'Posts'),
              _buildStatItem('100K+', 'Discussions'),
              _buildStatItem('1M+', 'Code Snippets'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ).animate().fadeIn().scale(),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildAboutUsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'About Us',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Meet the team behind DevsLog',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              // Project Manager Section
              Text(
                'Project Manager',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              _buildTeamMember(
                'Charles Collantes',
                'Project Manager',
                Icons.manage_accounts,
                AppTheme.primaryColor,
              ),
              
              const SizedBox(height: 60),
              
              // Developer Section
              Text(
                'Developer',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              _buildTeamMember(
                'Frederick Migano',
                'Developer',
                Icons.code,
                AppTheme.successColor,
              ),
              
              const SizedBox(height: 60),
              
              // Research and Documentation Section
              Text(
                'Research and Documentation',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  _buildTeamMember(
                    'Kathleen Santos',
                    'Research & Documentation',
                    Icons.description,
                    AppTheme.accentColor,
                  ),
                  _buildTeamMember(
                    'Allison Paris',
                    'Research & Documentation',
                    Icons.description,
                    AppTheme.accentColor,
                  ),
                  _buildTeamMember(
                    'David Nonan',
                    'Research & Documentation',
                    Icons.description,
                    AppTheme.accentColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMember(String name, String role, IconData icon, Color color) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                role,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(),
    );
  }

  Widget _buildCTASection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
          ],
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              'Ready to Join?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Start your developer journey today',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Create Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      color: AppTheme.secondaryColor,
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.code, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'DevsLog',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 DevsLog. All rights reserved.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
