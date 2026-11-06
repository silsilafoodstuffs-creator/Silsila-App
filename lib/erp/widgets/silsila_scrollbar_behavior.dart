import 'package:flutter/material.dart';

/// Keeps overflowing ERP content discoverable on desktop and web.
/// Horizontal bars stay at the bottom; vertical bars follow Directionality
/// (left side in the Arabic RTL interface).
class SilsilaScrollbarBehavior extends MaterialScrollBehavior {
  const SilsilaScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 7,
      radius: const Radius.circular(8),
      child: child,
    );
  }
}
