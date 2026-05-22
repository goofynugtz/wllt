# Feedback Mechanism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a subtle, two-step feedback sheet that routes positive users to App Store rating and captures negative feedback in Firestore, triggered contextually (10th transaction or first Category Breakdown view) and manually via Settings.

**Architecture:** A `FeedbackSheet` widget handles both steps internally (sentiment → text). `FeedbackService` wraps Firestore writes and `in_app_review`. Milestone logic lives in `LayoutScreen`, which listens to `TransactionProvider` and intercepts the CategoryBreakdown tap via a callback passed to `HomeScreen`.

**Tech Stack:** Flutter, Firestore (`cloud_firestore` already in project), `in_app_review` package, SharedPreferences (already in project via `StorageService`), `lucide_icons` (already in project).

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/widgets/feedback_sheet.dart` | Two-step bottom sheet widget |
| Create | `lib/services/feedback_service.dart` | Firestore write + in_app_review trigger |
| Modify | `lib/services/storage_service.dart` | Add `feedbackAutoShown` flag (SharedPreferences) |
| Modify | `lib/providers/user_preferences_provider.dart` | Expose `feedbackAutoShown` getter + setter |
| Modify | `lib/screens/settings_screen.dart` | Add "Send Feedback" row in About card |
| Modify | `lib/screens/home_screen.dart` | Accept `onCategoryBreakdownTap` callback |
| Modify | `lib/screens/layout_screen.dart` | Milestone checks + show sheet helper |
| Modify | `pubspec.yaml` | Add `in_app_review` dependency |
| Modify | `test/services/storage_service_test.dart` | Tests for feedbackAutoShown flag |

---

## Task 1: Add `in_app_review` package

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

Open `pubspec.yaml`. Under `dependencies:`, add after the last dependency line:

```yaml
  in_app_review: ^2.0.9
```

- [ ] **Step 2: Install**

```
flutter pub get
```

Expected: resolves without conflicts.

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "chore: add in_app_review package"
```

---

## Task 2: StorageService — feedbackAutoShown flag

**Files:**
- Modify: `lib/services/storage_service.dart`
- Modify: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write the failing test**

Open `test/services/storage_service_test.dart`. Add after the existing `'onboarding flag'` group:

```dart
group('feedback auto shown flag', () {
  test('feedbackAutoShown is false by default', () {
    expect(storage.feedbackAutoShown, isFalse);
  });

  test('setFeedbackAutoShown persists true', () async {
    await storage.setFeedbackAutoShown();
    expect(storage.feedbackAutoShown, isTrue);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```
flutter test test/services/storage_service_test.dart
```

Expected: FAIL — `feedbackAutoShown` not defined on StorageService.

- [ ] **Step 3: Add key + getter + setter to StorageService**

In `lib/services/storage_service.dart`, add the key constant after `keyAvatarSeed`:

```dart
static const String keyFeedbackAutoShown = 'feedback_auto_shown';
```

Add the getter/setter after the `// ── Onboarding` section (or anywhere logical — keep it near SharedPreferences-based flags):

```dart
// ── Feedback ──────────────────────────────────────────────────────────
bool get feedbackAutoShown =>
    _prefs.getBool(keyFeedbackAutoShown) ?? false;

Future<void> setFeedbackAutoShown() =>
    _prefs.setBool(keyFeedbackAutoShown, true);
```

- [ ] **Step 4: Run test to verify it passes**

```
flutter test test/services/storage_service_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat: add feedbackAutoShown flag to StorageService"
```

---

## Task 3: Expose flag in UserPreferencesProvider

**Files:**
- Modify: `lib/providers/user_preferences_provider.dart`

- [ ] **Step 1: Add getter and setter**

In `lib/providers/user_preferences_provider.dart`, add after the `avatarSeed` getter:

```dart
bool get feedbackAutoShown => _storage.feedbackAutoShown;

Future<void> setFeedbackAutoShown() async {
  await _storage.setFeedbackAutoShown();
  notifyListeners();
}
```

- [ ] **Step 2: Verify no analysis errors**

```
flutter analyze lib/providers/user_preferences_provider.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/providers/user_preferences_provider.dart
git commit -m "feat: expose feedbackAutoShown in UserPreferencesProvider"
```

---

## Task 4: FeedbackService

**Files:**
- Create: `lib/services/feedback_service.dart`

- [ ] **Step 1: Create the file**

Create `lib/services/feedback_service.dart` with:

```dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_review/in_app_review.dart';

class FeedbackService {
  static Future<void> submitFeedback({
    required String message,
    required String trigger,
    required String userId,
    String appVersion = '1.0.0',
  }) async {
    await FirebaseFirestore.instance.collection('feedback').add({
      'message': message,
      'userId': userId,
      'trigger': trigger,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```
flutter analyze lib/services/feedback_service.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/services/feedback_service.dart
git commit -m "feat: add FeedbackService with Firestore write and in_app_review"
```

---

## Task 5: FeedbackSheet widget

**Files:**
- Create: `lib/widgets/feedback_sheet.dart`

- [ ] **Step 1: Create the file**

Create `lib/widgets/feedback_sheet.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/feedback_service.dart';

class FeedbackSheet extends StatefulWidget {
  final String trigger;
  const FeedbackSheet({super.key, required this.trigger});

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  bool _showTextStep = false;
  bool _submitting = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final userId =
        context.read<UserPreferencesProvider>().googleUid ?? 'offline';
    await FeedbackService.submitFeedback(
      message: text,
      trigger: widget.trigger,
      userId: userId,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onPositive() async {
    Navigator.of(context).pop();
    await FeedbackService.requestReview();
  }

  void _onNegative() => setState(() => _showTextStep = true);

  Widget _buildDragHandle(ColorScheme cs) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildStep1(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDragHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enjoying WLLT?',
                style: TextStyle(fontSize: 18, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Takes one tap',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SentimentButton(
                      icon: LucideIcons.thumbsUp,
                      label: 'Loving it',
                      background: cs.primaryContainer,
                      foreground: cs.onPrimaryContainer,
                      onTap: _onPositive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SentimentButton(
                      icon: LucideIcons.thumbsDown,
                      label: 'Not really',
                      background: cs.surfaceContainerHighest,
                      foreground: cs.onSurfaceVariant,
                      onTap: _onNegative,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(ColorScheme cs) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(cs),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What can we do better?',
                  style: TextStyle(fontSize: 18, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  'Goes directly to the developer',
                  style:
                      TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  minLines: 3,
                  maxLines: 5,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Tell us what's on your mind…",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Feedback'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: _showTextStep ? _buildStep2(cs) : _buildStep1(cs),
    );
  }
}

class _SentimentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _SentimentButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 24, color: foreground),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```
flutter analyze lib/widgets/feedback_sheet.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```
git add lib/widgets/feedback_sheet.dart
git commit -m "feat: add FeedbackSheet widget with two-step sentiment flow"
```

---

## Task 6: Settings — Send Feedback row

**Files:**
- Modify: `lib/screens/settings_screen.dart`

The current `_buildAboutCard` returns a `_SettingsCard` wrapping a single `Padding > Row`. Restructure it to a `Column` so a tappable feedback row can be appended below a divider.

- [ ] **Step 1: Add import**

At the top of `lib/screens/settings_screen.dart`, add after existing imports:

```dart
import '../widgets/feedback_sheet.dart';
```

- [ ] **Step 2: Add `_showFeedbackSheet` helper to `SettingsScreen`**

Inside `class SettingsScreen extends StatelessWidget`, add this method (e.g. after `_openCustomerCenter`):

```dart
void _showFeedbackSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const FeedbackSheet(trigger: 'manual'),
  );
}
```

- [ ] **Step 3: Restructure `_buildAboutCard`**

Replace the entire `_buildAboutCard` method with:

```dart
Widget _buildAboutCard(BuildContext context) {
  return _SettingsCard(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B2977), Color(0xFF6750A4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.wallet, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WLLT: Expense Tracker',
                    style: TextStyle(
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Built with ♥ using Flutter',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(
          height: 0.5,
          thickness: 0.5,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          indent: 16,
          endIndent: 16,
        ),
        _SettingsTappableRow(
          icon: LucideIcons.messageSquare,
          label: 'Send Feedback',
          onTap: () => _showFeedbackSheet(context),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Verify no analysis errors**

```
flutter analyze lib/screens/settings_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```
git add lib/screens/settings_screen.dart
git commit -m "feat: add Send Feedback row to Settings About card"
```

---

## Task 7: HomeScreen — insight milestone callback

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add `onCategoryBreakdownTap` parameter to `HomeScreen`**

In `lib/screens/home_screen.dart`, find `class HomeScreen extends StatefulWidget` and add the parameter:

```dart
class HomeScreen extends StatefulWidget {
  final DateTime selectedMonth;
  final void Function(int delta)? onMonthChanged;
  final VoidCallback? onNavigateToHistory;
  final ValueNotifier<bool>? pageScrollEnabled;
  final VoidCallback? onCategoryBreakdownTap;   // ADD THIS

  const HomeScreen({
    super.key,
    required this.selectedMonth,
    this.onMonthChanged,
    this.onNavigateToHistory,
    this.pageScrollEnabled,
    this.onCategoryBreakdownTap,               // ADD THIS
  });
  ...
}
```

- [ ] **Step 2: Wire the callback in the CategoryBreakdown GestureDetector**

Find the `GestureDetector` wrapping `_buildCategoryBreakdown` (around line 296 in home_screen.dart). Replace its `onTap`:

```dart
GestureDetector(
  onTap: widget.onCategoryBreakdownTap ?? () => Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => CategoryBreakdownScreen(
        selectedMonth: widget.selectedMonth,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  ),
  child: _buildCategoryBreakdown(categoryBreakdown, totalExpense, currencySymbol),
),
```

- [ ] **Step 3: Verify no analysis errors**

```
flutter analyze lib/screens/home_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```
git add lib/screens/home_screen.dart
git commit -m "feat: add onCategoryBreakdownTap callback to HomeScreen"
```

---

## Task 8: LayoutScreen — milestone wiring

**Files:**
- Modify: `lib/screens/layout_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/layout_screen.dart`, add:

```dart
import '../widgets/feedback_sheet.dart';
import '../screens/category_breakdown_screen.dart';
```

- [ ] **Step 2: Add transaction listener in `_LayoutScreenState`**

Add a field and override `initState` / `dispose` to attach a listener to `TransactionProvider`:

After `final ValueNotifier<bool> _pageScrollEnabled = ValueNotifier(true);`, add:

```dart
int _lastTxCount = 0;
```

Modify `initState` to add a post-frame listener:

```dart
@override
void initState() {
  super.initState();
  AdConfigService.instance.fetch();
  final now = DateTime.now();
  _selectedMonth = DateTime(now.year, now.month, 1);
  _pageController = PageController();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<TransactionProvider>().addListener(_checkTransactionMilestone);
  });
}
```

Modify `dispose` to remove the listener:

```dart
@override
void dispose() {
  context.read<TransactionProvider>().removeListener(_checkTransactionMilestone);
  _pageController.dispose();
  _pageScrollEnabled.dispose();
  super.dispose();
}
```

- [ ] **Step 3: Add milestone methods**

Add these three methods to `_LayoutScreenState` (e.g. after `_changeMonth`):

```dart
void _checkTransactionMilestone() {
  final prefs = context.read<UserPreferencesProvider>();
  if (prefs.feedbackAutoShown) return;
  final txCount = context.read<TransactionProvider>().transactions.length;
  if (txCount >= 10 && _lastTxCount < 10) {
    prefs.setFeedbackAutoShown();
    _showFeedbackSheet('transaction_milestone');
  }
  _lastTxCount = txCount;
}

Future<void> _handleCategoryBreakdownTap() async {
  final prefs = context.read<UserPreferencesProvider>();
  if (!prefs.feedbackAutoShown) {
    await prefs.setFeedbackAutoShown();
    await _showFeedbackSheet('insight_milestone');
  }
  if (!mounted) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => CategoryBreakdownScreen(
        selectedMonth: _selectedMonth,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

Future<void> _showFeedbackSheet(String trigger) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FeedbackSheet(trigger: trigger),
  );
}
```

- [ ] **Step 4: Pass `onCategoryBreakdownTap` to `HomeScreen`**

Find the `HomeScreen(...)` widget in the `PageView` children (around line 365). Add the new parameter:

```dart
HomeScreen(
  selectedMonth: _selectedMonth,
  onMonthChanged: _changeMonth,
  onNavigateToHistory: () => _navigateToTab(1),
  pageScrollEnabled: _pageScrollEnabled,
  onCategoryBreakdownTap: _handleCategoryBreakdownTap,
),
```

- [ ] **Step 5: Verify no analysis errors**

```
flutter analyze lib/screens/layout_screen.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```
git add lib/screens/layout_screen.dart
git commit -m "feat: wire feedback milestone checks and sheet trigger in LayoutScreen"
```

---

## Task 9: Full test run + final commit

- [ ] **Step 1: Run all tests**

```
flutter test
```

Expected: all existing tests pass.

- [ ] **Step 2: Analyze full project**

```
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Final commit if any loose files**

```
git status
```

If clean, no commit needed. Done.
