import 'package:flutter/material.dart';
import '../services/erp_screen_layout_profiles.dart';

const _erpFramePurple = Color(0xFF3E007D);
const _erpFrameOrange = Color(0xFFFFA015);
const _erpFramePink = Color(0xFFFF27C3);

/// Shared ERP page frame. Saved Studio layout profiles are applied live here.
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
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ErpScreenLayoutProfiles.profiles,
      builder: (context, profiles, _) {
        final raw = profiles[title] is Map
            ? profiles[title] as Map
            : profiles['*'] is Map ? profiles['*'] as Map : const {};
        final profile = Map<String, dynamic>.from(raw);
        final showTitle = profile['showTitle'] as bool? ?? true;
        final showTabs = profile['showTabs'] as bool? ?? true;
        final showTasks = profile['showTasks'] as bool? ?? true;
        final showFooter = profile['showFooter'] as bool? ?? true;
        final rowHeight = ((profile['rowHeight'] as num?)?.toDouble() ?? 40).clamp(28, 80).toDouble();
        final spacing = ((profile['spacing'] as num?)?.toDouble() ?? 5).clamp(0, 30).toDouble();
        final radius = ((profile['cornerRadius'] as num?)?.toDouble() ?? 12).clamp(0, 30).toDouble();
        final contentWidth = ((profile['contentWidth'] as num?)?.toDouble() ?? 100).clamp(40, 100).toDouble();
        final primary = Color((profile['primary'] as int?) ?? _erpFramePurple.toARGB32());
        final accent = Color((profile['accent'] as int?) ?? _erpFrameOrange.toARGB32());
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(primary: primary, secondary: accent),
          dataTableTheme: baseTheme.dataTableTheme.copyWith(
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight,
            columnSpacing: spacing,
          ),
          inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
            constraints: BoxConstraints(minHeight: rowHeight, maxHeight: rowHeight),
          ),
        );

        return Theme(
          data: themed,
          child: Directionality(
            textDirection: Directionality.of(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTitle || (showTabs && tabs.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius + 3),
                      border: Border.all(color: _erpFramePink.withValues(alpha: .72), width: 1),
                      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF26004F), Color(0xFF3E007D), Color(0xFF6120A0)]),
                      boxShadow: [BoxShadow(color: _erpFramePurple.withValues(alpha: .24), blurRadius: 18, offset: const Offset(0, 6)), BoxShadow(color: _erpFramePink.withValues(alpha: .20), blurRadius: 22, spreadRadius: -4), BoxShadow(color: _erpFrameOrange.withValues(alpha: .10), blurRadius: 12, spreadRadius: -4)],
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final heading = Row(children: [
                        if (showTitle) ...[
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_erpFrameOrange, _erpFramePink]), borderRadius: BorderRadius.circular(radius), boxShadow: [BoxShadow(color: _erpFramePink.withValues(alpha: .35), blurRadius: 12)]),
                            child: Icon(icon, color: Colors.white, size: 23),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Color(0x66FF27C3), blurRadius: 10)])),
                              if (subtitle != null && subtitle!.isNotEmpty)
                                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFE9DDF5))),
                            ],
                          )),
                        ],
                      ]);
                      final tabStrip = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (showTabs)
                            for (var i = 0; i < tabs.length; i++)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 5),
                                child: Material(
                                  color: selectedTab == i ? _erpFramePurple : const Color(0xFFF9F3FF),
                                  elevation: selectedTab == i ? 5 : 1,
                                  shadowColor: primary.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(radius),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(radius),
                                    onTap: onTabSelected == null ? null : () => onTabSelected!(i),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(radius),
                                        border: Border.all(color: selectedTab == i ? _erpFramePink : const Color(0xFFE9E1F0), width: selectedTab == i ? 1.4 : .8),
                                        gradient: selectedTab == i ? const LinearGradient(colors: [Color(0xFF3E007D), Color(0xFF6A20A4)]) : null,
                                      ),
                                      child: Text(tabs[i], maxLines: 1,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                          color: selectedTab == i ? Colors.white : primary)),
                                    ),
                                  ),
                                ),
                              ),
                        ]),
                      );
                      if (!showTitle) return tabStrip;
                      if (!showTabs || tabs.isEmpty) return heading;
                      if (constraints.maxWidth >= 820) {
                        return Row(children: [
                          Flexible(flex: 4, child: heading),
                          const SizedBox(width: 12),
                          Flexible(flex: 6, child: Align(alignment: Alignment.centerLeft, child: tabStrip)),
                        ]);
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        heading,
                        const SizedBox(height: 10),
                        tabStrip,
                      ]);
                    }),
                  ),
                if (showTasks && actions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius + 2),
                      border: Border.all(color: const Color(0xFFFFC9F3), width: 1),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFFFF7FD), Color(0xFFF5EDFF)]),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF3E007D).withValues(alpha: .10), blurRadius: 10, offset: const Offset(0, 3)),
                        BoxShadow(color: const Color(0xFFFF27C3).withValues(alpha: .12), blurRadius: 14, spreadRadius: -4),
                      ],
                    ),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: actions)),
                  ),
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: contentWidth / 100,
                      child: Padding(padding: padding, child: child),
                    ),
                  ),
                ),
                if (showFooter && footer != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: const Color(0xFFEADCF5), width: 0.8),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF3E007D).withValues(alpha: .05), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700),
                      child: footer!,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
