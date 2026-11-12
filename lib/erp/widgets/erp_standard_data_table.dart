import 'package:flutter/material.dart';

/// Shared ERP table metrics and header treatment.
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
    this.horizontalMargin = 8,
    this.columnSpacing = 16,
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
      showCheckboxColumn: showCheckboxColumn,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      columns: columns,
      rows: rows,
    );
  }
}
