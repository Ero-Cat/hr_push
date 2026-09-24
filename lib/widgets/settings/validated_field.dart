import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_keys.dart';
import '../../theme/design_system.dart';

/// CupertinoFormRow with an inline error or hint slot under the input.
///
/// [errorKey]/[hintKey] are message keys resolved via [resolveL10nKey];
/// a non-null errorKey marks the field invalid (red message).
class ValidatedField extends StatelessWidget {
  const ValidatedField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.errorKey,
    this.hintKey,
    this.onChanged,
    this.suffix,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorKey;
  final String? hintKey;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasError = errorKey != null;
    final hintText = hintKey == null ? null : resolveL10nKey(l10n, hintKey!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoFormRow(
          prefix: Text(label),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  placeholder: placeholder,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  textAlign: TextAlign.end,
                  maxLines: maxLines,
                  decoration: null,
                  onChanged: onChanged,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary.resolveFrom(context),
                  ),
                  placeholderStyle: AppTypography.body.copyWith(
                    color: AppColors.textTertiary.resolveFrom(context),
                  ),
                ),
              ),
              if (suffix != null) ...[const SizedBox(width: 8), suffix!],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: 20,
            end: 20,
            bottom: hasError || hintText != null ? 8 : 0,
          ),
          child: hasError
              ? Text(
                  resolveL10nKey(l10n, errorKey!),
                  style: AppTypography.caption.copyWith(
                    color: CupertinoDynamicColor.resolve(
                      AppColors.danger,
                      context,
                    ),
                  ),
                )
              : hintText != null
              ? Text(
                  hintText,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary.resolveFrom(context),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
