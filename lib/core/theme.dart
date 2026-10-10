import 'package:flutter/material.dart';

/// Design tokens. Greens come from the YouthCare Connect / MYTHOSPRIME marks.
class Brand {
  static const green = Color(0xFF1B5E20);
  static const greenMid = Color(0xFF2E7D32);
  static const leaf = Color(0xFF7CB342);
  static const mint = Color(0xFF8FD18F);
}

class Gap {
  static const xs = 4.0, s = 8.0, m = 16.0, l = 24.0, xl = 40.0;
}

class Sem {
  const Sem(this.fg, this.bg);
  final Color fg, bg;
  static Sem success(BuildContext c) => _dark(c) ? const Sem(Color(0xFF9BE3A0), Color(0xFF173A1C)) : const Sem(Color(0xFF14501A), Color(0xFFDDF1DE));
  static Sem warning(BuildContext c) => _dark(c) ? const Sem(Color(0xFFFFD27A), Color(0xFF45330A)) : const Sem(Color(0xFF6B4300), Color(0xFFFFEBC2));
  static Sem info(BuildContext c) => _dark(c) ? const Sem(Color(0xFFA9CCF5), Color(0xFF14304F)) : const Sem(Color(0xFF0E4A82), Color(0xFFDCEBFA));
  static Sem danger(BuildContext c) => _dark(c) ? const Sem(Color(0xFFFFB4AB), Color(0xFF4A1612)) : const Sem(Color(0xFF8C1D18), Color(0xFFFCE0DD));
  static Sem neutral(BuildContext c) => _dark(c) ? const Sem(Color(0xFFD5DDD5), Color(0xFF273029)) : const Sem(Color(0xFF3B463E), Color(0xFFE9EDE6));
  static bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

ThemeData buildTheme(Brightness b, {required bool reduceMotion}) {
  final dark = b == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: Brand.green, brightness: b);
  final scheme = dark
      ? base.copyWith(
          primary: Brand.mint,
          onPrimary: const Color(0xFF06280B),
          primaryContainer: const Color(0xFF1E4A24),
          onPrimaryContainer: const Color(0xFFD7F5D8),
          surface: const Color(0xFF111713),
          onSurface: const Color(0xFFE4EBE4),
          onSurfaceVariant: const Color(0xFFB9C4BA),
          outline: const Color(0xFF7D897E),
          outlineVariant: const Color(0xFF39433B),
          error: const Color(0xFFFFB4AB),
          surfaceContainerHighest: const Color(0xFF232B25),
        )
      : base.copyWith(
          primary: Brand.green,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDDF1DE),
          onPrimaryContainer: const Color(0xFF0B3A12),
          surface: const Color(0xFFFAFAF6),
          onSurface: const Color(0xFF16201A),
          onSurfaceVariant: const Color(0xFF424D45),
          outline: const Color(0xFF6B766D),
          outlineVariant: const Color(0xFFD3DAD1),
          error: const Color(0xFFB3261E),
          surfaceContainerHighest: const Color(0xFFEDEFE8),
        );
  final t = ThemeData(brightness: b, useMaterial3: true).textTheme;
  final text = t.copyWith(
    displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  const builder = _NoTransition();
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    focusColor: scheme.primary.withValues(alpha: 0.25),
    dividerColor: scheme.outlineVariant,
    pageTransitionsTheme: reduceMotion
        ? const PageTransitionsTheme(builders: {
            TargetPlatform.android: builder,
            TargetPlatform.iOS: builder,
            TargetPlatform.windows: builder,
            TargetPlatform.linux: builder,
            TargetPlatform.macOS: builder,
          })
        : null,
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
  );
}

/// Status presentation: always an icon plus words, never colour alone.
(IconData, Sem Function(BuildContext)) statusStyle(String status) => switch (status) {
      'pending' => (Icons.hourglass_top, Sem.info),
      'accepted' => (Icons.check_circle_outline, Sem.success),
      'rerouted' => (Icons.alt_route, Sem.info),
      'attended' => (Icons.how_to_reg, Sem.success),
      'follow_up_due' => (Icons.event_repeat, Sem.warning),
      'completed' => (Icons.task_alt, Sem.success),
      'declined' => (Icons.block, Sem.danger),
      _ => (Icons.help_outline, Sem.neutral),
    };

(IconData, Sem Function(BuildContext)) serviceStatusStyle(String status) => switch (status) {
      'verified' => (Icons.verified_outlined, Sem.success),
      'pending' => (Icons.pending_outlined, Sem.warning),
      'unavailable' => (Icons.do_not_disturb_on_outlined, Sem.danger),
      _ => (Icons.edit_note, Sem.neutral),
    };
