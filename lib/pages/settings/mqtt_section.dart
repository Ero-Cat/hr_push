import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/connection_tester.dart';
import '../../theme/design_system.dart';
import '../../utils/settings_validator.dart';
import '../../widgets/settings/validated_field.dart';
import 'settings_section.dart';
import 'settings_section_contract.dart';

/// MQTT section: broker, port, TLS, credentials, last-will topic, test.
class MqttSettingsSection extends StatefulWidget {
  const MqttSettingsSection({super.key, required this.initial, this.onChanged});

  final HeartRateSettings initial;
  final VoidCallback? onChanged;

  @override
  State<MqttSettingsSection> createState() => MqttSettingsSectionState();
}

class MqttSettingsSectionState extends State<MqttSettingsSection>
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
    _brokerCtrl = TextEditingController(text: s.mqttBroker);
    _portCtrl = TextEditingController(text: s.mqttPort.toString());
    _topicCtrl = TextEditingController(text: s.mqttTopic);
    _usernameCtrl = TextEditingController(text: s.mqttUsername);
    _passwordCtrl = TextEditingController(text: s.mqttPassword);
    _clientIdCtrl = TextEditingController(text: s.mqttClientId);
    _lwtTopicCtrl = TextEditingController(text: s.mqttLwtTopic);
    _useTls = s.mqttUseTls;

    for (final c in _controllers) {
      c.addListener(_notifyChanged);
    }
  }

  List<TextEditingController> get _controllers => [
    _brokerCtrl,
    _portCtrl,
    _topicCtrl,
    _usernameCtrl,
    _passwordCtrl,
    _clientIdCtrl,
    _lwtTopicCtrl,
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

  String? get _portError => SettingsValidator.port(_portCtrl.text);

  @override
  List<String> validate() => [_portError].whereType<String>().toList();

  bool _textDirty(TextEditingController c, String initial) =>
      c.text.trim() != initial;

  @override
  bool isDirty() {
    final s = widget.initial;
    return _textDirty(_brokerCtrl, s.mqttBroker) ||
        _textDirty(_portCtrl, s.mqttPort.toString()) ||
        _textDirty(_topicCtrl, s.mqttTopic) ||
        _textDirty(_usernameCtrl, s.mqttUsername) ||
        _textDirty(_passwordCtrl, s.mqttPassword) ||
        _textDirty(_clientIdCtrl, s.mqttClientId) ||
        _textDirty(_lwtTopicCtrl, s.mqttLwtTopic) ||
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
              widget.onChanged?.call();
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
