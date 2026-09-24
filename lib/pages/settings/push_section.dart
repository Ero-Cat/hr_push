import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/connection_tester.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';

/// HTTP/WebSocket push section: endpoint, publish interval, test button.
class PushSettingsSection extends StatefulWidget {
  const PushSettingsSection({super.key, required this.initial, this.onChanged});

  final HeartRateSettings initial;
  final VoidCallback? onChanged;

  @override
  State<PushSettingsSection> createState() => PushSettingsSectionState();
}

class PushSettingsSectionState extends State<PushSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _intervalCtrl;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = TextEditingController(text: widget.initial.pushEndpoint);
    _intervalCtrl = TextEditingController(
      text: widget.initial.updateIntervalMs.toString(),
    );
    _endpointCtrl.addListener(_notifyChanged);
    _intervalCtrl.addListener(_notifyChanged);
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    // Rebuild this section so inline validation errors update live; the
    // page shell separately tracks the dirty flag.
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  String? get _endpointError =>
      SettingsValidator.pushEndpoint(_endpointCtrl.text);
  String? get _intervalError =>
      SettingsValidator.updateIntervalMs(_intervalCtrl.text);

  @override
  List<String> validate() {
    return [_endpointError, _intervalError].whereType<String>().toList();
  }

  @override
  bool isDirty() =>
      _endpointCtrl.text.trim() != widget.initial.pushEndpoint ||
      (int.tryParse(_intervalCtrl.text.trim()) ?? -1) !=
          widget.initial.updateIntervalMs;

  @override
  HeartRateSettings merge(HeartRateSettings settings) {
    return settings.copyWith(
      pushEndpoint: _endpointCtrl.text.trim(),
      updateIntervalMs:
          int.tryParse(_intervalCtrl.text.trim()) ??
          widget.initial.updateIntervalMs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final endpoint = _endpointCtrl.text.trim();
    final canTest = endpoint.isNotEmpty && _endpointError == null;
    final isWs = endpoint.startsWith('ws');

    return SettingsSectionContainer(
      header: l10n.sectionWebHttp,
      children: [
        ValidatedField(
          controller: _endpointCtrl,
          label: l10n.fieldEndpoint,
          placeholder: 'http:// or ws://',
          errorKey: _endpointError,
        ),
        ValidatedField(
          controller: _intervalCtrl,
          label: l10n.fieldInterval,
          keyboardType: TextInputType.number,
          errorKey: _intervalError,
        ),
        ConnectionTestRow(
          label: l10n.btnTest,
          enabled: canTest,
          run: () => isWs
              ? ConnectionTester.testWebSocket(endpoint)
              : ConnectionTester.testHttp(endpoint),
        ),
      ],
    );
  }
}
