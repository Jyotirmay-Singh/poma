import 'package:flutter/material.dart';

import '../application/calendar_connection_controller.dart';
import 'copy.dart';
import 'design_tokens.dart';

const _googleMark = 'assets/branding/google-g.png';

enum _AccountAction { switchAccount, signOut }

class GoogleAccountSection extends StatelessWidget {
  const GoogleAccountSection({
    required this.connection,
    required this.unlocked,
    required this.onManageCalendars,
    super.key,
  });

  final CalendarConnectionController connection;
  final bool unlocked;
  final VoidCallback onManageCalendars;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: connection,
    builder: (context, _) {
      final copy = context.copy;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final account = unlocked ? connection.verifiedAccountLabel : null;
      final signingIn =
          connection.status == CalendarConnectionStatus.connecting;
      final busy =
          signingIn ||
          connection.revoking ||
          connection.status == CalendarConnectionStatus.restoring;
      final connected =
          connection.status == CalendarConnectionStatus.connected &&
          !connection.cleanupPending &&
          !connection.revoking;
      final needsAttention =
          connection.cleanupPending && !connection.revoking ||
          const {
            CalendarConnectionStatus.offline,
            CalendarConnectionStatus.incompletePermissions,
            CalendarConnectionStatus.reconnectRequired,
            CalendarConnectionStatus.storageError,
            CalendarConnectionStatus.unavailable,
          }.contains(connection.status);
      final status = !unlocked
          ? copy.googleAccountHidden
          : connection.revoking
          ? copy.googleSigningOut
          : connection.cleanupPending
          ? copy.googleAccountAttention
          : switch (connection.status) {
              CalendarConnectionStatus.unconfigured => copy.googleAccountSetup,
              CalendarConnectionStatus.restoring => copy.googleAccountChecking,
              CalendarConnectionStatus.disconnected =>
                copy.googleAccountSignedOut,
              CalendarConnectionStatus.connecting => copy.googleSigningIn,
              CalendarConnectionStatus.connected => copy.googleAccountConnected,
              CalendarConnectionStatus.offline => copy.googleAccountOffline,
              CalendarConnectionStatus.incompletePermissions =>
                copy.googleAccountPermissions,
              CalendarConnectionStatus.reconnectRequired =>
                copy.googleAccountReconnect,
              CalendarConnectionStatus.storageError ||
              CalendarConnectionStatus.unavailable =>
                copy.googleAccountAttention,
            };
      final statusColor = unlocked && needsAttention
          ? colors.error
          : unlocked && (connected || busy)
          ? colors.primary
          : colors.onSurfaceVariant;
      final actions = <Widget>[];
      if (unlocked) {
        if (signingIn) {
          actions.add(
            TextButton(
              key: const ValueKey('settings-google-cancel'),
              onPressed: connection.cancel,
              child: Text(copy.cancel),
            ),
          );
        } else if (!busy) {
          if (connection.cleanupPending) {
            actions.add(
              OutlinedButton(
                key: const ValueKey('settings-google-retry-sign-out'),
                onPressed: connection.disconnect,
                child: Text(copy.googleRetrySignOut),
              ),
            );
          } else if (connected || !connection.configuration.configured) {
            actions.add(
              OutlinedButton.icon(
                key: const ValueKey('settings-google-manage-calendars'),
                onPressed: onManageCalendars,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(copy.googleManageCalendars),
              ),
            );
          } else {
            actions.add(
              OutlinedButton.icon(
                key: const ValueKey('settings-google-sign-in'),
                onPressed: connection.canConnect ? connection.connect : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                ),
                icon: ExcludeSemantics(
                  child: Image.asset(_googleMark, width: 20, height: 20),
                ),
                label: Text(copy.googleSignIn),
              ),
            );
          }
          if (account != null && !connection.cleanupPending) {
            actions.add(
              PopupMenuButton<_AccountAction>(
                key: const ValueKey('settings-google-account-menu'),
                tooltip: copy.googleAccountOptions,
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  switch (action) {
                    case _AccountAction.switchAccount:
                      connection.connect();
                    case _AccountAction.signOut:
                      connection.disconnect();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _AccountAction.switchAccount,
                    child: Text(copy.googleSwitchAccount),
                  ),
                  PopupMenuItem(
                    value: _AccountAction.signOut,
                    child: Text(copy.googleSignOut),
                  ),
                ],
              ),
            );
          }
        }
      }
      final identity = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccountAvatar(account: account, unlocked: unlocked),
          const SizedBox(width: PomaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unlocked) ...[
                  Text(
                    account ?? copy.googleAccountWelcome,
                    key: const ValueKey('settings-google-account-name'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: PomaSpace.xxs),
                ],
                Text(
                  !unlocked
                      ? copy.googleAccountUnlock
                      : account == null
                      ? copy.googleAccountInvite
                      : copy.googleAccountShared,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final buttons = Wrap(
        spacing: PomaSpace.xs,
        runSpacing: PomaSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      final message = !unlocked || busy || connected
          ? null
          : !connection.configuration.configured
          ? copy.googleAccountSetupHelp
          : connection.message;

      return Container(
        key: const ValueKey('settings-google-account'),
        padding: const EdgeInsets.all(PomaSpace.md),
        decoration: BoxDecoration(
          color: MediaQuery.highContrastOf(context)
              ? colors.surface
              : colors.surfaceContainerHighest.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: PomaSpace.sm,
              runSpacing: PomaSpace.xs,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    copy.googleAccount,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PomaSpace.xs,
                      vertical: PomaSpace.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(
                        PomaLayout.controlRadius,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unlocked && busy) ...[
                          SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: PomaSpace.xs),
                        ] else if (connected && unlocked) ...[
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: PomaSpace.xxs),
                        ],
                        Flexible(
                          child: Text(
                            status,
                            key: const ValueKey('settings-google-status'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PomaSpace.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.4) {
                  return Row(
                    children: [
                      Expanded(child: identity),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(width: PomaSpace.md),
                        buttons,
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: PomaSpace.sm),
                      buttons,
                    ],
                  ],
                );
              },
            ),
            if (message != null) ...[
              const SizedBox(height: PomaSpace.sm),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: needsAttention
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account, required this.unlocked});
  final String? account;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary.withValues(alpha: .12),
              foregroundColor: colors.primary,
              child: account == null
                  ? Icon(unlocked ? Icons.person_outline : Icons.lock_outline)
                  : Text(
                      account!.characters.first.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: colors.primary),
                    ),
            ),
            if (account != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Image.asset(_googleMark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
