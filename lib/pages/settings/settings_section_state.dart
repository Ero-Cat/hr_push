import 'package:flutter/cupertino.dart';

import '../../models/models.dart';

/// Base for settings section widgets: every section renders [initial] and
/// reports edits to the page shell through [onChanged].
abstract class SettingsSectionWidget extends StatefulWidget {
  const SettingsSectionWidget({
    super.key,
    required this.initial,
    this.onChanged,
  });

  /// Settings as they were when the page opened; dirty checks compare
  /// against these.
  final HeartRateSettings initial;

  /// Fired on every field edit so the page shell can re-evaluate dirty
  /// state (sections additionally rebuild themselves for live validation).
  final VoidCallback? onChanged;
}

/// Shared plumbing for settings section states: text-controller lifecycle,
/// live validation rebuilds and the trimmed dirty-check helper.
mixin SettingsSectionState<W extends SettingsSectionWidget> on State<W> {
  final List<TextEditingController> _fieldControllers = [];

  /// Create a controller tracked by this mixin (disposed automatically).
  @protected
  TextEditingController fieldController(String text) {
    final controller = TextEditingController(text: text);
    _fieldControllers.add(controller);
    return controller;
  }

  /// Wire every tracked controller to [notifyFieldChanged]; call once in
  /// initState after all controllers exist.
  @protected
  void listenToFields() {
    for (final controller in _fieldControllers) {
      controller.addListener(notifyFieldChanged);
    }
  }

  /// Rebuild this section so inline validation errors update live; the
  /// page shell separately tracks the dirty flag via [SettingsSectionWidget.onChanged].
  @protected
  void notifyFieldChanged() {
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  /// Whether [controller]'s trimmed text differs from [initial].
  @protected
  bool textDirty(TextEditingController controller, String initial) =>
      controller.text.trim() != initial;

  @override
  void dispose() {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
