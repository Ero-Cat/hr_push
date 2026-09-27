import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/connection_tester.dart';
import '../../theme/design_system.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';
import 'settings_section_state.dart';

/// MQTT section: broker, port, TLS, credentials, last-will topic, test.
class MqttSettingsSection extends SettingsSectionWidget {
  const MqttSettingsSection({
    super.key,
    required super.initial,
    super.onChanged,
  });

  @override
  State<MqttSettingsSection> createState() => MqttSettingsSectionState();
}

class MqttSettingsSectionState extends State<MqttSettingsSection>
    with SettingsSectionState<MqttSettingsSection>
    implements SettingsSectionContract {
  late final TextEditingController _brokerCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _topicCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _clientIdCtrl;
  late final TextEditingController _lwtTopicCtrl;

  bool _useTls = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _brokerCtrl = fieldController(s.mqttBroker);
    _portCtrl = fieldController(s.mqttPort.toString());
    _topicCtrl = fieldController(s.mqttTopic);
    _usernameCtrl = fieldController(s.mqttUsername);
    _passwordCtrl = fieldController(s.mqttPassword);
    _clientIdCtrl = fieldController(s.mqttClientId);
    _lwtTopicCtrl = fieldController(s.mqttLwtTopic);
    _useTls = s.mqttUseTls;

    listenToFields();
  }

  String? get _portError => SettingsValidator.port(_portCtrl.text);

  @override
  List<String> validate() => [_portError].whereType<String>().toList();

  @override
  bool isDirty() {
    final s = widget.initial;
    return textDirty(_brokerCtrl, s.mqttBroker) ||
        textDirty(_portCtrl, s.mqttPort.toString()) ||
        textDirty(_topicCtrl, s.mqttTopic) ||
        textDirty(_usernameCtrl, s.mqttUsername) ||
        textDirty(_passwordCtrl, s.mqttPassword) ||
        textDirty(_clientIdCtrl, s.mqttClientId) ||
        textDirty(_lwtTopicCtrl, s.mqttLwtTopic) ||
        _useTls != s.mqttUseTls;
  }

  @override
  HeartRateSettings merge(HeartRateSettings settings) {
    return settings.copyWith(
      mqttBroker: _brokerCtrl.text.trim(),
      mqttPort: SettingsValidator.parsePort(
        _portCtrl.text,
        widget.initial.mqttPort,
      ),
      mqttTopic: _topicCtrl.text.trim(),
      mqttUsername: _usernameCtrl.text.trim(),
      mqttPassword: _passwordCtrl.text,
      mqttClientId: _clientIdCtrl.text.trim(),
      mqttUseTls: _useTls,
      mqttLwtTopic: _lwtTopicCtrl.text.trim(),
    );
  }

  HeartRateSettings _buildTestSettings() {
    return widget.initial.copyWith(
      mqttBroker: _brokerCtrl.text.trim(),
      mqttPort: SettingsValidator.parsePort(
        _portCtrl.text,
        widget.initial.mqttPort,
      ),
      mqttUsername: _usernameCtrl.text.trim(),
      mqttPassword: _passwordCtrl.text,
      mqttUseTls: _useTls,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final broker = _brokerCtrl.text.trim();
    final canTest = broker.isNotEmpty && _portError == null;

    return SettingsSectionContainer(
      header: l10n.sectionMqtt,
      children: [
        ValidatedField(
          controller: _brokerCtrl,
          label: l10n.fieldBroker,
          placeholder: 'broker.hivemq.com',
        ),
        ValidatedField(
          controller: _portCtrl,
          label: l10n.fieldPort,
          keyboardType: TextInputType.number,
          errorKey: _portError,
        ),
        CupertinoFormRow(
          prefix: Text(l10n.fieldMqttTls),
          child: CupertinoSwitch(
            value: _useTls,
            activeTrackColor: AppColors.accent,
            onChanged: (v) => setState(() {
              _useTls = v;
              notifyFieldChanged();
            }),
          ),
        ),
        ValidatedField(controller: _topicCtrl, label: l10n.fieldTopic),
        ValidatedField(controller: _usernameCtrl, label: l10n.fieldUsername),
        ValidatedField(
          controller: _passwordCtrl,
          label: l10n.fieldPassword,
          obscureText: _obscurePassword,
          suffix: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Semantics(
              label: l10n.showPassword,
              button: true,
              child: Icon(
                _obscurePassword
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                size: 18,
                color: AppColors.textTertiary.resolveFrom(context),
              ),
            ),
          ),
        ),
        ValidatedField(
          controller: _clientIdCtrl,
          label: l10n.fieldClientId,
          hintKey: 'hintClientId',
        ),
        ValidatedField(
          controller: _lwtTopicCtrl,
          label: l10n.fieldMqttLwtTopic,
          hintKey: 'hintMqttLwt',
        ),
        ConnectionTestRow(
          label: l10n.btnTest,
          enabled: canTest,
          run: () => ConnectionTester.testMqtt(_buildTestSettings()),
        ),
      ],
    );
  }
}
