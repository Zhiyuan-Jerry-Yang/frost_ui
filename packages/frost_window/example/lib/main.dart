import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

// Manual test bench for the native window: caption drag and double-click,
// edge and corner resizing (including over the right-edge scrollbar), Snap
// Layouts on the maximize button, the system menu (right-click, Alt+Space),
// Back (Alt+Left, mouse back button) and keyboard/IME input in a text field.

final _config = FrostConfig(
  palettes: FrostPalettes.pink,
  fonts: const FrostFonts(japanese: 'Yu Gothic UI', simplifiedChinese: 'Microsoft YaHei UI', defaultScript: FrostContentScript.japanese),
  icons: const FrostIconSet(
    back: FrostIconData.glyph(Icons.arrow_back),
    close: FrostIconData.glyph(Icons.close),
    more: FrostIconData.glyph(Icons.more_horiz),
    expand: FrostIconData.glyph(Icons.expand_more),
    collapse: FrostIconData.glyph(Icons.expand_less),
    chevronLeft: FrostIconData.glyph(Icons.chevron_left),
    chevronRight: FrostIconData.glyph(Icons.chevron_right),
    chevronDown: FrostIconData.glyph(Icons.keyboard_arrow_down),
    arrowDown: FrostIconData.glyph(Icons.arrow_downward),
    refresh: FrostIconData.glyph(Icons.refresh),
    copy: FrostIconData.glyph(Icons.copy),
    search: FrostIconData.glyph(Icons.search),
    check: FrostIconData.glyph(Icons.check),
    success: FrostIconData.glyph(Icons.check_circle),
    info: FrostIconData.glyph(Icons.info_outline),

    error: FrostIconData.glyph(Icons.error_outline),
    empty: FrostIconData.glyph(Icons.inbox_outlined),
    sidebarExpand: FrostIconData.glyph(Icons.keyboard_double_arrow_right),
    sidebarCollapse: FrostIconData.glyph(Icons.keyboard_double_arrow_left),
    forward: FrostIconData.glyph(Icons.arrow_forward),
    chevronUp: FrostIconData.glyph(Icons.keyboard_arrow_up),
    chevronUpDown: FrostIconData.glyph(Icons.unfold_more),
    externalLink: FrostIconData.glyph(Icons.open_in_new),
    link: FrostIconData.glyph(Icons.link),
    share: FrostIconData.glyph(Icons.share),
    download: FrostIconData.glyph(Icons.download),
    upload: FrostIconData.glyph(Icons.upload),
    delete: FrostIconData.glyph(Icons.delete_outline),
    edit: FrostIconData.glyph(Icons.edit_outlined),
    add: FrostIconData.glyph(Icons.add),
    remove: FrostIconData.glyph(Icons.remove),
    filter: FrostIconData.glyph(Icons.filter_list),
    sort: FrostIconData.glyph(Icons.sort),
    dragHandle: FrostIconData.glyph(Icons.drag_handle),
    play: FrostIconData.glyph(Icons.play_arrow),
    pause: FrostIconData.glyph(Icons.pause),
    repeat: FrostIconData.glyph(Icons.repeat),
    volumeOn: FrostIconData.glyph(Icons.volume_up),
    volumeOff: FrostIconData.glyph(Icons.volume_off),
    fullscreen: FrostIconData.glyph(Icons.fullscreen),
    exitFullscreen: FrostIconData.glyph(Icons.fullscreen_exit),
    zoomIn: FrostIconData.glyph(Icons.zoom_in),
    zoomOut: FrostIconData.glyph(Icons.zoom_out),
    image: FrostIconData.glyph(Icons.image_outlined),
    imageError: FrostIconData.glyph(Icons.broken_image_outlined),
    multiPage: FrostIconData.glyph(Icons.collections),
    minimize: FrostIconData.glyph(Icons.minimize),
    maximize: FrostIconData.glyph(Icons.crop_square),
    restore: FrostIconData.glyph(Icons.filter_none),
    calendar: FrostIconData.glyph(Icons.calendar_today),
    clock: FrostIconData.glyph(Icons.schedule),
    folder: FrostIconData.glyph(Icons.folder_outlined),
    eye: FrostIconData.glyph(Icons.visibility),
    eyeOff: FrostIconData.glyph(Icons.visibility_off),
    user: FrostIconData.glyph(Icons.person_outline),
    send: FrostIconData.glyph(Icons.send),
    attach: FrostIconData.glyph(Icons.attach_file),
    textFormat: FrostIconData.glyph(Icons.text_fields),
  ),
  labels: (context) => const FrostLabels(
    retry: '重试窗口初始化',
    retryAfter: _retryAfter,
    error: 'Error',
    errorDetails: 'Details',
    copyDetails: 'Copy',
    copied: 'Copied',
    loading: 'Loading',
    actionSucceeded: 'Action succeeded',
    actionFailed: 'Action failed',
    loadFailed: 'Could not load',
    noMoreItems: 'Nothing more',
    noItems: 'No items',
    pullToRefresh: 'Pull to refresh',
    releaseToRefresh: 'Release to refresh',
    refreshing: 'Refreshing',
    refreshComplete: 'Updated',
    refreshFailed: 'Refresh failed',
    previous: 'Previous',
    next: 'Next',
    back: 'Back',
    more: 'More',
    expandNavigation: 'Expand',
    collapseNavigation: 'Collapse',
    navigationStatus: _navigationStatus,
    clearText: 'Clear',
    search: 'Search',
    noResults: _noResults,
    clearSearch: 'Clear search',
    dismiss: 'Dismiss',
    expandText: 'expandText',
    collapseText: 'collapseText',
    showAll: 'showAll',
    copy: 'copy',
    clearAll: 'clearAll',
    showPassword: 'showPassword',
    hidePassword: 'hidePassword',
    chooseDate: 'chooseDate',
    chooseTime: 'chooseTime',
    increment: 'increment',
    decrement: 'decrement',
    reorderHandle: 'reorderHandle',
    sortAscending: 'sortAscending',
    sortDescending: 'sortDescending',
    play: 'play',
    pause: 'pause',
    loop: 'Loop',
    mute: 'mute',
    unmute: 'unmute',
    fullscreen: 'fullscreen',
    exitFullscreen: 'exitFullscreen',
    reload: 'reload',
    openInBrowser: 'openInBrowser',
    minimize: '最小化',
    maximize: '最大化',
    restore: '还原',
    close: '关闭',
    cancel: '取消',
    apply: '应用',
    clear: '清除',
    choose: '选择…',
    showInFolder: '在文件夹中显示',
    selectedCount: _selectedCount,
    pageOf: _pageOf,
    selectAll: 'Select all',
    done: 'Done',
    itemPosition: _itemPosition,
    tableDimensions: _tableDimensions,
    taskQueued: 'Queued',
    taskRunning: 'Running',
    taskPaused: 'Paused',
    taskCompleted: 'Completed',
    taskFailed: 'Failed',
    taskCancelled: 'Cancelled',
    remove: 'Remove',
    forward: 'Forward',
    stop: 'Stop',
    seek: 'Playback position',
    send: 'Send',
    attach: 'Attach',
    readerSettings: 'Reading settings',
    textSize: 'Text size',
    lineSpacing: 'Line spacing',
    readingProgress: 'Reading progress',
    showReplies: _showReplies,
    characterCount: _characterCount,
    moreMedia: _moreMedia,
  ),
  errors: FrostErrorPresenter(message: (context, error) => 'Something went wrong', details: (error) => '$error'),
);

