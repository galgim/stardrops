import 'dart:io';

// Not dart:ui — it exports a different TextStyle that would shadow the one
// AppText actually uses.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/services/locale_service.dart';
import 'package:stardrop/theme/app_text.dart';

/// Keeps the type scale closed.
///
/// It was closed once before. Then fifteen `copyWith(fontSize: ...)` calls
/// accumulated across seven sizes, one reasonable-looking line at a time,
/// until the app was back to picking sizes per widget — with a named scale
/// still sitting there claiming otherwise. Nothing failed, so nobody noticed
/// until an audit counted them.
///
/// This is the counter. If a size is genuinely missing, add a named role to
/// `AppText` rather than a number to a call site.
void main() {
  test('no widget sets its own font size', () {
    const allowed = 'lib/theme/app_text.dart';

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.replaceAll(r'\', '/').endsWith(allowed)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('fontSize:')) {
          offenders.add('${entity.path}:${i + 1} — ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These call sites name their own font size. Add a role to AppText '
          'and use it instead:\n${offenders.join('\n')}',
    );
  });

  // ── Script adaptation ─────────────────────────────────────

  group('Korean typography', () {
    // Every style that can ever hold a translated word. The data styles are
    // deliberately absent: they hold digits and are checked separately.
    List<({String name, TextStyle style})> languageStyles() => [
          (name: 'hero', style: AppText.hero),
          (name: 'display', style: AppText.display),
          (name: 'title', style: AppText.title),
          (name: 'body', style: AppText.body),
          (name: 'label', style: AppText.label),
          (name: 'caption', style: AppText.caption),
          (name: 'chip', style: AppText.chip),
          (name: 'button', style: AppText.button),
          (name: 'buttonSmall', style: AppText.buttonSmall),
        ];

    tearDown(() => LocaleService.current.value = const Locale('en'));

    test('Latin keeps its tracking', () {
      LocaleService.current.value = const Locale('en');
      expect(AppText.label.letterSpacing, 2.5);
      expect(AppText.button.letterSpacing, 1.5);
      expect(AppText.hero.letterSpacing, 1);
    });

    test('Hangul drops tracking on every language style', () {
      LocaleService.current.value = const Locale('ko');
      for (final s in languageStyles()) {
        expect(
          s.style.letterSpacing ?? 0,
          0,
          reason: '${s.name} still tracks in Korean, which reads as broken',
        );
      }
    });

    test('Hangul opens the line heights that would clip it', () {
      LocaleService.current.value = const Locale('ko');
      for (final s in languageStyles()) {
        expect(
          s.style.height,
          greaterThanOrEqualTo(1.2),
          reason: '${s.name} is too tight for a Hangul block',
        );
      }
    });

    test('a generous line height is left where it was', () {
      LocaleService.current.value = const Locale('ko');
      expect(AppText.body.height, 1.55); // not clamped down to 1.2
    });

    test('digit-only styles are untouched by the script', () {
      LocaleService.current.value = const Locale('ko');
      expect(AppText.stat.height, 1);
      expect(AppText.statLarge.height, 1);
      expect(AppText.statSmall.height, 1);
    });

    // The one that fails silently in production: a style with no Hangul
    // fallback renders Korean as empty boxes, and nothing throws.
    test('every style can reach a Hangul font', () {
      for (final locale in [const Locale('en'), const Locale('ko')]) {
        LocaleService.current.value = locale;
        final styles = [
          ...languageStyles(),
          (name: 'stat', style: AppText.stat),
          (name: 'statLarge', style: AppText.statLarge),
          (name: 'statSmall', style: AppText.statSmall),
          (name: 'cardNumber', style: AppText.cardNumber(20, const Color(0xFFFFFFFF))),
        ];
        for (final s in styles) {
          expect(
            s.style.fontFamilyFallback ?? const <String>[],
            isNotEmpty,
            reason: '${s.name} names SpaceGrotesk with no fallback, so any '
                'Hangul in it renders as tofu',
          );
        }
      }
    });
  });
}
