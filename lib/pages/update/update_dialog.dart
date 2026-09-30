import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../theme/design_system.dart';

/// Opens the update dialog for the currently known newer release.
///
/// No-op when the service has no pending update; callers only invoke it when
/// [UpdateService.updateAvailable] is true.
Future<void> showUpdateDialog(BuildContext context) {
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, svc, _) {
        final l10n = AppLocalizations.of(context)!;
        final release = svc.latest;
        if (release == null) {
          return CupertinoAlertDialog(
            title: Text(l10n.updateBannerTitle),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.updateCancel),
              ),
            ],
          );
        }

        return CupertinoAlertDialog(
          title: Text('${l10n.updateBannerTitle} v${release.version}'),
          content: _content(context, svc, l10n),
          actions: _actions(context, svc, l10n),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    UpdateService svc,
    AppLocalizations l10n,
  ) {
    final release = svc.latest!;
    final children = <Widget>[];

    if (svc.status == UpdateStatus.downloading) {
      final percent = (svc.downloadProgress * 100).round();
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text('${l10n.updateDownloading} $percent%'),
              const SizedBox(height: 10),
              const CupertinoActivityIndicator(),
            ],
          ),
        ),
      );
    } else {
      if (release.plainNotes.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.updateNotesTitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
        children.add(
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  release.plainNotes,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (svc.status == UpdateStatus.downloaded) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _installGuide(l10n, svc),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        );
      } else if (svc.error != null &&
          svc.status !=
              UpdateStatus
                  .failed // check failure already shown by the caller
                  ) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.updateDownloadFailed,
              style: AppTypography.caption.copyWith(
                color: AppColors.danger.resolveFrom(context),
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String _installGuide(AppLocalizations l10n, UpdateService svc) {
    if (Platform.isMacOS) return l10n.updateGuideMacos;
    if (Platform.isLinux) return l10n.updateGuideLinux;
    if (Platform.isWindows &&
        (svc.downloadedFilePath?.toLowerCase().endsWith('.zip') ?? false)) {
      return l10n.updateGuideWindowsZip;
    }
    return l10n.updateGuideWindowsInstaller;
  }

  List<Widget> _actions(
    BuildContext context,
    UpdateService svc,
    AppLocalizations l10n,
  ) {
    void close() => Navigator.of(context).pop();

    switch (svc.status) {
      case UpdateStatus.downloading:
        return [
          CupertinoDialogAction(
            onPressed: () {
              svc.cancelDownload();
              close();
            },
            child: Text(l10n.updateCancel),
          ),
        ];
      case UpdateStatus.downloaded:
        return [
          CupertinoDialogAction(
            onPressed: () {
              svc.openReleasePage();
              close();
            },
            child: Text(l10n.updateOpenReleasePage),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              await svc.installUpdate();
              if (context.mounted) close();
            },
            child: Text(l10n.updateInstallNow),
          ),
        ];
      default:
        // iOS cannot self-install sideloaded IPAs; the release page is the
        // only actionable destination there.
        if (Platform.isIOS) {
          return [
            CupertinoDialogAction(
              onPressed: () {
                svc.ignoreCurrentVersion();
                close();
              },
              child: Text(l10n.updateSkipVersion),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                svc.openReleasePage();
                close();
              },
              child: Text(l10n.updateOpenReleasePage),
            ),
          ];
        }
        return [
          CupertinoDialogAction(
            onPressed: () {
              svc.ignoreCurrentVersion();
              close();
            },
            child: Text(l10n.updateSkipVersion),
          ),
          CupertinoDialogAction(
            onPressed: () {
              svc.openReleasePage();
              close();
            },
            child: Text(l10n.updateOpenReleasePage),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => svc.downloadUpdate(),
            child: Text(l10n.updateNow),
          ),
        ];
    }
  }
}
