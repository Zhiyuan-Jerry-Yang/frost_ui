part of 'shell.dart';

class _ContentSheet extends StatelessWidget {
  const _ContentSheet({required this.enabled, required this.radius, required this.child});
  final bool enabled;
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? FrostPageOutline(
          radius: radius,
          scrollbarChannel: FrostGap.related,
          child: FrostSurface(role: FrostSurfaceRole.panel, borderRadius: radius, child: child),
        )
      : child;
}
