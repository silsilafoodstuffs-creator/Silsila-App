import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard navigation for ERP forms and data grids.
/// Enter advances between single-line fields; arrow keys move focus between
/// controls when the user is not editing text. Native text-caret and dropdown
/// arrow behavior is preserved.
class ErpKeyboardNavigation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    clearActions();
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final primary = FocusManager.instance.primaryFocus;
          final focusedWidget = primary?.context?.widget;

          if (event.logicalKey == LogicalKeyboardKey.f12) {
            final action = onF12Add;
            if (action != null) { action(); return KeyEventResult.handled; }
          }
          if (event.logicalKey == LogicalKeyboardKey.f8) {
            final action = onF8Save;
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
        child: child,
      ),
    );
  }
}
