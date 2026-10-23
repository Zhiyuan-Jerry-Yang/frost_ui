import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/icon.dart';
import '../primitives/text.dart';
import 'error_content.dart';

// Inline messages pair their footnote text with a same-line semantic icon.
const _compactIconSize = 16.0;

/// A one-line message inside content: an icon, the text, an optional action,
/// and optional technical detail one tap away.
class FrostCompactMessage extends StatelessWidget {
  const FrostCompactMessage({required FrostIconData this.icon, required String this.message, this.actionLabel, this.onAction, this.details, super.key})
    : error = null;

  /// Inline error from [error]: the app's localized summary, retry, and the
  /// technical detail one tap away.
  const FrostCompactMessage.error({required Object this.error, this.actionLabel, this.onAction, super.key}) : icon = null, message = null, details = null;

  final FrostIconData? icon;
  final String? message;
  final Object? error;

  /// Defaults to the retry label for errors.
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final error = this.error;
    final presenter = FrostScope.errorsOf(context);
    final message = error == null ? this.message! : presenter.message(context, error);
    final details = error == null ? this.details : presenter.details(error);
    final actionLabel = this.actionLabel ?? (error == null ? null : FrostScope.labelsOf(context).retry);
    final icons = FrostIconSet.of(context);
    final mappedIcon = error == null ? null : presenter.icon?.call(context, error);
    return DecoratedBox(
      decoration: ShapeDecoration(color: tokens.fillSubtle, shape: FrostRadius.shape(context, FrostRadius.md)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FrostGap.related, vertical: FrostGap.related),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FrostIcon(
                  icon ?? mappedIcon ?? icons.error,
                  size: _compactIconSize,
                  color: error == null || mappedIcon != null ? tokens.textSecondary : tokens.negativeInk,
                ),
                const SizedBox(width: FrostGap.related),
                Expanded(
                  child: FrostText(message, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: FrostGap.related),
                  FrostButton(onPressed: onAction, icon: icons.refresh, label: actionLabel, variant: FrostButtonVariant.plain, size: FrostControlSize.compact),
                ],
              ],
            ),
            if (details != null && details.trim().isNotEmpty) FrostErrorDetails(details: details),
          ],
        ),
      ),
    );
  }
}
