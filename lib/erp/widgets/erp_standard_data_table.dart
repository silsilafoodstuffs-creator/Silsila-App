import 'package:flutter/material.dart';

/// Shared ERP table metrics and header treatment.
///
/// New catalog screens should use this wrapper instead of setting row metrics
/// independently so the compact ERP table contract stays consistent.
///
/// Keep table-specific columns and row actions in the screen; this widget owns
/// the consistent density and visual defaults used across ERP catalogs.
class ErpStandardDataTable extends StatelessWidget {
  const ErpStandardDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headingColor = const Color(0xFFF5EFFB),
    this.headingHeight = 40,
    this.rowHeight = 40,
    this.horizontalMargin = 5,
    this.columnSpacing = 5,
    this.dividerThickness = 0.7,
    this.headingTextStyle,
    this.dataTextStyle,
    this.checkboxHorizontalMargin,
    this.onSelectAll,
    this.showCheckboxColumn = true,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Color headingColor;
  final double headingHeight;
  final double rowHeight;
  final double horizontalMargin;
  final double columnSpacing;
  final double dividerThickness;
  final TextStyle? headingTextStyle;
  final TextStyle? dataTextStyle;
  final double? checkboxHorizontalMargin;
  final ValueChanged<bool?>? onSelectAll;
  final bool showCheckboxColumn;
  final int? sortColumnIndex;
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(headingColor),
      headingRowHeight: headingHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      horizontalMargin: horizontalMargin,
      columnSpacing: columnSpacing,
      dividerThickness: dividerThickness,
      headingTextStyle: headingTextStyle,
      dataTextStyle: dataTextStyle,
      checkboxHorizontalMargin: checkboxHorizontalMargin,
      onSelectAll: onSelectAll,
      showCheckboxColumn: showCheckboxColumn,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      columns: columns,
      rows: rows,
    );
  }
}
