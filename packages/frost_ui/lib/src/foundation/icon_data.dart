import 'package:flutter/widgets.dart';

import 'scope.dart';

/// An icon supplied by the app. The library ships no icon files: an app
/// supplies its own icon font, generated from app-owned source artwork.
@immutable
sealed class FrostIconData {
  const FrostIconData();

  /// A font glyph.
  const factory FrostIconData.glyph(IconData data) = FrostGlyphIcon;
}

final class FrostGlyphIcon extends FrostIconData {
  const FrostGlyphIcon(this.data);

  final IconData data;

  @override
  bool operator ==(Object other) => other is FrostGlyphIcon && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

/// The icons Frost components draw themselves. Every slot is required; an
/// app maps each to its own icon set.
@immutable
class FrostIconSet {
  const FrostIconSet({
    required this.back,
    required this.forward,
    required this.close,
    required this.more,
    required this.chevronLeft,
    required this.chevronRight,
    required this.chevronUp,
    required this.chevronDown,
    required this.arrowDown,
    required this.chevronUpDown,
    required this.expand,
    required this.collapse,
    required this.sidebarExpand,
    required this.sidebarCollapse,
    required this.externalLink,
    required this.link,
    required this.search,
    required this.refresh,
    required this.copy,
    required this.share,
    required this.download,
    required this.upload,
    required this.delete,
    required this.edit,
    required this.add,
    required this.remove,
    required this.filter,
    required this.sort,
    required this.check,
    required this.dragHandle,
    required this.success,
    required this.info,
    required this.error,
    required this.empty,
    required this.play,
    required this.pause,
    required this.repeat,
    required this.volumeOn,
    required this.volumeOff,
    required this.fullscreen,
    required this.exitFullscreen,
    required this.zoomIn,
    required this.zoomOut,
    required this.image,
    required this.imageError,
    required this.multiPage,
    required this.minimize,
    required this.maximize,
    required this.restore,
    required this.calendar,
    required this.clock,
    required this.folder,
    required this.eye,
    required this.eyeOff,
    required this.user,
    required this.send,
    required this.attach,
    required this.textFormat,
  });

  final FrostIconData back;
  final FrostIconData forward;
  final FrostIconData close;
  final FrostIconData more;
  final FrostIconData chevronLeft;
  final FrostIconData chevronRight;
  final FrostIconData chevronUp;
  final FrostIconData chevronDown;

  /// Downward pull-to-refresh arrow; the header rotates it when armed.
  final FrostIconData arrowDown;
  final FrostIconData chevronUpDown;
  final FrostIconData expand;
  final FrostIconData collapse;
  final FrostIconData sidebarExpand;
  final FrostIconData sidebarCollapse;
  final FrostIconData externalLink;
  final FrostIconData link;
  final FrostIconData search;
  final FrostIconData refresh;
  final FrostIconData copy;
  final FrostIconData share;
  final FrostIconData download;
  final FrostIconData upload;
  final FrostIconData delete;
  final FrostIconData edit;
  final FrostIconData add;
  final FrostIconData remove;
  final FrostIconData filter;
  final FrostIconData sort;
  final FrostIconData check;
  final FrostIconData dragHandle;
  final FrostIconData success;
  final FrostIconData info;
  final FrostIconData error;
  final FrostIconData empty;
  final FrostIconData play;
  final FrostIconData pause;
  final FrostIconData repeat;
  final FrostIconData volumeOn;
  final FrostIconData volumeOff;
  final FrostIconData fullscreen;
  final FrostIconData exitFullscreen;
  final FrostIconData zoomIn;
  final FrostIconData zoomOut;
  final FrostIconData image;
  final FrostIconData imageError;
  final FrostIconData multiPage;
  final FrostIconData minimize;
  final FrostIconData maximize;
  final FrostIconData restore;
  final FrostIconData calendar;
  final FrostIconData clock;
  final FrostIconData folder;
  final FrostIconData eye;
  final FrostIconData eyeOff;
  final FrostIconData user;
  final FrostIconData send, attach, textFormat;

  /// The icon set of the nearest [FrostScope].
  static FrostIconSet of(BuildContext context) => FrostScope.configOf(context).icons;
}
