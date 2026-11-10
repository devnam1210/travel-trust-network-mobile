import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// For small status/action fragments, never forms or complete scrolling lists.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: AppMotion.feedback,
      switchInCurve: AppMotion.curve,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [
          for (final old in previous)
            IgnorePointer(child: ExcludeSemantics(child: old)),
          ?current,
        ],
      ),
      child: child,
    );
  }
}

class BusyIcon extends StatelessWidget {
  const BusyIcon({
    super.key,
    required this.busy,
    required this.icon,
    this.size = 20,
    this.color,
  });
  final bool busy;
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: MotionSwitcher(
      child: busy
          ? CircularProgressIndicator(
              key: const ValueKey('busy'),
              strokeWidth: 2,
              color: color,
            )
          : Icon(icon, key: const ValueKey('idle'), size: size, color: color),
    ),
  );
}

/// Reserve the indicator's height so changing activity cannot move the form/list.
class LoadingLine extends StatelessWidget {
  const LoadingLine({super.key, required this.visible});
  final bool visible;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 4,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppMotion.duration(context, AppMotion.feedback),
      curve: AppMotion.curve,
      child: visible
          ? const LinearProgressIndicator()
          : const SizedBox.expand(),
    ),
  );
}
