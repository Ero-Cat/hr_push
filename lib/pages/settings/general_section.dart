import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';

import '../../app_metadata.dart';
import '../../hr_notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../theme/design_system.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import '../log_detail_page.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';

/// General section: max heart rate, logging, background runtime, version.
class GeneralSettingsSection extends StatefulWidget {
  const GeneralSettingsSection({
    super.key,
    required this.initial,
    this.onChanged,
  });

  final HeartRateSettings initial;
  final VoidCallback? onChanged;

  @override
  State<GeneralSettingsSection> createState() => GeneralSettingsSectionState();
}

class GeneralSettingsSectionState extends State<GeneralSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _maxHrCtrl;
  bool _logEnabled = false;

  @override
  void initState() {
    super.initState();
    _maxHrCtrl = TextEditingController(
      text: widget.initial.maxHeartRate.toString(),
    );
    _logEnabled = widget.initial.logEnabled;
    _maxHrCtrl.addListener(_notifyChanged);
  }

  @override
  void dispose() {
    _maxHrCtrl.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    // Rebuild this section so inline validation errors update live; the
    // page shell separately tracks the dirty flag.
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  String? get _maxHrError => SettingsValidator.maxHeartRate(_maxHrCtrl.text);

  @override
  List<String> validate() => [_maxHrError].whereType<String>().toList();

  @override
  bool isDirty() =>
      (int.tryParse(_maxHrCtrl.text.trim()) ?? -1) !=
          widget.initial.maxHeartRate ||
      _logEnabled != widget.initial.logEnabled;

  @override
  HeartRateSettings merge(HeartRateSettings settings) {
    return settings.copyWith(
      maxHeartRate:
          int.tryParse(_maxHrCtrl.text.trim()) ?? widget.initial.maxHeartRate,
      logEnabled: _logEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSectionContainer(
      header: l10n.sectionGeneral,
      children: [
        ValidatedField(
          controller: _maxHrCtrl,
          label: l10n.fieldMaxHr,
          keyboardType: TextInputType.number,
          errorKey: _maxHrError,
        ),
        CupertinoFormRow(
          prefix: Text(l10n.fieldEnableLogs),
          child: CupertinoSwitch(
            value: _logEnabled,
            activeTrackColor: AppColors.accent,
            onChanged: (v) => setState(() {
              _logEnabled = v;
              widget.onChanged?.call();
            }),
          ),
        ),
        if (_logEnabled)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            minimumSize: Size.zero,
            onPressed: () {
              Navigator.of(
                context,
              ).push(CupertinoPageRoute(builder: (_) => const LogDetailPage()));
            },
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.btnViewLogs,
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.accent.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (Platform.isAndroid)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            minimumSize: Size.zero,
            onPressed: () async {
              await HrNotificationService().openBackgroundRuntimeSettings();
            },
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.btnBackgroundRuntime,
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.accent.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Center(
            child: Text(
              'v$appVersion',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary.resolveFrom(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
