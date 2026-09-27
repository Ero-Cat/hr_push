import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/connection_tester.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';
import 'settings_section_state.dart';

/// HTTP/WebSocket push section: endpoint, publish interval, test button.
class PushSettingsSection extends SettingsSectionWidget {
  const PushSettingsSection({
    super.key,
    required super.initial,
    super.onChanged,
  });

  @override
  State<PushSettingsSection> createState() => PushSettingsSectionState();
}

class PushSettingsSectionState extends State<PushSettingsSection>
    with SettingsSectionState<PushSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _intervalCtrl;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = fieldController(widget.initial.pushEndpoint);
    _intervalCtrl = fieldController(widget.initial.updateIntervalMs.toString());
    listenToFields();
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
      textDirty(_endpointCtrl, widget.initial.pushEndpoint) ||
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
