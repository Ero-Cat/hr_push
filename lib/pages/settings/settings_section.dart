import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_keys.dart';
import '../../services/connection_tester.dart';
import '../../theme/design_system.dart';

/// Shared building blocks for settings sections.

/// Rounded grouped section container matching the app's form style.
class SettingsSectionContainer extends StatelessWidget {
  const SettingsSectionContainer({
    super.key,
    required this.header,
    required this.children,
    this.footer,
  });

  final String header;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: Text(header.toUpperCase()),
      backgroundColor: AppColors.bgPrimary,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      children: children,
    );
  }
}

/// Inline async test row: runs a probe and reports the outcome.
class ConnectionTestRow extends StatefulWidget {
  const ConnectionTestRow({
    super.key,
    required this.label,
    required this.enabled,
    required this.run,
  });

  final String label;
  final bool enabled;
  final Future<ConnectionTestResult> Function() run;

  @override
  State<ConnectionTestRow> createState() => _ConnectionTestRowState();
}

class _ConnectionTestRowState extends State<ConnectionTestRow> {
  bool _running = false;
  ConnectionTestResult? _result;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
    });
    final result = await widget.run();
    if (mounted) {
      setState(() {
        _running = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            minimumSize: Size.zero,
            disabledColor: AppColors.bgTertiary
                .resolveFrom(context)
                .withValues(alpha: 0.6),
            color: AppColors.accent
                .resolveFrom(context)
                .withValues(alpha: widget.enabled ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(AppRadius.r12),
            onPressed: widget.enabled && !_running ? _run : null,
            child: _running
                ? const CupertinoActivityIndicator(radius: 8)
                : Text(
                    widget.label,
                    style: AppTypography.subheadline.copyWith(
                      color: widget.enabled
                          ? AppColors.accent.resolveFrom(context)
                          : AppColors.textTertiary.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          if (result != null)
            Expanded(
              child: Row(
                children: [
                  Icon(
                    result.isOk
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.xmark_circle_fill,
                    size: 16,
                    color: result.isOk
                        ? AppColors.success.resolveFrom(context)
                        : AppColors.danger.resolveFrom(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${resolveL10nKey(l10n, result.isOk ? 'testSuccess' : 'testFailed')}: ${result.detail}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
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