final _window = FrostWindowController(minimumSize: const Size(480, 360), diagnosticWriter: (diagnostic) async => debugPrint('frost_window: $diagnostic'));

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

enum _SidebarChoice { inset, flush, capsule }

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;
  bool _mica = true;
  _SidebarChoice _style = _SidebarChoice.inset;
  FrostNavItemForm _form = FrostNavItemForm.tile;
  int _selected = 0;
  final _homeKey = GlobalKey<_HomePageState>();
  late final _delegate = _ExampleRouter((context) => _HomePage(key: _homeKey, settings: _settings()));
  late final _router = RouterConfig<Object>(routerDelegate: _delegate);

  void _change(VoidCallback change) {
    setState(change);
    _delegate.refresh();
  }

  void _back() {
    final navigator = _delegate.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      _homeKey.currentState?._back();
    }
  }

  Widget _settings() => Wrap(
    spacing: FrostGap.related,
    runSpacing: FrostGap.related,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FrostButton(
        label: '切换亮暗',
        size: FrostControlSize.compact,
        onPressed: () => _change(() => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
      ),
      FrostButton(label: _mica ? 'Mica: on' : 'Mica: off', size: FrostControlSize.compact, onPressed: () => _change(() => _mica = !_mica)),
      FrostPicker.menu(
        value: _style,
        options: const [
          FrostPickerOption(value: _SidebarChoice.inset, label: 'inset'),
          FrostPickerOption(value: _SidebarChoice.flush, label: 'flush'),
          FrostPickerOption(value: _SidebarChoice.capsule, label: 'capsule'),
        ],
        onChanged: (value) => _change(() => _style = value),
        label: 'Choice',
      ),
      if (_style == _SidebarChoice.flush)
        FrostPicker.menu(
          value: _form,
          options: const [
            FrostPickerOption(value: FrostNavItemForm.tile, label: 'tile'),
            FrostPickerOption(value: FrostNavItemForm.indicator, label: 'indicator'),
          ],
          onChanged: (value) => _change(() => _form = value),
          label: 'Choice',
        ),
    ],
  );

  @override
  void dispose() {
    _delegate.dispose();
    _window.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostApp.router(
    config: _config,
    title: 'Frost 正式外壳',
    routerConfig: _router,
    density: FrostDensity.compact,
    appearance: FrostAppearance(mode: _mode, lightAccent: _config.palettes.accentPresets.first, darkAccent: _config.palettes.accentPresets.first),
    builder: (context, child) => FrostWindowHost(
      backdrop: _mica ? FrostWindowBackdrop.mica : FrostWindowBackdrop.none,
      controller: _window,
      title: 'Frost 正式外壳 · 原生窗口验证',
      child: FrostShell(
        destinations: const [
          FrostNavDestination(icon: FrostIconData.glyph(Icons.home_outlined), label: '首页'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: '搜索'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.download_outlined), label: '下载'),
          FrostNavDestination(icon: FrostIconData.glyph(Icons.settings_outlined), label: '设置'),
        ],
        selectedIndex: _selected,
        atDestinationRoot: true,
        onDestinationSelected: (value) => setState(() => _selected = value),
        canGoBack: true,
        onBack: _back,
        showsMobileNavigation: true,
        initiallyExpanded: true,
        sidebarStyle: switch (_style) {
          _SidebarChoice.inset => const FrostSidebarStyle.inset(),
          _SidebarChoice.flush => FrostSidebarStyle.flush(itemForm: _form),
          _SidebarChoice.capsule => const FrostSidebarStyle.capsule(),
        },
        brand: const FrostText('Frost', role: FrostTextRole.headline),
        child: child!,
      ),
    ),
  );
}

