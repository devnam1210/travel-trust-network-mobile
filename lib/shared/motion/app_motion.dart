import 'package:flutter/material.dart';

/// Shared timings; accessibility settings always take precedence over decoration.
abstract final class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const feedback = Duration(milliseconds: 180);
  static const fade = Duration(milliseconds: 220);
  static const expand = Duration(milliseconds: 260);
  static const page = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;

  static int imageWidth(BuildContext context, double logicalWidth) =>
      (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
        1,
        2048,
      );

  /// Fade decoded pixels once. Cached frames and ordinary rebuilds remain visible.
  static Widget imageFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool synchronous,
  ) => AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: synchronous ? Duration.zero : duration(context, fade),
    curve: curve,
    child: child,
  );
}

/// Preserve MaterialPageRoute, native Android back gestures, and Navigator results.
class AppPageTransitionsBuilder extends PredictiveBackPageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppMotion.reduced(context)
      ? child
      : super.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}
