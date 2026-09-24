import 'package:flutter/cupertino.dart';

import '../heart_rate_manager.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_keys.dart';
import '../models/models.dart';
import '../theme/design_system.dart';
import '../widgets/settings/settings_toast.dart';
import 'settings/general_section.dart';
import 'settings/mqtt_section.dart';
import 'settings/osc_section.dart';
import 'settings/push_section.dart';
import 'settings/settings_section_contract.dart';

/// Settings page shell: owns save/dirty handling and composes the protocol
/// sections (each section validates its own fields).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial, this.manager});

  final HeartRateSettings initial;
  final HeartRateManager? manager;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _pushKey = GlobalKey<PushSettingsSectionState>();
  final _oscKey = GlobalKey<OscSettingsSectionState>();
  final _mqttKey = GlobalKey<MqttSettingsSectionState>();
  final _generalKey = GlobalKey<GeneralSettingsSectionState>();

  bool _dirty = false;

  void _onSectionChanged() {
    final dirty = _allSections.any((s) => s.isDirty());
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  /// Sections that have been built. Sections below the fold of the lazy
  /// ListView are absent — untouched fields equal the initial settings, so
  /// they cannot be dirty or invalid.
  List<SettingsSectionContract> get _allSections => [
    _pushKey.currentState,
    _oscKey.currentState,
    _mqttKey.currentState,
    _generalKey.currentState,
  ].whereType<SettingsSectionContract>().toList();

  Future<void> _onSave() async {
    final l10n = AppLocalizations.of(context)!;
    final errors = <String>[
      for (final section in _allSections) ...section.validate(),
    ];
    if (errors.isNotEmpty) {
      showSettingsToast(
        context,
        resolveL10nKey(l10n, 'fixErrorsBeforeSave'),
        isError: true,
      );
      return;
    }

    var settings = widget.initial;
    for (final section in _allSections) {
      settings = section.merge(settings);
    }

    setState(() => _dirty = false);
    showSettingsToast(context, resolveL10nKey(l10n, 'savedToast'));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.of(context).pop(settings);
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.unsavedTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.unsavedBody),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            isDefaultAction: true,
            child: Text(l10n.unsavedKeepEditing),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            isDestructiveAction: true,
            child: Text(l10n.unsavedDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (!mounted) return;
        if (discard) navigator.pop();
      },
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.bgPrimary,
        navigationBar: CupertinoNavigationBar(
          middle: Text(l10n.settingsTitle),
          previousPageTitle: l10n.back,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _onSave,
            child: Text(
              l10n.save,
              style: _dirty
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : const TextStyle(),
            ),
          ),
        ),
        child: SafeArea(
          child: ListView(
            children: [
              PushSettingsSection(
                key: _pushKey,
                initial: widget.initial,
                onChanged: _onSectionChanged,
              ),
              OscSettingsSection(
                key: _oscKey,
                initial: widget.initial,
                manager: widget.manager,
                onChanged: _onSectionChanged,
              ),
              MqttSettingsSection(
                key: _mqttKey,
                initial: widget.initial,
                onChanged: _onSectionChanged,
              ),
              GeneralSettingsSection(
                key: _generalKey,
                initial: widget.initial,
                onChanged: _onSectionChanged,
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
