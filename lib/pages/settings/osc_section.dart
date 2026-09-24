import 'package:flutter/cupertino.dart';

import '../../heart_rate_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/connection_tester.dart';
import '../../services/push_coordinator.dart';
import '../../theme/design_system.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';

/// VRChat OSC section: target address, test button, advanced parameter paths
/// behind progressive disclosure, ChatBox options, and the live OSC status.
class OscSettingsSection extends StatefulWidget {
  const OscSettingsSection({
    super.key,
    required this.initial,
    this.manager,
    this.onChanged,
  });

  final HeartRateSettings initial;
  final HeartRateManager? manager;
  final VoidCallback? onChanged;

  @override
  State<OscSettingsSection> createState() => OscSettingsSectionState();
}

class OscSettingsSectionState extends State<OscSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _connectedCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _percentCtrl;
  late final TextEditingController _heartbeatIntCtrl;
  late final TextEditingController _heartbeatPulseCtrl;
  late final TextEditingController _heartbeatToggleCtrl;
  late final TextEditingController _pulseDurationCtrl;
  late final TextEditingController _chatboxTemplateCtrl;

  bool _advancedExpanded = false;
  bool _heartbeatIntEnabled = false;
  bool _heartbeatPulseEnabled = false;
  bool _heartbeatToggleEnabled = false;
  bool _chatboxEnabled = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _addressCtrl = TextEditingController(text: s.oscAddress);
    _connectedCtrl = TextEditingController(text: s.oscHrConnectedPath);
    _valueCtrl = TextEditingController(text: s.oscHrValuePath);
    _percentCtrl = TextEditingController(text: s.oscHrPercentPath);
    _heartbeatIntCtrl = TextEditingController(text: s.oscHeartbeatIntPath);
    _heartbeatPulseCtrl = TextEditingController(text: s.oscHeartbeatPulsePath);
    _heartbeatToggleCtrl = TextEditingController(
      text: s.oscHeartbeatTogglePath,
    );
    _pulseDurationCtrl = TextEditingController(
      text: s.oscHeartbeatPulseDurationMs.toString(),
    );
    _chatboxTemplateCtrl = TextEditingController(text: s.oscChatboxTemplate);

    _heartbeatIntEnabled = s.oscHeartbeatIntEnabled;
    _heartbeatPulseEnabled = s.oscHeartbeatPulseEnabled;
    _heartbeatToggleEnabled = s.oscHeartbeatToggleEnabled;
    _chatboxEnabled = s.oscChatboxEnabled;

    for (final c in _controllers) {
      c.addListener(_notifyChanged);
    }
  }

  List<TextEditingController> get _controllers => [
    _addressCtrl,
    _connectedCtrl,
    _valueCtrl,
    _percentCtrl,
    _heartbeatIntCtrl,
    _heartbeatPulseCtrl,
    _heartbeatToggleCtrl,
    _pulseDurationCtrl,
    _chatboxTemplateCtrl,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifyChanged() {
    // Rebuild this section so inline validation errors update live; the
    // page shell separately tracks the dirty flag.
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  String? get _addressError => SettingsValidator.oscAddress(_addressCtrl.text);

  String? _pathError(TextEditingController c) =>
      SettingsValidator.oscPath(c.text);

  String? get _pulseDurationError =>
      SettingsValidator.heartbeatPulseDurationMs(_pulseDurationCtrl.text);

  @override
  List<String> validate() {
    return [
      _addressError,
      _pathError(_connectedCtrl),
      _pathError(_valueCtrl),
      _pathError(_percentCtrl),
      _pathError(_heartbeatIntCtrl),
      _pathError(_heartbeatPulseCtrl),
      _pathError(_heartbeatToggleCtrl),
      _pulseDurationError,
    ].whereType<String>().toList();
  }

  bool _textDirty(TextEditingController c, String initial) =>
      c.text.trim() != initial;

  @override
  bool isDirty() {
    final s = widget.initial;
    return _textDirty(_addressCtrl, s.oscAddress) ||
        _textDirty(_connectedCtrl, s.oscHrConnectedPath) ||
        _textDirty(_valueCtrl, s.oscHrValuePath) ||
        _textDirty(_percentCtrl, s.oscHrPercentPath) ||
        _textDirty(_heartbeatIntCtrl, s.oscHeartbeatIntPath) ||
        _textDirty(_heartbeatPulseCtrl, s.oscHeartbeatPulsePath) ||
        _textDirty(_heartbeatToggleCtrl, s.oscHeartbeatTogglePath) ||
        _textDirty(
          _pulseDurationCtrl,
          s.oscHeartbeatPulseDurationMs.toString(),
        ) ||
        _textDirty(_chatboxTemplateCtrl, s.oscChatboxTemplate) ||
        _heartbeatIntEnabled != s.oscHeartbeatIntEnabled ||
        _heartbeatPulseEnabled != s.oscHeartbeatPulseEnabled ||
        _heartbeatToggleEnabled != s.oscHeartbeatToggleEnabled ||
        _chatboxEnabled != s.oscChatboxEnabled;
  }

  @override
  HeartRateSettings merge(HeartRateSettings settings) {
    final pulse = int.tryParse(_pulseDurationCtrl.text.trim());
    return settings.copyWith(
      oscAddress: _addressCtrl.text.trim(),
      oscHrConnectedPath: _connectedCtrl.text.trim(),
      oscHrValuePath: _valueCtrl.text.trim(),
      oscHrPercentPath: _percentCtrl.text.trim(),
      oscHeartbeatIntPath: _heartbeatIntCtrl.text.trim(),
      oscHeartbeatPulsePath: _heartbeatPulseCtrl.text.trim(),
      oscHeartbeatTogglePath: _heartbeatToggleCtrl.text.trim(),
      oscHeartbeatIntEnabled: _heartbeatIntEnabled,
      oscHeartbeatPulseEnabled: _heartbeatPulseEnabled,
      oscHeartbeatToggleEnabled: _heartbeatToggleEnabled,
      oscHeartbeatPulseDurationMs: pulse != null && pulse >= 20 && pulse <= 1000
          ? pulse
          : widget.initial.oscHeartbeatPulseDurationMs,
      oscChatboxEnabled: _chatboxEnabled,
      oscChatboxTemplate: _chatboxTemplateCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final address = _addressCtrl.text.trim();
    final canTest = address.isNotEmpty && _addressError == null;

    return SettingsSectionContainer(
      header: l10n.sectionVrchatOsc,
      children: [
        ValidatedField(
          controller: _addressCtrl,
          label: l10n.fieldAddress,
          placeholder: '127.0.0.1:9000',
          errorKey: _addressError,
          hintKey: _addressError == null ? 'hintOscEmpty' : null,
          suffix: _addressCtrl.text.trim().isEmpty
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    _addressCtrl.text = '127.0.0.1:9000';
                  },
                  child: Text(
                    l10n.btnFillDefault,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accent.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
        ConnectionTestRow(
          label: l10n.btnTest,
          enabled: canTest,
          run: () => ConnectionTester.testOsc(address),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.info,
                size: 14,
                color: AppColors.textTertiary.resolveFrom(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.hintOscNote,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.manager != null)
          AnimatedBuilder(
            animation: widget.manager!,
            builder: (context, child) =>
                _OscStatusChip(status: widget.manager!.oscStatus),
          ),
        CupertinoFormRow(
          prefix: Text(l10n.sectionOscChatbox),
          child: CupertinoSwitch(
            value: _chatboxEnabled,
            activeTrackColor: AppColors.accent,
            onChanged: (v) => setState(() {
              _chatboxEnabled = v;
              widget.onChanged?.call();
            }),
          ),
        ),
        if (_chatboxEnabled)
          ValidatedField(
            controller: _chatboxTemplateCtrl,
            label: l10n.fieldTemplate,
            placeholder: '💓{hr}',
          ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          minimumSize: Size.zero,
          onPressed: () =>
              setState(() => _advancedExpanded = !_advancedExpanded),
          child: Row(
            children: [
              Icon(
                _advancedExpanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 14,
                color: AppColors.accent.resolveFrom(context),
              ),
              const SizedBox(width: 6),
              Text(
                _advancedExpanded ? l10n.hideAdvanced : l10n.showAdvanced,
                style: AppTypography.subheadline.copyWith(
                  color: AppColors.accent.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_advancedExpanded) ..._buildAdvancedFields(context, l10n),
      ],
    );
  }

  List<Widget> _buildAdvancedFields(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      ValidatedField(
        controller: _connectedCtrl,
        label: l10n.fieldConnectedParam,
        errorKey: _pathError(_connectedCtrl),
      ),
      ValidatedField(
        controller: _valueCtrl,
        label: l10n.fieldHrValueParam,
        errorKey: _pathError(_valueCtrl),
      ),
      ValidatedField(
        controller: _percentCtrl,
        label: l10n.fieldHrPercentParam,
        errorKey: _pathError(_percentCtrl),
      ),
      _buildToggle(
        context,
        label: l10n.fieldHeartbeatInt,
        value: _heartbeatIntEnabled,
        onChanged: (v) => setState(() {
          _heartbeatIntEnabled = v;
          widget.onChanged?.call();
        }),
      ),
      if (_heartbeatIntEnabled)
        ValidatedField(
          controller: _heartbeatIntCtrl,
          label: l10n.fieldHeartbeatIntPath,
          errorKey: _pathError(_heartbeatIntCtrl),
        ),
      _buildToggle(
        context,
        label: l10n.fieldHeartbeatPulse,
        value: _heartbeatPulseEnabled,
        onChanged: (v) => setState(() {
          _heartbeatPulseEnabled = v;
          widget.onChanged?.call();
        }),
      ),
      if (_heartbeatPulseEnabled)
        ValidatedField(
          controller: _heartbeatPulseCtrl,
          label: l10n.fieldHeartbeatPulsePath,
          errorKey: _pathError(_heartbeatPulseCtrl),
        ),
      _buildToggle(
        context,
        label: l10n.fieldHeartbeatToggle,
        value: _heartbeatToggleEnabled,
        onChanged: (v) => setState(() {
          _heartbeatToggleEnabled = v;
          widget.onChanged?.call();
        }),
      ),
      if (_heartbeatToggleEnabled)
        ValidatedField(
          controller: _heartbeatToggleCtrl,
          label: l10n.fieldHeartbeatTogglePath,
          errorKey: _pathError(_heartbeatToggleCtrl),
        ),
      ValidatedField(
        controller: _pulseDurationCtrl,
        label: l10n.fieldHeartbeatDuration,
        keyboardType: TextInputType.number,
        errorKey: _pulseDurationError,
      ),
    ];
  }

  Widget _buildToggle(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CupertinoFormRow(
      prefix: Text(label),
      child: CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// Live OSC push status, rendered from the manager's OscStatus.
class _OscStatusChip extends StatelessWidget {
  const _OscStatusChip({required this.status});

  final OscStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status.state) {
      OscSendState.disabled => (l10n.oscStatusDisabled, AppColors.textTertiary),
      OscSendState.ready => (l10n.oscStatusReady, AppColors.textSecondary),
      OscSendState.sent => (l10n.oscStatusSent, AppColors.warning),
      OscSendState.acknowledged => (
        l10n.oscStatusAcknowledged,
        AppColors.success,
      ),
      OscSendState.error => (l10n.oscStatusError, AppColors.danger),
    };
    final resolved = CupertinoDynamicColor.resolve(color, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: resolved.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.r12),
          border: Border.all(color: resolved.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: resolved,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${l10n.oscStatusTitle}: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: resolved,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
