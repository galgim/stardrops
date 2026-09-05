import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Offers the one-time unlock that lets this device host a local game.
///
/// Returns true once hosting is unlocked — by a purchase, by a restore, or
/// because it already was — and null if the player backed out. Joining is free
/// and never reaches this dialog.
Future<bool?> showHostUnlockDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _HostUnlockDialog(),
  );
}

class _HostUnlockDialog extends StatefulWidget {
  const _HostUnlockDialog();

  @override
  State<_HostUnlockDialog> createState() => _HostUnlockDialogState();
}

class _HostUnlockDialogState extends State<_HostUnlockDialog> {
  final _purchases = PurchaseService.instance;

  /// The last failure, shown in place of the explanation. Cleared whenever
  /// another attempt starts, so a stale message can't sit under a live one.
  PurchaseError? _error;

  @override
  void initState() {
    super.initState();
    _purchases.addListener(_onPurchaseChange);
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchaseChange);
    super.dispose();
  }

  /// Closes the moment the unlock lands, whichever way it arrived — the player
  /// asked to host, so the lobby is where they should end up, not back on a
  /// dialog congratulating them.
  void _onPurchaseChange() {
    if (!mounted) return;
    if (_purchases.canHost) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {});
  }

  Future<void> _run(Future<PurchaseError?> Function() action) async {
    setState(() => _error = null);
    final error = await action();
    if (!mounted) return;
    // A cancel is the player changing their mind, not a failure to report.
    if (error == PurchaseError.cancelled) return;
    setState(() => _error = error);
  }

  /// The failure text, or null while there's nothing to apologise for.
  String? _message(AppLocalizations l10n) => switch (_error) {
    null => null,
    PurchaseError.storeUnavailable => l10n.purchaseStoreUnavailable,
    PurchaseError.productMissing => l10n.purchaseUnavailable,
    PurchaseError.cancelled => null,
    PurchaseError.failed => l10n.purchaseFailed,
    PurchaseError.nothingToRestore => l10n.purchaseNothingToRestore,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _purchases.busy;
    final failure = _message(l10n);
    final price = _purchases.price;

    return AppDialog(
      title: l10n.purchaseTitle,
      children: [
        // The failure replaces the explanation rather than stacking under it,
        // the way the join dialog handles a bad code — so the dialog keeps its
        // height and doesn't jump when something goes wrong.
        Text(
          failure ?? l10n.purchaseBody,
          style: failure == null
              ? AppText.body
              : AppText.body.copyWith(color: AppColors.penalty),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.dialog(
          // The store's own price string, which is already in the player's
          // currency. Falls back to the bare label while the product is still
          // loading, or if it never does.
          label: price == null ? l10n.purchaseBuy : l10n.purchaseBuyAt(price),
          filled: false,
          onTap: busy ? null : () => _run(_purchases.buy),
        ),
        const SizedBox(height: AppSpacing.md),
        // Apple requires a visible restore for a non-consumable: a player who
        // reinstalls or changes phone must be able to get it back without
        // paying twice.
        AppButton.dialog(
          label: l10n.purchaseRestore,
          filled: false,
          onTap: busy ? null : () => _run(_purchases.restore),
        ),
        const SizedBox(height: AppSpacing.md),
        // Tapping outside already dismisses, as it does on every dialog here.
        // This is spelled out anyway because this is the one dialog that asks
        // for money, and a paywall with no visible way out reads as a trap —
        // to a player, and to a reviewer.
        AppButton.dialog(
          label: l10n.purchaseNotNow,
          filled: false,
          onTap: busy ? null : () => Navigator.pop(context),
        ),
      ],
    );
  }
}
