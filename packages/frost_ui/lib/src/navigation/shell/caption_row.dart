part of 'shell.dart';

// A shared title-row height aligns navigation with or without native actions.
const _shellCaptionHeight = 40.0;

class _CaptionRow extends StatelessWidget {
  const _CaptionRow({required this.iconAxis, required this.nativeCaption, required this.showsBack, required this.onBack, this.brand});
  final double iconAxis;
  final bool nativeCaption, showsBack;
  final Widget? brand;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    Widget drag(Widget child) => nativeCaption ? FrostCaptionRegion(kind: FrostHitKind.caption, child: child) : child;
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showsBack) _ShellCaptionBack(width: iconAxis * 2, onBack: onBack),
        Expanded(
          child: drag(
            ClipRect(
              child: Align(alignment: AlignmentDirectional.centerStart, child: brand),
            ),
          ),
        ),
        if (nativeCaption) const FrostCaptionButtons(),
      ],
    );
  }
}

// Kept outside the destinations' scroll view and the page subtree.
class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final extent = math.max(_shellCaptionHeight, FrostDensity.of(context).targetHeight);
    return SizedBox(
      width: extent,
      height: extent,
      child: FrostButton.icon(
        label: expanded ? labels.collapseNavigation : labels.expandNavigation,
        icon: expanded ? icons.sidebarCollapse : icons.sidebarExpand,
        onPressed: onToggle,
      ),
    );
  }
}

// Geometry-only override: feedback, colours and 140 ms transitions stay shared.
class _ShellCaptionBack extends StatelessWidget {
  const _ShellCaptionBack({required this.width, required this.onBack});
  final double width;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: _shellCaptionHeight,
    child: FrostButtonControl(
      key: const ValueKey('frost-shell-back'),
      label: FrostScope.labelsOf(context).back,
      icon: FrostIconSet.of(context).back,
      iconStyle: FrostIconButtonStyle.plain,
      onPressed: onBack,
      geometry: const FrostButtonGeometry(
        // Navigation keeps ordinary rounded feedback; only native caption actions are square.
        horizontalInset: 0,
        verticalInset: 0,
        minimumWidth: _shellCaptionHeight,
        alignment: MainAxisAlignment.center,
        visualHeight: _shellCaptionHeight,
        maximumHitHeight: _shellCaptionHeight,
        iconSize: 20,
        edgeBleed: 0,
      ),
    ),
  );
}
