import 'package:flutter/widgets.dart';

enum FrostFieldAppearance { standard, composer }

/// Internal field behavior for composed inputs. Validation can tint chrome
/// without inventing supporting prose; numeric content keeps tabular figures.
class FrostFieldOptions extends InheritedWidget {
  const FrostFieldOptions({
    this.semanticHint,
    this.invalid = false,
    this.appearance = FrostFieldAppearance.standard,
    this.numeric = false,
    this.supportingTrailing,
    this.beforeSubmit,
    required super.child,
    super.key,
  });
  final bool invalid, numeric;
  final FrostFieldAppearance appearance;
  final String? semanticHint;
  final Widget? supportingTrailing;
  final Future<bool> Function()? beforeSubmit;
  static FrostFieldOptions? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostFieldOptions>();
  @override
  bool updateShouldNotify(FrostFieldOptions oldWidget) =>
      semanticHint != oldWidget.semanticHint ||
      invalid != oldWidget.invalid ||
      appearance != oldWidget.appearance ||
      numeric != oldWidget.numeric ||
      supportingTrailing != oldWidget.supportingTrailing ||
      beforeSubmit != oldWidget.beforeSubmit;
}
