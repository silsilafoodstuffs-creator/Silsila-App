import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard navigation for ERP forms and data grids.
/// Enter advances between single-line fields; arrow keys move focus between
/// controls when the user is not editing text. Native text-caret and dropdown
/// arrow behavior is preserved.
class ErpKeyboardNavigation extends StatefulWidget {
  const ErpKeyboardNavigation({super.key, required this.child});

  final Widget child;

  /// Actions registered by the currently visible ERP data-entry screen.
  static VoidCallback? onF12Add;
  static VoidCallback? onF8Save;

  static void registerActions({VoidCallback? add, VoidCallback? save}) {
    onF12Add = add;
    onF8Save = save;
  }

  static void clearActions() {
    onF12Add = null;
    onF8Save = null;
  }

  @override
  State<ErpKeyboardNavigation> createState() => _ErpKeyboardNavigationState();
}

class _ErpKeyboardNavigationState extends State<ErpKeyboardNavigation> {
  @override
  void didUpdateWidget(covariant ErpKeyboardNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear stale callbacks only when the wrapped screen changes. Do not clear
    // them on ordinary focus/parent rebuilds: a child screen may not rebuild.
    if (oldWidget.child != widget.child) {
      ErpKeyboardNavigation.clearActions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final primary = FocusManager.instance.primaryFocus;
          final focusedWidget = primary?.context?.widget;

          if (event.logicalKey == LogicalKeyboardKey.f12) {
            final action = ErpKeyboardNavigation.onF12Add;
            if (action != null) { action(); return KeyEventResult.handled; }
          }
          if (event.logicalKey == LogicalKeyboardKey.f8) {
            final action = ErpKeyboardNavigation.onF8Save;
            if (action != null) { action(); return KeyEventResult.handled; }
          }

          if (event.logicalKey == LogicalKeyboardKey.enter &&
              focusedWidget is EditableText &&
              (focusedWidget.maxLines == null || focusedWidget.maxLines == 1)) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          }

          // Do not steal arrow keys from text fields, dropdowns, or other
          // controls that use them for their own native interaction.
          if (focusedWidget is EditableText ||
              focusedWidget is DropdownButton ||
              focusedWidget is DropdownButtonFormField) {
            return KeyEventResult.ignored;
          }

          final direction = switch (event.logicalKey) {
            LogicalKeyboardKey.arrowUp => TraversalDirection.up,
            LogicalKeyboardKey.arrowDown => TraversalDirection.down,
            LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
            LogicalKeyboardKey.arrowRight => TraversalDirection.right,
            _ => null,
          };
          if (direction != null) {
            primary?.focusInDirection(direction);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}

/// Registers the current screen's add/save actions with the shared keyboard handler.
class ErpKeyboardActionRegistrar extends StatelessWidget {
  const ErpKeyboardActionRegistrar({super.key, required this.child, this.add, this.save});
  final Widget child;
  final VoidCallback? add;
  final VoidCallback? save;

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: add, save: save);
    return child;
  }
}
