import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../logic/ai_strategy.dart';
import '../services/profile_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text.dart';
import 'app_dialog.dart';
import 'difficulty_dialog.dart';
import 'glass_pane.dart';

/// Shows who the player is: the name they play under at the top, their lifetime
/// record under it.
///
/// The name is a button rather than a field. Reading your own profile is the
/// common case and typing into it is the rare one, so the keyboard only comes
/// up once you ask for it by tapping the name, which opens [_NameDialog].
///
/// Read the name back with [ProfileService.read] once this completes — writes
/// land in the preferences cache synchronously, so a read queued after this
/// future always sees them.
Future<void> showProfileDialog(BuildContext context, String currentName) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ProfileDialog(currentName: currentName),
  );
}

class _ProfileDialog extends StatefulWidget {
  final String currentName;

  const _ProfileDialog({required this.currentName});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late String _name = widget.currentName;
  PlayerStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Loads the lifetime record. Stays null on a read failure, which hides the
  /// line rather than showing a misleading zero.
  Future<void> _loadStats() async {
    final stats = await StatsService.read();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  /// Opens the name editor, then picks up whatever it stored. The editor saves
  /// as you type, so there's no result to return and every way out of it —
  /// return key, tap outside, back — leaves the same name behind.
  Future<void> _editName() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _NameDialog(currentName: _name),
    );
    final name = await ProfileService.read();
    if (!mounted) return;
    setState(() => _name = name);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    final l10n = AppLocalizations.of(context)!;

    return AppDialog(
      title: l10n.profileTitle,
      children: [
        Text(
          l10n.profileYourName,
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassPane(
          onTap: _editName,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            _name,
            style: AppText.title.copyWith(letterSpacing: 0.5),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (stats != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.profileRecord(stats.gamesPlayed),
            style: AppText.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          _RecordTable(byLevel: stats.byLevel),
        ],
      ],
    );
  }
}

/// The lifetime record, one row per difficulty: the level down the left, wins
/// and losses in the columns beside it.
///
/// A [Table] rather than a Row of Columns — the three columns have to line up
/// across every row, and the level names are three different lengths in each
/// translation.
class _RecordTable extends StatelessWidget {
  final Map<AiLevel, LevelRecord> byLevel;

  const _RecordTable({required this.byLevel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Table(
      // The level column carries words, the other two carry at most a few
      // digits, so it takes twice the width.
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.textFaint, width: 0.5),
            ),
          ),
          children: [
            const SizedBox.shrink(), // the level column needs no heading
            _heading(l10n.profileWon),
            _heading(l10n.profileLost),
          ],
        ),
        for (final entry in byLevel.entries)
          TableRow(
            children: [
              _cell(
                Text(
                  difficultyLabel(context, entry.key),
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _cell(_count(entry.value.wins)),
              _cell(_count(entry.value.losses)),
            ],
          ),
      ],
    );
  }

  static Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: AppText.caption, textAlign: TextAlign.center),
  );

  static Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: child,
  );

  static Widget _count(int value) =>
      Text('$value', style: AppText.statLarge, textAlign: TextAlign.center);
}

/// The name editor: one field, no SAVE button and nothing to confirm.
///
/// The name is a label, not a form — it saves as you type, so pressing return,
/// tapping outside, or backing out all leave the same name behind. That removes
/// the one thing a landscape keyboard could push off the bottom of the dialog,
/// and it removes the way you could lose a typed name by dismissing instead of
/// committing.
class _NameDialog extends StatefulWidget {
  final String currentName;

  const _NameDialog({required this.currentName});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentName == ProfileService.defaultName
        ? ''
        : widget.currentName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Persists each edit as it's made, so there is no unsaved state to lose on
  /// any exit path. Not awaited: it logs its own failures, and a name is not
  /// worth blocking a keystroke on.
  void _onChanged(String value) => ProfileService.save(value);

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: AppLocalizations.of(context)!.profileYourName,
      children: [
        // Not a GlassPane: that owns a press response and a tap sound, which a
        // field you type into shouldn't have. A plain filled surface instead.
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
            textCapitalization: TextCapitalization.words,
            maxLength: ProfileService.maxLength,
            textInputAction: TextInputAction.done,
            onChanged: _onChanged,
            // The keyboard's own done key is the way out. It doesn't need to
            // save — that already happened on the way in.
            onSubmitted: (_) => Navigator.pop(context),
            cursorColor: AppColors.accent,
            style: AppText.title.copyWith(letterSpacing: 0.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '', // the cap is enforced, it doesn't need a tally
              isDense: true,
              hintText: ProfileService.defaultName,
              hintStyle: AppText.title.copyWith(
                letterSpacing: 0.5,
                color: AppColors.textFaint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
