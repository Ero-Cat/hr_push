
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../theme/design_system.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bgOpacity = isDark ? GlassStyle.opacityDark : GlassStyle.opacityLight;
    final bgColor = isDark 
        ? CupertinoColors.black.withValues(alpha: bgOpacity) 
        : CupertinoColors.white.withValues(alpha: bgOpacity);

    final content = Container(
      decoration: BoxDecoration(
        boxShadow: [ AppShadows.card ],
        borderRadius: BorderRadius.circular(AppRadius.r20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassStyle.blurAmount, 
            sigmaY: GlassStyle.blurAmount
          ),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: bgColor,
              // borderRadius handling is done by ClipRRect, but inner border needs it too
              borderRadius: BorderRadius.circular(AppRadius.r20),
              border: Border.all(
                color: AppColors.glassBorder.resolveFrom(context),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (margin != null) {
      if (onTap != null) {
        return Padding(
          padding: margin!,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            pressedOpacity: 0.7,
            child: content,
          ),
        );
      }
      return Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        pressedOpacity: 0.7,
        child: content,
      );
    }
    
    return content;
  }
}
