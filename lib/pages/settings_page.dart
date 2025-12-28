
import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';
import '../heart_rate_manager.dart';
import '../theme/design_system.dart';
import 'log_detail_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial});

  final HeartRateSettings initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Controllers
  late final TextEditingController _pushCtrl;
  late final TextEditingController _oscCtrl;
  late final TextEditingController _oscConnectedCtrl;
  late final TextEditingController _oscValueCtrl;
  late final TextEditingController _oscPercentCtrl;
  late final TextEditingController _oscChatboxTemplateCtrl;
  late final TextEditingController _maxHrCtrl;
  late final TextEditingController _intervalCtrl;
  late final TextEditingController _mqttBrokerCtrl;
  late final TextEditingController _mqttPortCtrl;
  late final TextEditingController _mqttTopicCtrl;
  late final TextEditingController _mqttUsernameCtrl;
  late final TextEditingController _mqttPasswordCtrl;
  late final TextEditingController _mqttClientIdCtrl;
  
  bool _oscChatboxEnabled = false;
  bool _logEnabled = false;

  @override
  void initState() {
    super.initState();
    // Initialize with values
    _pushCtrl = TextEditingController(text: widget.initial.pushEndpoint);
    _oscCtrl = TextEditingController(text: widget.initial.oscAddress);
    _oscConnectedCtrl = TextEditingController(text: widget.initial.oscHrConnectedPath);
    _oscValueCtrl = TextEditingController(text: widget.initial.oscHrValuePath);
    _oscPercentCtrl = TextEditingController(text: widget.initial.oscHrPercentPath);
    _oscChatboxTemplateCtrl = TextEditingController(text: widget.initial.oscChatboxTemplate);
    _maxHrCtrl = TextEditingController(text: widget.initial.maxHeartRate.toString());
    _intervalCtrl = TextEditingController(text: widget.initial.updateIntervalMs.toString());
    
    _oscChatboxEnabled = widget.initial.oscChatboxEnabled;
    _logEnabled = widget.initial.logEnabled;

    _mqttBrokerCtrl = TextEditingController(text: widget.initial.mqttBroker);
    _mqttPortCtrl = TextEditingController(text: widget.initial.mqttPort.toString());
    _mqttTopicCtrl = TextEditingController(text: widget.initial.mqttTopic);
    _mqttUsernameCtrl = TextEditingController(text: widget.initial.mqttUsername);
    _mqttPasswordCtrl = TextEditingController(text: widget.initial.mqttPassword);
    _mqttClientIdCtrl = TextEditingController(text: widget.initial.mqttClientId);
    
    // Set defaults if empty
    if (_oscCtrl.text.isEmpty) _oscCtrl.text = '127.0.0.1:9000';
    if (_mqttTopicCtrl.text.isEmpty) _mqttTopicCtrl.text = 'hr_push';
    if (_oscConnectedCtrl.text.isEmpty) _oscConnectedCtrl.text = '/avatar/parameters/hr_connected';
    if (_oscValueCtrl.text.isEmpty) _oscValueCtrl.text = '/avatar/parameters/hr_val';
    if (_oscPercentCtrl.text.isEmpty) _oscPercentCtrl.text = '/avatar/parameters/hr_percent';
    if (_oscChatboxTemplateCtrl.text.isEmpty) _oscChatboxTemplateCtrl.text = '💓{hr}';
  }

  @override
  void dispose() {
    _pushCtrl.dispose();
    _oscCtrl.dispose();
    _oscConnectedCtrl.dispose();
    _oscValueCtrl.dispose();
    _oscPercentCtrl.dispose();
    _oscChatboxTemplateCtrl.dispose();
    _maxHrCtrl.dispose();
    _intervalCtrl.dispose();
    _mqttBrokerCtrl.dispose();
    _mqttPortCtrl.dispose();
    _mqttTopicCtrl.dispose();
    _mqttUsernameCtrl.dispose();
    _mqttPasswordCtrl.dispose();
    _mqttClientIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsTitle),
        previousPageTitle: l10n.back,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onSave,
          child: Text(l10n.save),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            _buildSection(
              header: l10n.sectionWebHttp,
              children: [
                _buildInput(
                  controller: _pushCtrl,
                  label: l10n.fieldEndpoint,
                  placeholder: 'http:// or ws://',
                ),
                _buildInput(
                  controller: _intervalCtrl,
                  label: l10n.fieldInterval,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            
            _buildSection(
              header: l10n.sectionVrchatOsc,
              children: [
                _buildInput(controller: _oscCtrl, label: l10n.fieldAddress, placeholder: '127.0.0.1:9000'),
                _buildInput(controller: _oscConnectedCtrl, label: l10n.fieldConnectedParam),
                _buildInput(controller: _oscValueCtrl, label: l10n.fieldHrValueParam),
                _buildInput(controller: _oscPercentCtrl, label: l10n.fieldHrPercentParam),
                _buildInput(controller: _maxHrCtrl, label: l10n.fieldMaxHr, keyboardType: TextInputType.number),
              ],
            ),

            _buildSection(
              header: l10n.sectionOscChatbox,
              children: [
                 CupertinoFormRow(
                   prefix: Text(l10n.fieldEnabled),
                   child: CupertinoSwitch(
                     value: _oscChatboxEnabled,
                     activeTrackColor: AppColors.accent,
                     onChanged: (v) => setState(() => _oscChatboxEnabled = v),
                   ),
                 ),
                 if (_oscChatboxEnabled)
                   _buildInput(
                     controller: _oscChatboxTemplateCtrl,
                     label: l10n.fieldTemplate,
                     placeholder: '💓{hr}',
                   ),
              ],
            ),

            _buildSection(
              header: l10n.sectionMqtt,
              children: [
                _buildInput(controller: _mqttBrokerCtrl, label: l10n.fieldBroker, placeholder: 'broker.hivemq.com'),
                _buildInput(controller: _mqttPortCtrl, label: l10n.fieldPort, keyboardType: TextInputType.number),
                _buildInput(controller: _mqttTopicCtrl, label: l10n.fieldTopic),
                _buildInput(controller: _mqttUsernameCtrl, label: l10n.fieldUsername),
                _buildInput(controller: _mqttPasswordCtrl, label: l10n.fieldPassword, obscureText: true),
                _buildInput(controller: _mqttClientIdCtrl, label: l10n.fieldClientId),
              ],
            ),

            _buildSection(
              header: l10n.sectionDebugging,
              children: [
                CupertinoFormRow(
                   prefix: Text(l10n.fieldEnableLogs),
                   child: CupertinoSwitch(
                     value: _logEnabled,
                     activeTrackColor: AppColors.accent,
                     onChanged: (v) => setState(() => _logEnabled = v),
                   ),
                 ),
                 if (_logEnabled)
                   CupertinoButton(
                     child: Text(l10n.btnViewLogs),
                     onPressed: () {
                       Navigator.of(context).push(
                         CupertinoPageRoute(builder: (_) => const LogDetailPage()),
                       );
                     },
                   ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'v1.6.1',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String header, required List<Widget> children}) {
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

  Widget _buildInput({
    required TextEditingController controller, 
    required String label, 
    String? placeholder, 
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return CupertinoFormRow(
      prefix: Text(label),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textAlign: TextAlign.end,
        decoration: null,
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary.resolveFrom(context),
        ),
        placeholderStyle: AppTypography.body.copyWith(
          color: AppColors.textTertiary.resolveFrom(context),
        ),
      ),
    );
  }

  void _onSave() {
    final updated = widget.initial.copyWith(
      pushEndpoint: _pushCtrl.text.trim(),
      oscAddress: _oscCtrl.text.trim(),
      oscHrConnectedPath: _oscConnectedCtrl.text.trim(),
      oscHrValuePath: _oscValueCtrl.text.trim(),
      oscHrPercentPath: _oscPercentCtrl.text.trim(),
      oscChatboxEnabled: _oscChatboxEnabled,
      oscChatboxTemplate: _oscChatboxTemplateCtrl.text.trim(),
      maxHeartRate: int.tryParse(_maxHrCtrl.text.trim()) ?? 200,
      updateIntervalMs: int.tryParse(_intervalCtrl.text.trim()) ?? 1000,
      logEnabled: _logEnabled,
      mqttBroker: _mqttBrokerCtrl.text.trim(),
      mqttPort: int.tryParse(_mqttPortCtrl.text.trim()) ?? 1883,
      mqttTopic: _mqttTopicCtrl.text.trim(),
      mqttUsername: _mqttUsernameCtrl.text.trim(),
      mqttPassword: _mqttPasswordCtrl.text,
      mqttClientId: _mqttClientIdCtrl.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }
}
