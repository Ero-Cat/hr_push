import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';

import '../../app_metadata.dart';
import '../../hr_notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../theme/design_system.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import '../hr_percent_help_page.dart';
import '../log_detail_page.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';
import 'settings_section_state.dart';

/// General section: heart-rate percent conversion range, logging, background
/// runtime, version.
class GeneralSettingsSection extends SettingsSectionWidget {
  const GeneralSettingsSection({
    super.key,
    required super.initial,
    super.onChanged,
  });

  @override
  State<GeneralSettingsSection> createState() => GeneralSettingsSectionState();
}

class GeneralSettingsSectionState extends State<GeneralSettingsSection>
    with SettingsSectionState<GeneralSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _minHrCtrl;
  late final TextEditingController _maxHrCtrl;
  bool _logEnabled = false;

  @override
  void initState() {
    super.initState();
    _minHrCtrl = fieldController(widget.initial.minHeartRate.toString());
    _maxHrCtrl = fieldController(widget.initial.maxHeartRate.toString());
    _logEnabled = widget.initial.logEnabled;
    listenToFields();
  }

  String? get _minHrError => SettingsValidator.minHeartRate(_minHrCtrl.text);
  String? get _maxHrError => SettingsValidator.maxHeartRate(_maxHrCtrl.text);

  /// Cross-field check that the conversion span is positive; only meaningful
  /// once both fields individually validate.
  String? get _hrRangeError {
    if (_minHrError != null || _maxHrError != null) return null;
    final min = int.tryParse(_minHrCtrl.text.trim());
    final max = int.tryParse(_maxHrCtrl.text.trim());
    if (min == null || max == null) return null;
    return SettingsValidator.hrRange(min, max);
  }

  @override
  List<String> validate() =>
      [_minHrError, _maxHrError, _hrRangeError].whereType<String>().toList();

  @override
  bool isDirty() =>
      (int.tryParse(_minHrCtrl.text.trim()) ?? -1) !=
          widget.initial.minHeartRate ||
      (int.tryParse(_maxHrCtrl.text.trim()) ?? -1) !=
          widget.initial.maxHeartRate ||
      _logEnabled != widget.initial.logEnabled;

  @override
  HeartRateSettings merge(HeartRateSettings settings) {
    return settings.copyWith(
      minHeartRate:
          int.tryParse(_minHrCtrl.text.trim()) ?? widget.initial.minHeartRate,
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
          controller: _minHrCtrl,
          label: l10n.fieldMinHr,
          keyboardType: TextInputType.number,
          errorKey: _minHrError,
        ),
        ValidatedField(
          controller: _maxHrCtrl,
          label: l10n.fieldMaxHr,
          keyboardType: TextInputType.number,
          errorKey: _maxHrError ?? _hrRangeError,
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          minimumSize: Size.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => HrPercentHelpPage(
                  minHeartRate:
                      int.tryParse(_minHrCtrl.text.trim()) ??
                      widget.initial.minHeartRate,
                  maxHeartRate:
                      int.tryParse(_maxHrCtrl.text.trim()) ??
                      widget.initial.maxHeartRate,
                ),
              ),
            );
          },
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.btnHrPercentHelp,
              style: AppTypography.subheadline.copyWith(
                color: AppColors.accent.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        CupertinoFormRow(
          prefix: Text(l10n.fieldEnableLogs),
          child: CupertinoSwitch(
            value: _logEnabled,
            activeTrackColor: AppColors.accent,
            onChanged: (v) => setState(() {
              _logEnabled = v;
              notifyFieldChanged();
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
