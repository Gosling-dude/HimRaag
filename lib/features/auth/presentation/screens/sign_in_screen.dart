import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/legal_links.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../auth/providers/user_profile_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _isLoading = false;

  // The consent line must link to the documents it refers to.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => openExternalUrl(context, AppConstants.termsUrl);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => openExternalUrl(context, AppConstants.privacyPolicyUrl);

  static final TextStyle _linkStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.75),
    decoration: TextDecoration.underline,
    decorationColor: Colors.white.withValues(alpha: 0.75),
  );

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) _routeAfterAuth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).continueAsGuest();
    } catch (_) {/* local guest fallback already handled in repo */}
    if (mounted) _routeAfterAuth();
    if (mounted) setState(() => _isLoading = false);
  }

  /// New users pick personalization preferences first; returning users go
  /// straight to the feed.
  void _routeAfterAuth() {
    final done = ref.read(onboardingCompletedProvider);
    context.go(done ? '/home' : '/preferences');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundDark, AppColors.playerGradientStart],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                _AppLogo(),
                const SizedBox(height: 16),
                Text(
                  'HimRaag',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pahadi Music, Heart of the Hills',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(flex: 3),
                _SignInButton(
                  icon: const _GoogleIcon(),
                  label: 'Continue with Google',
                  onTap: _isLoading ? null : _signInWithGoogle,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF1A1030),
                ),
                const SizedBox(height: 16),
                _SignInButton(
                  icon: const Icon(Icons.person_outline,
                      color: Colors.white, size: 20),
                  label: 'Continue as Guest',
                  onTap: _isLoading ? null : _continueAsGuest,
                  backgroundColor: Colors.transparent,
                  textColor: Colors.white,
                  borderColor: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      children: [
                        TextSpan(
                          text: 'Terms of Service',
                          style: _linkStyle,
                          recognizer: _termsTap,
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: _linkStyle,
                          recognizer: _privacyTap,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child:
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor ?? Colors.transparent),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child:
          Icon(Icons.g_mobiledata_rounded, size: 20, color: Color(0xFF4285F4)),
    );
  }
}
