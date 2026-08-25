import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../net/join_code.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// What the player chose to do with a local game.
enum LocalGameChoice { host, join }

/// The result of the LOCAL GAME dialog: host a table, or join [code].
typedef LocalGameResult = ({LocalGameChoice choice, String? code});

/// Asks whether to host a local game or join one, and takes the code if
/// joining. Returns null if dismissed.
Future<LocalGameResult?> showLocalGameDialog(BuildContext context) {
  return showDialog<LocalGameResult>(
    context: context,
    builder: (context) => const _LocalGameDialog(),
  );
}

class _LocalGameDialog extends StatefulWidget {
  const _LocalGameDialog();

  @override
  State<_LocalGameDialog> createState() => _LocalGameDialogState();
}

class _LocalGameDialogState extends State<_LocalGameDialog> {
  final _controller = TextEditingController();

  /// False on the first screen (host or join), true once joining was chosen
  /// and the code is being typed.
  bool _entering = false;

  /// True when the typed code isn't a code at all — caught here rather than
  /// after a six-second dial that was never going to connect.
  bool _badCode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _controller.text;
    if (JoinCode.decode(code) == null) {
      setState(() => _badCode = true);
      return;
    }
    Navigator.pop(context, (choice: LocalGameChoice.join, code: code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_entering) {
      return AppDialog(
        title: l10n.localGameTitle,
        children: [
          Text(
            l10n.localGameSameWifi,
            style: AppText.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.dialog(
            label: l10n.localGameHost,
            filled: false,
            onTap: () => Navigator.pop(
              context,
              (choice: LocalGameChoice.host, code: null),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.dialog(
            label: l10n.localGameJoin,
            filled: false,
            onTap: () => setState(() => _entering = true),
          ),
        ],
      );
    }

    return AppDialog(
      // No JOIN button under the field, for the same reason the profile dialog
      // has no SAVE: the keyboard's Go key already submits, and a button below
      // a text field is the one thing a landscape keyboard pushes off screen.
      title: l10n.joinGameTitle,
      children: [
        // The error replaces this rather than appearing below the field, so
        // the field stays last and the dialog doesn't change height when a
        // code is rejected.
        Text(
          _badCode ? l10n.joinBadCode : l10n.joinEnterCode,
          style: _badCode
              ? AppText.label.copyWith(color: AppColors.penalty)
              : AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitCode(),
            onChanged: (_) {
              if (_badCode) setState(() => _badCode = false);
            },
            // The code is base 36, and it's shown grouped with dashes — so
            // dashes are allowed in and stripped by the decoder.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z-]')),
              LengthLimitingTextInputFormatter(JoinCode.length + 2),
            ],
            cursorColor: AppColors.accent,
            style: AppText.display.copyWith(letterSpacing: 3),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '—',
              hintStyle: AppText.display.copyWith(
                letterSpacing: 3,
                color: AppColors.textFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
