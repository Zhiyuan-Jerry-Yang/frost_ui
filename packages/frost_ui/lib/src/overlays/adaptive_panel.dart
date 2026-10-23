import 'package:flutter/widgets.dart';

import 'dialogs.dart';
import 'sheet.dart';

// Room for a regular dialog and its two viewport margins.
const _panelMinimumDialogWidth = 600.0;

/// Available overlay space, independent of platform and navigation size class.
/// Safe-area and keyboard side insets cannot be used for a floating panel.
bool frostPanelUsesSheet(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.size.width - media.padding.horizontal - media.viewInsets.horizontal < _panelMinimumDialogWidth;
}

/// Presents a FrostDialog in a fitted sheet when floating content cannot fit.
/// The same dialog owns content, actions, async loading and keyboard behavior
/// in both forms. Lazy content can use scrollable:false as usual. Presentation
/// is chosen when opening; resizing never creates a second modal session.
Future<T?> showFrostAdaptiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  List<FrostSheetDetent> sheetDetents = const [FrostSheetDetent.fitted],
}) => frostPanelUsesSheet(context)
    ? showFrostSheet<T>(
        context: context,
        detents: sheetDetents,
        barrierDismissible: barrierDismissible,
        showsCloseButton: false,
        scrollable: false,
        builder: (context) => FrostAdaptiveDialogSheet(child: Builder(builder: builder)),
      )
    : showFrostDialog<T>(context: context, builder: builder, barrierDismissible: barrierDismissible);

/// Internal presentation context; the dialog keeps one action/scroll owner.
class FrostAdaptiveDialogSheet extends InheritedWidget {
  const FrostAdaptiveDialogSheet({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostAdaptiveDialogSheet>() != null;
  @override
  bool updateShouldNotify(FrostAdaptiveDialogSheet oldWidget) => false;
}
