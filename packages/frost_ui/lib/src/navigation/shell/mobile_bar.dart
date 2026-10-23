part of 'shell.dart';

// Minimum bar height before bottom safe area; larger text grows the bar.
const _mobileNavigationMinHeight = 64.0;
const _mobileNavigationIconSize = 24.0;

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({required this.destinations, required this.selectedIndex, required this.onDestinationSelected});

  final List<FrostNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return FrostSurface(
      role: FrostSurfaceRole.chrome,
      borderRadius: BorderRadius.zero,
      edge: FrostSurfaceEdge.none,
      elevated: false,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final style = FrostTypography.of(context).style(FrostTextRole.caption).copyWith(height: 1);
            final labelWidth = math.max(1.0, constraints.maxWidth / destinations.length - 8);
            final labelHeight = destinations
                .map((destination) {
                  final painter = TextPainter(
                    text: TextSpan(text: destination.label, style: style),
                    textDirection: Directionality.of(context),
                    textAlign: TextAlign.center,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: labelWidth);
                  final height = painter.height;
                  painter.dispose();
                  return height;
                })
                .reduce(math.max);
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: FrostThemeTokens.of(context).separator, width: 1 / MediaQuery.devicePixelRatioOf(context)),
                ),
              ),
              child: SizedBox(
                height: math.max(_mobileNavigationMinHeight, FrostGap.related + _mobileNavigationIconSize + FrostGap.inline + labelHeight + FrostGap.related),
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        child: _DestinationItem(
                          destination: destinations[index],
                          child: _MobileNavItem(
                            label: destinations[index].label,
                            labelHeight: labelHeight,
                            icon: destinations[index].icon,
                            selected: selectedIndex == index,
                            onTap: () => onDestinationSelected(index),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({required this.label, required this.labelHeight, required this.icon, required this.selected, required this.onTap});

  final String label;
  final double labelHeight;
  final FrostIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return FrostSelectionFeedback(
      selected: selected,
      foreground: selected ? tokens.selectionInk : tokens.textSecondary,
      background: Colors.transparent,
      builder: (context, ink, fill, scale) => Semantics(
        button: true,
        selected: selected,
        label: FrostDestinationStatus.labelOf(context, label),
        excludeSemantics: true,
        child: FrostClickSurface(
          feedback: FrostClickFeedback.quiet,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FrostGap.inline, vertical: FrostGap.related),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: scale,
                  child: FrostDestinationStatus.decorateIcon(context, FrostIcon(icon, size: _mobileNavigationIconSize, color: ink)),
                ),
                const SizedBox(height: FrostGap.inline),
                SizedBox(
                  height: labelHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FrostSkeletonText(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: FrostTypography.of(context).style(FrostTextRole.caption).copyWith(height: 1, color: ink),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
