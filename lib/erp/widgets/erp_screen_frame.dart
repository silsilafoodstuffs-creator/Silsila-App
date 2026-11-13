import 'package:flutter/material.dart';
import 'erp_quick_task_button.dart';

const _erpFramePurple = Color(0xFF3E007D);
const _erpFrameOrange = Color(0xFFFFA015);

/// Shared ERP page frame: title, elevated sibling tabs, quick actions,
/// bounded content area and a compact information footer.
class ErpScreenFrame extends StatelessWidget {
  const ErpScreenFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dashboard_customize_outlined,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabSelected,
    this.actions = const [],
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.all(12),
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabSelected;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECE7F2)),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final heading = Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFF1E9FA), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: _erpFramePurple, size: 23),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _erpFramePurple)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                )),
              ]);
              if (tabs.isEmpty) return heading;
              final tabStrip = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 5),
                      child: Material(
                        color: selectedTab == i ? _erpFramePurple : const Color(0xFFFAF8FC),
                        elevation: selectedTab == i ? 3 : 1,
                        shadowColor: _erpFramePurple.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(11),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(11),
                          onTap: onTabSelected == null ? null : () => onTabSelected!(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: selectedTab == i ? _erpFrameOrange : const Color(0xFFE9E1F0), width: selectedTab == i ? 1.4 : .8),
                            ),
                            child: Text(tabs[i], maxLines: 1,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                color: selectedTab == i ? Colors.white : _erpFramePurple)),
                          ),
                        ),
                      ),
                    ),
                ]),
              );
              if (constraints.maxWidth >= 820) {
                return Row(children: [Flexible(flex: 4, child: heading), const SizedBox(width: 12), Flexible(flex: 6, child: Align(alignment: Alignment.centerLeft, child: tabStrip))]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, if (tabs.isNotEmpty) const SizedBox(height: 10), tabStrip]);
            }),
          ),
          if (actions.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECE7F2)),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))]),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: actions)),
            ),
          Expanded(child: Padding(padding: padding, child: child)),
          if (footer != null)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFECE7F2))),
              child: DefaultTextStyle(style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700), child: footer!),
            ),
        ],
      ),
    );
  }
}
