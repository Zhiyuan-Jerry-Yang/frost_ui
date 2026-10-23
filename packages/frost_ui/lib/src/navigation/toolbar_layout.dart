part of 'toolbar.dart';

enum _Kind { leading, leadingCompactMeasure, fullMeasure, compactMeasure, item, middle, moreMeasure, more }

enum _Form { full, compact, hidden }

enum _Middle { full, collapsed, hidden }

class _ToolbarIdentity {
  const _ToolbarIdentity(this.stage, this.forms, this.middle, this.leadingForms);
  final int stage;
  final List<_Form> forms;
  final List<_Form> leadingForms;
  final _Middle middle;
  @override
  bool operator ==(Object other) =>
      other is _ToolbarIdentity &&
      stage == other.stage &&
      middle == other.middle &&
      listEquals(forms, other.forms) &&
      listEquals(leadingForms, other.leadingForms);
  @override
  int get hashCode => Object.hash(stage, Object.hashAll(forms), middle, Object.hashAll(leadingForms));
}

class _Data extends ContainerBoxParentData<RenderBox> {
  _Kind kind = _Kind.leading;
  int index = 0;
  bool title = false, visible = false;
  double titleMinimum = 0;
  int shrinkPriority = 1;
}

class _ToolbarSlot extends ParentDataWidget<_Data> {
  const _ToolbarSlot({required this.kind, this.index = 0, this.title = false, this.titleMinimum = 0, this.shrinkPriority = 1, required super.child});
  final _Kind kind;
  final int index;
  final bool title;
  final double titleMinimum;
  final int shrinkPriority;
  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _Data;
    if (data.kind == kind && data.index == index && data.title == title && data.titleMinimum == titleMinimum && data.shrinkPriority == shrinkPriority) {
      return;
    }
    data.kind = kind;
    data.index = index;
    data.title = title;
    data.titleMinimum = titleMinimum;
    data.shrinkPriority = shrinkPriority;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ToolbarLayout;
}

class _ToolbarConstraints extends BoxConstraints {
  const _ToolbarConstraints(
    double width,
    double height, {
    this.form = _Form.full,
    this.middle = _Middle.full,
    this.overflow = const [],
    this.trailingEdge = false,
  }) : super(minWidth: width, maxWidth: width, maxHeight: height);
  final _Form form;
  final _Middle middle;
  final List<int> overflow;
  final bool trailingEdge;
  @override
  bool operator ==(Object other) =>
      other is _ToolbarConstraints &&
      super == other &&
      form == other.form &&
      middle == other.middle &&
      trailingEdge == other.trailingEdge &&
      listEquals(overflow, other.overflow);
  @override
  int get hashCode => Object.hash(super.hashCode, form, middle, Object.hashAll(overflow), trailingEdge);
}

