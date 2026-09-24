import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../theme/design_system.dart';

/// First-run onboarding: permissions → connect device (with the Xiaomi
/// heart-rate-broadcast hint) → push setup.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onFinished});

  /// Called with true when the user finished (or skipped) onboarding.
  final ValueChanged<bool> onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCirc,
      );
    } else {
      widget.onFinished(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLast = _page == _pageCount - 1;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CupertinoButton(
                padding: const EdgeInsets.all(16),
                onPressed: () => widget.onFinished(false),
                child: Text(
                  l10n.onbSkip,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  _OnboardingStep(
                    icon: CupertinoIcons.heart_fill,
                    title: l10n.onbTitle1,
                    body: l10n.onbBody1,
                  ),
                  _OnboardingStep(
                    icon: CupertinoIcons.antenna_radiowaves_left_right,
                    title: l10n.onbTitle2,
                    body: l10n.onbBody2,
                  ),
                  _OnboardingStep(
                    icon: CupertinoIcons.paperplane_fill,
                    title: l10n.onbTitle3,
                    body: l10n.onbBody3,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pageCount; i++)
                  Container(
                    width: i == _page ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.accent.resolveFrom(context)
                          : AppColors.separator.resolveFrom(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _next,
                  child: Text(
                    isLast ? l10n.onbDone : l10n.onbNext,
                    style: AppTypography.headline.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.accent
                  .resolveFrom(context)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.accent.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title1.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              height: 1.5,
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