class _ExampleRouter extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _ExampleRouter(this.builder);
  void refresh() => notifyListeners();
  final WidgetBuilder builder;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        child: FrostShellDestination(child: Builder(builder: builder)),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.settings, super.key});
  final Widget settings;
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  // The header uses the same input base for plain text and completed tokens.
  final _search = FrostTokenEditingController(
    rules: [FrostTokenRule(pattern: RegExp(r'^#'), tone: FrostTokenTone.accent)],
  );
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  int _backs = 0;
  int _source = 0;
  static const _sourceNames = ['主数据源 · 公共作品资料库', '备用数据源 · 本地作品资料库'];
  int _mode = 0;
  String _period = '本周';
  String _feedback = '拖动顶部空白/品牌；页眉和输入区不应拖动窗口。';

  void _report(String message) {
    if (mounted) setState(() => _feedback = message);
  }

  void _back() => setState(() {
    _backs++;
    _feedback = '收到返回请求：$_backs（Alt+Left / 鼠标后退）';
  });
  Future<void> _systemMenu() async {
    try {
      await _window.showSystemMenu();
    } on FrostWindowFailure {
      _report('系统菜单不可用，请重试窗口初始化');
    }
  }

  Future<void> _push() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _DetailPage()));
    if (mounted) _report('已从详情页返回');
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      FrostBackIntent: CallbackAction<FrostBackIntent>(
        onInvoke: (_) {
          _back();
          return null;
        },
      ),
    },
    child: Focus(
      autofocus: true,
      child: FrostPinnedChrome(
        chrome: FrostPageHeader(
          title: FrostTitleMenu(
            title: _sourceNames[_source],
            entries: [
              FrostMenuSection(
                header: '数据源',
                entries: [for (var i = 0; i < 2; i++) FrostMenuAction(_sourceNames[i], checked: _source == i, onSelected: () => setState(() => _source = i))],
              ),
            ],
          ),
          middle: FrostSearchInput(controller: _search, focusNode: _searchFocus, placeholder: '搜索', onSubmitted: (value) => _report('搜索提交：$value')),
          collapsedMiddle: FrostButton.icon(label: '搜索', icon: _config.icons.search, onPressed: () => _report('窄窗口搜索入口')),
          actions: [
            FrostToolbarItem.picker(
              choices: const [
                FrostPickerOption(value: 0, label: '最新'),
                FrostPickerOption(value: 1, label: '热门'),
                FrostPickerOption(value: 2, label: '历史'),
              ],
              value: _mode,
              onChanged: (value) => setState(() => _mode = value),
              label: '浏览模式',
            ),
            FrostToolbarItem.menu(
              label: _period,
              entries: [
                FrostMenuSection(
                  header: '时间范围',
                  entries: [
                    for (final period in ['今天', '本周', '本月'])
                      FrostMenuAction(period, checked: _period == period, onSelected: () => setState(() => _period = period)),
                  ],
                ),
                const FrostMenuDivider(),
                FrostMenuAction('选择日期…', icon: _config.icons.calendar, onSelected: () => _report('已打开选择日期入口（示例提示）')),
              ],
            ),
            FrostToolbarItem.action(icon: _config.icons.refresh, label: '刷新内容', showsLabel: true, onPressed: () => _report('已刷新内容')),
            FrostToolbarItem.action(icon: _config.icons.forward, label: '打开详情页', priority: FrostToolbarPriority.high, onPressed: () => unawaited(_push())),
            FrostToolbarItem.action(icon: _config.icons.download, label: '下载', priority: FrostToolbarPriority.low, onPressed: () => _report('下载示例操作')),
          ],
        ),
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                const FrostChromeSpacer(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: FrostGap.of(context).page),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.settings,
                        const SizedBox(height: FrostGap.related),
                        const FrostText('页眉与原生窗口验证', role: FrostTextRole.title2),
                        const SizedBox(height: FrostGap.related),
                        Semantics(
                          liveRegion: true,
                          child: FrostText(_feedback, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, maxLines: 2),
                        ),
                        ValueListenableBuilder(
                          valueListenable: _window,
                          builder: (context, state, _) => FrostText(
                            'backdrop: ${state.backdropActive} · solid: ${state.reduceTransparency} · ready: ${_window.ready} · failed: ${_window.failed} ${_window.failureCode ?? ''} · active: ${state.active} · maximized: ${state.maximized} · dpr: ${MediaQuery.devicePixelRatioOf(context)} · revision: ${state.revision}',
                            role: FrostTextRole.caption,
                            tone: FrostTextTone.tertiary,
                            maxLines: 2,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FrostButton(
                            label: '系统菜单',
                            size: FrostControlSize.compact,
                            variant: FrostButtonVariant.plain,
                            onPressed: () => unawaited(_systemMenu()),
                          ),
                        ),
                        const TextField(
                          decoration: InputDecoration(labelText: '键盘与中文输入法', hintText: '在这里输入中文和英文'),
                        ),
                        const SizedBox(height: FrostGap.related),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: FrostGap.of(context).page,
                    right: FrostGap.of(context).page,
                    bottom: FrostGap.of(context).page + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.builder(
                    itemCount: 60,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
                      child: FrostText('第 ${index + 1} 行 · 拖动右侧滚动条，检查缩放边框是否侵入内容', tone: FrostTextTone.secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FrostPageHeader(
        title: const Text('详情页'),
        actions: [
          FrostToolbarItem.action(icon: _config.icons.copy, label: '复制', onPressed: () => FrostToast.info('已触发复制示例')),
          FrostToolbarItem.action(icon: _config.icons.info, label: '信息', onPressed: () => FrostToast.info('普通标题与两个操作')),
        ],
      ),
      const Expanded(child: Center(child: FrostText('Alt+Left 或鼠标后退返回；标题行仍可操作。'))),
    ],
  );
}

String _selectedCount(int count) => 'Selected $count';
String _noResults(String query) => 'No results for “$query”';
String _pageOf(int page, int total) => '$page of $total';

String _itemPosition(int position, int total) => '$position / $total';

String _tableDimensions(int rows, int columns) => '$rows × $columns';

String _showReplies(int count) => 'Show $count replies';
String _characterCount(int count, int limit) => '$count of $limit characters';
String _moreMedia(int count) => '+$count';

String _navigationStatus(int count, int? progressPercent) => [if (count > 0) '$count items', if (progressPercent != null) '$progressPercent%'].join(', ');

String _retryAfter(int seconds) => 'Retry in ${seconds}s';