class _ToolbarLayout extends MultiChildRenderObjectWidget {
  const _ToolbarLayout({
    required this.identity,
    required this.width,
    required this.minimumMiddle,
    required this.maximumMiddle,
    required this.collapsedWidth,
    required this.hasMiddle,
    required this.gap,
    required this.edgeInset,
    required this.startRoom,
    required this.endRoom,
    required this.minimumHeight,
    required this.direction,
    required this.items,
    required this.controlsCount,
    required this.iconInset,
    required super.children,
  });
  final FrostLayoutIdentity identity;
  final double width, minimumMiddle, maximumMiddle, collapsedWidth, gap, minimumHeight;
  final bool hasMiddle;
  final double? edgeInset;
  final double startRoom, endRoom;
  final TextDirection direction;
  final List<FrostToolbarItem> items;
  final int controlsCount;
  final double iconInset;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderToolbar(this);
  @override
  void updateRenderObject(BuildContext context, _RenderToolbar renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderToolbar extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderToolbar(this.config);
  _ToolbarLayout config;
  int stage = 0;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  @override
  void performLayout() {
    final leading = <RenderBox>[], live = <int, RenderBox>{};
    final full = <int, double>{}, compact = <int, double>{};
    final leadingCompact = <int, double>{};
    RenderBox? middle;
    late RenderBox more;
    var moreWidth = 0.0, height = config.minimumHeight;
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as _Data;
      data.visible = false;
      switch (data.kind) {
        case _Kind.item:
          live[data.index] = child;
        case _Kind.middle:
          middle = child;
        case _Kind.more:
          more = child;
        case _Kind.leading || _Kind.leadingCompactMeasure || _Kind.fullMeasure || _Kind.compactMeasure || _Kind.moreMeasure:
          child.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
          height = math.max(height, child.size.height);
          switch (data.kind) {
            case _Kind.leading:
              leading.add(child);
            case _Kind.leadingCompactMeasure:
              leadingCompact[data.index] = child.size.width;
            case _Kind.fullMeasure:
              full[data.index] = child.size.width;
            case _Kind.compactMeasure:
              compact[data.index] = child.size.width;
            case _Kind.moreMeasure:
              moreWidth = child.size.width;
            default:
              break;
          }
      }
    }
    final forms = List.filled(config.items.length, _Form.full);
    final leadWidths = [for (final child in leading) child.size.width];
    final leadingForms = List.filled(leading.length, _Form.full);
    var mode = config.hasMiddle ? _Middle.full : _Middle.hidden;
    var middleWidth = config.hasMiddle ? config.minimumMiddle : 0.0;
    double itemWidth(int index) => switch (forms[index]) {
      _Form.full => full[index]!,
      _Form.compact => compact[index]!,
      _Form.hidden => 0,
    };
    List<double> widths() => [
      ...leadWidths.where((w) => w > 0),
      if (middleWidth > 0) middleWidth,
      for (var i = 0; i < forms.length; i++)
        if (forms[i] != _Form.hidden) itemWidth(i),
      if (forms.contains(_Form.hidden)) moreWidth,
    ];
    double total() {
      final values = widths();
      return values.fold(0.0, (a, b) => a + b) + math.max(0, values.length - 1) * config.gap;
    }

    final available = config.width.isFinite ? config.width : total() + (config.hasMiddle ? config.maximumMiddle - config.minimumMiddle : 0);
    final order = List.generate(forms.length, (i) => i)
      ..sort((a, b) {
        final result = config.items[b].priority.index.compareTo(config.items[a].priority.index);
        if (result != 0) return result;
        // Merge an existing More/group into the shared overflow before hiding
        // peers. Replacing its trigger costs no width and prevents two Mores.
        final group = (config.items[b]._isOverflowGroup ? 1 : 0) - (config.items[a]._isOverflowGroup ? 1 : 0);
        return group == 0 ? a.compareTo(b) : group;
      });
    stage = 0;
    for (final entry in leadingCompact.entries) {
      if (total() <= available) break;
      leadWidths[entry.key] = entry.value;
      leadingForms[entry.key] = _Form.compact;
      stage = 1;
    }
    for (final picker in [false, true]) {
      for (final i in order) {
        if (total() <= available) break;
        final item = config.items[i];
        if (item._canCompact && item._isPicker == picker) {
          forms[i] = _Form.compact;
          stage = picker ? 2 : 1;
        }
      }
    }
    for (final i in order) {
      if (total() <= available) break;
      if (config.items[i].priority != FrostToolbarPriority.high) {
        forms[i] = _Form.hidden;
        stage = 3;
      }
    }
    void shrinkTitles() {
      final indices = [for (var i = 0; i < leading.length; i++) i]
        ..sort((a, b) {
          final priority = (leading[a].parentData! as _Data).shrinkPriority.compareTo((leading[b].parentData! as _Data).shrinkPriority);
          return priority == 0 ? a.compareTo(b) : priority;
        });
      for (final i in indices) {
        if (total() <= available) break;
        final data = leading[i].parentData! as _Data;
        if (data.title) {
          leadWidths[i] = math.max(data.titleMinimum, leadWidths[i] - (total() - available));
          stage = math.max(stage, 4);
        }
      }
    }

    shrinkTitles();
    if (total() > available && config.hasMiddle) {
      if (config.collapsedWidth > 0) {
        mode = _Middle.collapsed;
        middleWidth = config.collapsedWidth;
      } else {
        // A flexible editor without a declared alternative must keep its State
        // and focus. Give it the remaining space, with room for a text target and two affordances
        // as the minimum usable field; truly smaller rows use the existing scroll path.
        final minimum = math.min(config.minimumMiddle, config.minimumHeight * 3 + config.gap * 2);
        middleWidth = math.max(minimum, middleWidth - (total() - available));
      }
      stage = 5;
    }
    if (total() > available) stage = 6;
    if (mode == _Middle.full) middleWidth += math.min(config.maximumMiddle - middleWidth, math.max(0, available - total()));
    config.identity.update(_ToolbarIdentity(stage, List.unmodifiable(forms), mode, List.unmodifiable(leadingForms)), viewport: available);
    final contentWidth = math.max(available, total());
    final overflow = [
      for (var i = 0; i < forms.length; i++)
        if (forms[i] == _Form.hidden) i,
    ];
    final visible = <RenderBox>[];
    for (var i = 0; i < leading.length; i++) {
      leading[i].layout(_ToolbarConstraints(leadWidths[i], constraints.maxHeight, form: leadingForms[i]), parentUsesSize: true);
      if (leadWidths[i] > 0) visible.add(leading[i]);
    }
    final leadingCount = visible.length;
    var shownControls = 0;
    if (middle != null) {
      middle.layout(_ToolbarConstraints(middleWidth, constraints.maxHeight, middle: mode), parentUsesSize: true);
      if (mode != _Middle.hidden) visible.add(middle);
    }
    for (var i = 0; i < forms.length; i++) {
      live[i]!.layout(
        _ToolbarConstraints(
          forms[i] == _Form.hidden ? full[i]! : itemWidth(i),
          constraints.maxHeight,
          form: forms[i],
          trailingEdge: overflow.isEmpty && i == forms.lastIndexWhere((form) => form != _Form.hidden),
        ),
        parentUsesSize: true,
      );
      if (forms[i] != _Form.hidden) {
        if (i < config.controlsCount) {
          visible.insert(leadingCount + shownControls++, live[i]!);
        } else {
          visible.add(live[i]!);
        }
      }
    }
    more.layout(_ToolbarConstraints(overflow.isEmpty ? 0 : moreWidth, constraints.maxHeight, overflow: overflow), parentUsesSize: true);
    if (overflow.isNotEmpty) visible.add(more);
    for (final child in visible) {
      height = math.max(height, child.size.height);
    }
    size = constraints.constrain(Size(contentWidth, height + FrostGap.inline * 2));
    var cursor = 0.0;
    var atTrailing = false;
    final edgeInset = config.edgeInset;
    double? graphicInset(RenderBox box) {
      final data = box.parentData! as _Data;
      final icon = switch (data.kind) {
        _Kind.leading => false,
        _Kind.more => true,
        _Kind.item => switch (config.items[data.index]) {
          _Action(:final showsLabel) => !showsLabel || forms[data.index] == _Form.compact,
          _Menu(:final showsLabel) => !showsLabel,
          _ => false,
        },
        _ => false,
      };
      return icon ? config.iconInset : null;
    }

    final firstInset = visible.isEmpty ? null : graphicInset(visible.first);
    final lastInset = visible.isEmpty ? null : graphicInset(visible.last);
    final startShift = edgeInset == null || firstInset == null ? 0.0 : math.max(-config.startRoom, edgeInset - firstInset);
    final endShift = edgeInset == null || lastInset == null ? 0.0 : math.min(config.endRoom, lastInset - edgeInset);
    for (final child in visible) {
      final data = child.parentData! as _Data;
      data.visible = true;
      if (!atTrailing && (data.kind == _Kind.item && data.index >= config.controlsCount || data.kind == _Kind.more)) {
        atTrailing = true;
        final trailing = visible.where((child) {
          final data = child.parentData! as _Data;
          return data.kind == _Kind.item && data.index >= config.controlsCount || data.kind == _Kind.more;
        }).toList();
        final extent = trailing.fold(0.0, (sum, child) => sum + child.size.width) + math.max(0, trailing.length - 1) * config.gap;
        cursor = math.max(cursor, size.width - extent);
      }
      // Align the complete trailing cluster, never just its last glyph. Pure
      // icons retain the shared square plate and their mutual target spacing.
      final shift = atTrailing
          ? endShift
          : identical(child, visible.first)
          ? startShift
          : 0.0;
      final position = cursor + shift;
      data.offset = Offset(config.direction == TextDirection.ltr ? position : size.width - position - child.size.width, (size.height - child.size.height) / 2);
      cursor += child.size.width + config.gap;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in getChildrenAsList()) {
      final data = child.parentData! as _Data;
      if (data.visible) context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in getChildrenAsList().reversed) {
      final data = child.parentData! as _Data;
      if (data.visible &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, position) => child.hitTest(result, position: position),
          )) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final child in getChildrenAsList()) {
      if ((child.parentData! as _Data).visible) visitor(child);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('collapseStage', stage));
  }
}
