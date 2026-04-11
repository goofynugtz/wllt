import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/user_preferences_provider.dart';
import '../../services/auth_service.dart';

class OnboardingPage1Screen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingPage1Screen({super.key, required this.onNext});

  @override
  State<OnboardingPage1Screen> createState() => _OnboardingPage1ScreenState();
}

class _OnboardingPage1ScreenState extends State<OnboardingPage1Screen> {
  bool _agreedToTerms = false;
  bool _isLoading = false;

  // Recognizers must live as fields so they can be disposed — creating them
  // inside build() leaks one instance per rebuild.
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    // Terms of Service URL not yet configured.
  }

  void _openPrivacy() {
    // Privacy Policy URL not yet configured.
  }

  Future<void> _handleGoogleSignIn() async {
    final authService = context.read<AuthService>();
    final prefs = context.read<UserPreferencesProvider>();
    setState(() => _isLoading = true);
    try {
      final cred = await authService.signInWithGoogle();
      if (cred == null) {
        // User dismissed the account picker — do nothing.
        setState(() => _isLoading = false);
        return;
      }
      final user = cred.user!;
      await prefs.setAuthMode('google');
      await prefs.setGoogleUser(uid: user.uid, email: user.email ?? '');
      widget.onNext();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: ${e.message}')),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOfflineMode() async {
    await context.read<UserPreferencesProvider>().setAuthMode('offline');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Offline mode — your data won't be backed up to the cloud."),
        duration: Duration(seconds: 3),
      ),
    );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _agreedToTerms && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background fills the full screen edge-to-edge.
          Positioned.fill(
            child: Container(
              color: const Color(0xFFFFF3F0).withValues(alpha: 0.91),
            ),
          ),
          // SafeArea keeps content clear of status bar and home indicator.
          SafeArea(
            child: Column(
              children: [
                // ── Hero ────────────────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6750A4), Color(0xFF9D85E5)],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x526750A4),
                                blurRadius: 40,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.wallet,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'WLLT',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 38,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.76,
                            color: Color(0xFF1D1B20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Track your expenses,\nmaster your money.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: Color(0xFF6B6572),
                            height: 1.375,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Bottom panel ─────────────────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(36)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 32,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GET STARTED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          letterSpacing: 0.325,
                          color: Color(0xFF6B6572),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: enabled ? 1.0 : 0.4,
                        child: _ActionButton(
                          onPressed: enabled ? _handleGoogleSignIn : null,
                          isLoading: _isLoading,
                          icon: const _GoogleLogo(),
                          label: 'Continue with Google',
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D1B20),
                          borderColor: const Color(0xFFE8E0EC),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: Color(0xFFE8E0EC))),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: Color(0xFFE8E0EC))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: enabled ? 1.0 : 0.4,
                        child: _ActionButton(
                          onPressed: enabled ? _handleOfflineMode : null,
                          isLoading: false,
                          icon: const Icon(LucideIcons.cloudOff,
                              size: 20, color: Color(0xFF6750A4)),
                          label: 'Continue without account',
                          backgroundColor: const Color(0xFFF5EFF7),
                          foregroundColor: const Color(0xFF6750A4),
                          borderColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── T&C checkbox ────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              activeColor: const Color(0xFF6750A4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              onChanged: (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: Color(0xFF9E99A3),
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: const TextStyle(
                                        color: Color(0xFF6750A4)),
                                    recognizer: _termsRecognizer,
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                        color: Color(0xFF6750A4)),
                                    recognizer: _privacyRecognizer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  const _ActionButton({
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: borderColor == Colors.transparent
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 1))
                ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: foregroundColor))
                : icon,
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: foregroundColor),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Official Google "G" logo rendered from inline SVG paths.
/// No asset file required — flutter_svg handles the string directly.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  // Source: https://developers.google.com/identity/branding-guidelines
  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: 20, height: 20);
  }
}
