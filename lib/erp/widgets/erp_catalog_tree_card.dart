import 'package:flutter/material.dart';

/// Shared shell for catalog tree nodes.
///
/// Screens provide their own fields and actions while this widget standardizes
/// indentation, selection, borders, tap behavior, and spacing.
class ErpCatalogTreeCard extends StatelessWidget {
  const ErpCatalogTreeCard({
    super.key,
    required this.child,
    required this.depth,
    required this.selected,
    required this.backgroundColor,
    required this.selectedColor,
    required this.borderColor,
    required this.selectedBorderColor,
    this.onTap,
    this.onDoubleTap,
    this.padding = const EdgeInsets.all(8),
    this.indentPerLevel = 18,
    this.bottomSpacing = 6,
  });

  final Widget child;
  final int depth;
  final bool selected;
  final Color backgroundColor;
  final Color selectedColor;
  final Color borderColor;
  final Color selectedBorderColor;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final EdgeInsetsGeometry padding;
  final double indentPerLevel;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: depth * indentPerLevel,
        bottom: bottomSpacing,
      ),
      child: Material(
        color: selected ? selectedColor : backgroundColor,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? selectedBorderColor : borderColor,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
