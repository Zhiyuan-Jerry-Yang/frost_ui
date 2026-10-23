import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_focus_outline.dart';

const testFonts = FrostFonts(japanese: 'JP', simplifiedChinese: 'SC', defaultScript: FrostContentScript.japanese);

/// Locate the public Frost wrapper even when its tooltip semantics are excluded.
Finder findFrostTooltip(String message) => find.byWidgetPredicate((widget) => widget is FrostTooltip && widget.message == message);

/// Inspect the same concentric outline used by shared fields and click surfaces.
Finder frostFocusRings() => find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is FrostFocusOutlinePainter);

const _glyph = FrostIconData.glyph(IconData(0xe000));

const testIcons = FrostIconSet(
  back: _glyph,
  close: FrostIconData.glyph(IconData(0xe001)),
  more: _glyph,
  expand: _glyph,
  collapse: _glyph,
  chevronLeft: _glyph,
  chevronRight: _glyph,
  chevronDown: _glyph,
  arrowDown: FrostIconData.glyph(IconData(0xe003)),
  refresh: _glyph,
  copy: _glyph,
  search: _glyph,
  check: FrostIconData.glyph(IconData(0xe002)),
  success: _glyph,
  info: _glyph,

  error: _glyph,
  empty: _glyph,
  sidebarExpand: _glyph,
  sidebarCollapse: _glyph,
  forward: _glyph,
  chevronUp: _glyph,
  chevronUpDown: _glyph,
  externalLink: _glyph,
  link: _glyph,
  share: _glyph,
  download: _glyph,
  upload: _glyph,
  delete: _glyph,
  edit: _glyph,
  add: _glyph,
  remove: _glyph,
  filter: _glyph,
  sort: _glyph,
  dragHandle: _glyph,
  play: _glyph,
  pause: _glyph,
  repeat: _glyph,
  volumeOn: _glyph,
  volumeOff: _glyph,
  fullscreen: _glyph,
  exitFullscreen: _glyph,
  zoomIn: _glyph,
  zoomOut: _glyph,
  image: _glyph,
  imageError: _glyph,
  multiPage: _glyph,
  minimize: _glyph,
  maximize: _glyph,
  restore: _glyph,
  calendar: _glyph,
  clock: _glyph,
  folder: _glyph,
  eye: _glyph,
  eyeOff: _glyph,
  user: _glyph,
  send: _glyph,
  attach: _glyph,
  textFormat: _glyph,
);

FrostLabels testLabels(BuildContext context) => const FrostLabels(
  retry: 'L.retry',
  retryAfter: _retryAfter,
  error: 'L.error',
  errorDetails: 'L.errorDetails',
  copyDetails: 'L.copyDetails',
  copied: 'L.copied',
  loading: 'L.loading',
  actionSucceeded: 'L.actionSucceeded',
  actionFailed: 'L.actionFailed',
  loadFailed: 'L.loadFailed',
  noMoreItems: 'L.noMoreItems',
  noItems: 'L.noItems',
  pullToRefresh: 'L.pullToRefresh',
  releaseToRefresh: 'L.releaseToRefresh',
  refreshing: 'L.refreshing',
  refreshComplete: 'L.refreshComplete',
  refreshFailed: 'L.refreshFailed',
  previous: 'L.previous',
  next: 'L.next',
  back: 'L.back',
  more: 'L.more',
  expandNavigation: 'L.expandNavigation',
  collapseNavigation: 'L.collapseNavigation',
  navigationStatus: _navigationStatus,
  clearText: 'L.clearText',
  search: 'L.search',
  noResults: _noResults,
  clearSearch: 'L.clearSearch',
  dismiss: 'L.dismiss',
  expandText: 'L.expandText',
  collapseText: 'L.collapseText',
  showAll: 'L.showAll',
  copy: 'L.copy',
  clearAll: 'L.clearAll',
  showPassword: 'L.showPassword',
  hidePassword: 'L.hidePassword',
  chooseDate: 'L.chooseDate',
  chooseTime: 'L.chooseTime',
  increment: 'L.increment',
  decrement: 'L.decrement',
  reorderHandle: 'L.reorderHandle',
  sortAscending: 'L.sortAscending',
  sortDescending: 'L.sortDescending',
  play: 'L.play',
  pause: 'L.pause',
  loop: 'L.loop',
  mute: 'L.mute',
  unmute: 'L.unmute',
  fullscreen: 'L.fullscreen',
  exitFullscreen: 'L.exitFullscreen',
  reload: 'L.reload',
  openInBrowser: 'L.openInBrowser',
  minimize: 'L.minimize',
  maximize: 'L.maximize',
  restore: 'L.restore',
  close: 'L.close',
  cancel: 'L.cancel',
  apply: 'L.apply',
  clear: 'L.clear',
  choose: 'L.choose',
  showInFolder: 'L.showInFolder',
  selectedCount: _selectedCount,
  pageOf: _pageOf,
  selectAll: 'L.selectAll',
  done: 'L.done',
  itemPosition: _itemPosition,
  tableDimensions: _tableDimensions,
  taskQueued: 'L.taskQueued',
  taskRunning: 'L.taskRunning',
  taskPaused: 'L.taskPaused',
  taskCompleted: 'L.taskCompleted',
  taskFailed: 'L.taskFailed',
  taskCancelled: 'L.taskCancelled',
  remove: 'L.remove',
  forward: 'L.forward',
  stop: 'L.stop',
  seek: 'L.seek',
  send: 'L.send',
  attach: 'L.attach',
  readerSettings: 'L.readerSettings',
  textSize: 'L.textSize',
  lineSpacing: 'L.lineSpacing',
  readingProgress: 'L.readingProgress',
  showReplies: _showReplies,
  characterCount: _characterCount,
  moreMedia: _moreMedia,
);

final testErrors = FrostErrorPresenter(message: (context, error) => 'E.message($error)', details: (error) => 'E.details($error)');

final testConfig = FrostConfig(palettes: FrostPalettes.pink, fonts: testFonts, icons: testIcons, labels: testLabels, errors: testErrors);

/// [child] inside a Frost theme, scope and toast host, on a desktop-sized
/// surface unless [size] says otherwise.
Widget frostTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool reduceTransparency = false,
  FrostDensity density = FrostDensity.comfortable,
  TargetPlatform platform = TargetPlatform.windows,
}) => FrostScope(
  config: testConfig,
  reduceTransparency: reduceTransparency,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: brightness, platform: platform, locale: const Locale('en'), density: density),
    builder: (context, child) => FrostToastHost(child: child!),
    home: child,
  ),
);

String _selectedCount(int count) => 'Selected $count';
String _noResults(String query) => 'L.noResults($query)';
String _pageOf(int page, int total) => '$page of $total';

String _itemPosition(int position, int total) => '$position / $total';

String _tableDimensions(int rows, int columns) => '$rows × $columns';

String _showReplies(int count) => 'L.showReplies($count)';
String _characterCount(int count, int limit) => '$count / $limit';
String _moreMedia(int count) => '+$count';

String _navigationStatus(int count, int? progressPercent) => 'L.navigationStatus($count,$progressPercent)';

String _retryAfter(int seconds) => 'L.retryAfter($seconds)';
