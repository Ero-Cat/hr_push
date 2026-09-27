import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../models/heart_rate_settings.dart';
import '../theme/design_system.dart';

/// Explains how the heart-rate percent is computed and consumed, with live
/// examples converted using the min/max HR values currently typed into the
/// settings form (unsaved edits included).
class HrPercentHelpPage extends StatelessWidget {
  const HrPercentHelpPage({
    super.key,
    required this.minHeartRate,
    required this.maxHeartRate,
  });

  final int minHeartRate;
  final int maxHeartRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = HeartRateSettings.defaults().copyWith(
      minHeartRate: minHeartRate,
      maxHeartRate: maxHeartRate,
    );

    final examples = <_ExampleRowData>[
      _ExampleRowData(minHeartRate, l10n.percentHelpTagMin),
      _ExampleRowData(
        ((minHeartRate + maxHeartRate) / 2).round(),
        l10n.percentHelpTagMid,
      ),
      _ExampleRowData(maxHeartRate, l10n.percentHelpTagMax),
      if (minHeartRate >= 20)
        _ExampleRowData(minHeartRate - 15, l10n.percentHelpTagClampedLow),
      _ExampleRowData(maxHeartRate + 15, l10n.percentHelpTagClampedHigh),
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.percentHelpTitle),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          children: [
            _SectionCard(
              title: l10n.percentHelpFormulaTitle,
              children: [
                Text(
                  l10n.percentHelpFormulaBody,
                  style: AppTypography.subheadline.copyWith(height: 1.5),
                ),
              ],
            ),
            _SectionCard(
              title: l10n.percentHelpExampleTitle,
              children: [
                Text(
                  l10n.percentHelpExampleIntro(minHeartRate, maxHeartRate),
                  style: AppTypography.subheadline,
                ),
                const SizedBox(height: 8),
                for (final example in examples)
                  _ExampleRow(
                    data: example,
                    percent: settings.percentFor(example.bpm) ?? 0,
                  ),
              ],
            ),
            _SectionCard(
              title: l10n.percentHelpFieldsTitle,
              children: [
                _bulletText(context, l10n.percentHelpFieldJson),
                _bulletText(context, l10n.percentHelpFieldOsc),
                _bulletText(context, l10n.percentHelpFieldChatbox),
              ],
            ),
            _SectionCard(
              title: l10n.percentHelpUnityTitle,
              children: [
                Text(
                  l10n.percentHelpUnityIntro,
                  style: AppTypography.subheadline,
                ),
                const SizedBox(height: 8),
                _bulletText(context, l10n.percentHelpUnity01),
                _bulletText(context, l10n.percentHelpUnityNeg),
                _bulletText(context, l10n.percentHelpUnityDirect),
              ],
            ),
            _SectionCard(
              title: l10n.percentHelpWhyTitle,
              children: [
                Text(
                  l10n.percentHelpWhyBody,
                  style: AppTypography.subheadline.copyWith(height: 1.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletText(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.accent.resolveFrom(context),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.subheadline.copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _ExampleRowData {
  const _ExampleRowData(this.bpm, this.tag);

  final int bpm;
  final String tag;
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.data, required this.percent});

  final _ExampleRowData data;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text('${data.bpm} BPM', style: AppTypography.subheadline),
          ),
          Expanded(child: Text(data.tag, style: AppTypography.footnote)),
          Text(
            percent.toStringAsFixed(2),
            style: AppTypography.headline.copyWith(
              color: AppColors.heart.resolveFrom(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.resolveFrom(context),
        border: Border.all(color: AppColors.separator.resolveFrom(context)),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headline),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
