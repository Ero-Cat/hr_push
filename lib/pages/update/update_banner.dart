import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../theme/design_system.dart';
import '../../widgets/glass_surface.dart';
import 'update_dialog.dart';

/// Slim dashboard banner announcing a newer GitHub release. Tapping it (or
/// its action button) opens the update dialog; the whole banner hides once
/// the user skips the version.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<UpdateService, ({bool show, String version})>(
      selector: (_, svc) =>
          (show: svc.shouldShowBanner, version: svc.latest?.version ?? ''),
      builder: (context, state, _) {
        if (!state.show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
          child: GlassSurface(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle_fill,
                  color: AppColors.warning.resolveFrom(context),
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    '${l10n.updateBannerTitle} v${state.version}',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.textPrimary.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => showUpdateDialog(context),
                  child: Text(
                    l10n.updateNow,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.accent.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
