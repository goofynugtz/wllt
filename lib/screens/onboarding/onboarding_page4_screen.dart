import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/user_preferences_provider.dart';
import '../../screens/layout_screen.dart';
import 'onboarding_shared_widgets.dart';

class OnboardingPage4Screen extends StatefulWidget {
  final VoidCallback onBack;

  const OnboardingPage4Screen({super.key, required this.onBack});

  @override
  State<OnboardingPage4Screen> createState() => _OnboardingPage4ScreenState();
}

class _OnboardingPage4ScreenState extends State<OnboardingPage4Screen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  Future<void> _handleContinue() async {
    if (_trimmed.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    final prefs = context.read<UserPreferencesProvider>();
    await prefs.setDisplayName(_trimmed);
    await prefs.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LayoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canContinue = _trimmed.isNotEmpty && !_isLoading;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: widget.onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: OnboardingProgressBar(current: 3, total: 3),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '3 of 3',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Heading ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finally, what should\nwe call you?',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.65,
                      color: cs.onSurface,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll use this to personalise your experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Name field ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focusNode.hasFocus ? cs.primary : cs.outlineVariant,
                    width: _focusNode.hasFocus ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleContinue(),
                  style: TextStyle(fontSize: 16, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Your first name',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      LucideIcons.user,
                      size: 18,
                      color: _focusNode.hasFocus ? cs.primary : cs.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Get Started button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
              child: Opacity(
                opacity: canContinue ? 1.0 : 0.4,
                child: GestureDetector(
                  onTap: canContinue ? _handleContinue : null,
                  child: Builder(
                    builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.sparkles,
                                        size: 18, color: cs.onInverseSurface),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onInverseSurface,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
