import 'package:flutter/material.dart';

/// A text sample shaped ahead of time, in the locale it is drawn in.
@immutable
class FrostFontWarmUpSample {
  const FrostFontWarmUpSample({required this.locale, required this.text});

  final Locale locale;
  final String text;
}

/// Shapes [samples] in the theme's body font, regular and bold, whenever the
/// font chain or locale changes, so the first frame of navigation and
/// settings text does not stall on font loading. The app supplies the
/// samples: its navigation labels and the characters its pages use first.
class FrostFontWarmUp extends StatefulWidget {
  const FrostFontWarmUp({required this.samples, required this.child, super.key});

  final List<FrostFontWarmUpSample> Function(BuildContext context) samples;
  final Widget child;

  @override
  State<FrostFontWarmUp> createState() => _FrostFontWarmUpState();
}

class _FrostFontWarmUpState extends State<FrostFontWarmUp> {
  static const _weights = [FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600];
  int? _warmedConfiguration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final configuration = Object.hash(baseStyle.fontFamily, Object.hashAll(baseStyle.fontFamilyFallback ?? const []), Localizations.localeOf(context));
    if (_warmedConfiguration == configuration) return;
    _warmedConfiguration = configuration;
    final samples = widget.samples(context);
    for (final weight in _weights) {
      final style = baseStyle.copyWith(fontWeight: weight);
      for (final sample in samples) {
        TextPainter(
            text: TextSpan(text: sample.text, style: style),
            textDirection: TextDirection.ltr,
            locale: sample.locale,
            maxLines: 1,
          )
          ..layout(maxWidth: 2048)
          ..dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
