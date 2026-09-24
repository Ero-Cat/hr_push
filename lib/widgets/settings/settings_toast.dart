import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../theme/design_system.dart';

/// Brief pill-style feedback at the bottom of the screen (Cupertino has no
/// built-in toast).
void showSettingsToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final overlay = OverlayEntry(
    builder: (context) => _ToastOverlay(message: message, isError: isError),
  );
  Overlay.of(context, rootOverlay: true).insert(overlay);
  Timer(const Duration(milliseconds: 1600), overlay.remove);
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError
        ? CupertinoDynamicColor.resolve(AppColors.danger, context)
        : CupertinoDynamicColor.resolve(AppColors.success, context);

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  AppColors.bgTertiary,
                  context,
                ),
                borderRadius: BorderRadius.circular(AppRadius.r20),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isError
                        ? CupertinoIcons.exclamationmark_circle_fill
                        : CupertinoIcons.checkmark_circle_fill,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.textPrimary.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
