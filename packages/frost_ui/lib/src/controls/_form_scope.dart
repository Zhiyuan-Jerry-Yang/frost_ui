part of 'form.dart';

/// UI-only registrations. No notifier or widget rebuild is triggered by
/// registration in lifecycle/build, so a complete cold frame stays legal.
class FrostFormFieldHandle {
  FrostFormFieldHandle({required this.context, required this.focusOf, required this.errorOf, required this.enabledOf});
  final BuildContext context;
  final FocusNode? Function() focusOf;
  final bool Function() errorOf, enabledOf;
  List<int> order = const [];
  Future<bool> Function()? beforeSubmit;
  FocusNode? get focus => focusOf();
  bool get hasError => errorOf();
  bool get eligible => context.mounted && enabledOf();
  bool get canFocus => eligible && focus != null && focus!.canRequestFocus;
  Future<bool> prepare() => beforeSubmit?.call() ?? Future<bool>.value(true);
}

class FrostFormCoordinator {
  FrostFormCoordinator({required this.submit});
  final Future<bool> Function() submit;
  final _fields = <FrostFormFieldHandle>[];
  void register(FrostFormFieldHandle field) {
    if (!_fields.contains(field)) _fields.add(field);
  }

  void unregister(FrostFormFieldHandle field) => _fields.remove(field);
  List<FrostFormFieldHandle> get orderedFields {
    final ordered = _fields.where((field) => field.context.mounted).toList();
    ordered.sort((a, b) {
      for (var index = 0; index < a.order.length && index < b.order.length; index++) {
        final compare = a.order[index].compareTo(b.order[index]);
        if (compare != 0) return compare;
      }
      return _fields.indexOf(a).compareTo(_fields.indexOf(b));
    });
    return ordered;
  }

  TextInputAction actionFor(FrostFormFieldHandle field) {
    // A Picker's live menu focus can be created later in this same layout.
    // Eligibility is known at registration and keeps cold-frame actions exact.
    final fields = orderedFields.where((field) => field.eligible).toList();
    return fields.isNotEmpty && identical(fields.last, field) ? TextInputAction.done : TextInputAction.next;
  }

  void completeEditing(FrostFormFieldHandle field) {
    final fields = orderedFields.where((field) => field.canFocus).toList(), index = fields.indexOf(field);
    if (index >= 0 && index < fields.length - 1) {
      fields[index + 1].focus!.requestFocus();
    } else {
      submit();
    }
  }

  void dispose() => _fields.clear();
}

class FrostFormScope extends InheritedWidget {
  const FrostFormScope({required this.coordinator, required super.child, super.key});
  final FrostFormCoordinator coordinator;
  static FrostFormCoordinator? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostFormScope>()?.coordinator;
  @override
  bool updateShouldNotify(FrostFormScope oldWidget) => coordinator != oldWidget.coordinator;
}

class FrostFormOrder extends InheritedWidget {
  const FrostFormOrder({required this.order, required super.child, super.key});
  final List<int> order;
  static List<int> of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostFormOrder>()?.order ?? const [];
  @override
  bool updateShouldNotify(FrostFormOrder oldWidget) => !listEquals(order, oldWidget.order);
}

/// Shared registration for non-text editors; input controllers stay in owners.
class FrostFormFieldRegistration extends StatefulWidget {
  const FrostFormFieldRegistration({required this.focusOf, required this.enabled, required this.error, required this.child, super.key});
  final FocusNode? Function() focusOf;
  final bool enabled;
  final String? error;
  final Widget child;
  @override
  State<FrostFormFieldRegistration> createState() => _FieldRegistrationState();
}

class _FieldRegistrationState extends State<FrostFormFieldRegistration> {
  FrostFormCoordinator? _coordinator;
  late final _field = FrostFormFieldHandle(
    context: context,
    focusOf: () => widget.focusOf(),
    errorOf: () => widget.error != null,
    enabledOf: () => widget.enabled,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = FrostFormScope.maybeOf(context);
    if (_coordinator != coordinator) {
      _coordinator?.unregister(_field);
      _coordinator = coordinator;
      _coordinator?.register(_field);
    }
    _field.order = FrostFormOrder.of(context);
  }

  @override
  void dispose() {
    _coordinator?.unregister(_field);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
