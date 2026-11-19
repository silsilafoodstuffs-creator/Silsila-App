import 'package:flutter/material.dart';
import '../services/erp_screen_layout_profiles.dart';

const _erpFramePurple = Color(0xFF3E007D);
const _erpFrameOrange = Color(0xFFFFA015);
const _erpFramePink = Color(0xFFFF27C3);

class ErpScreenLayoutScope extends InheritedWidget {
  const ErpScreenLayoutScope({
    super.key,
    required this.screen,
    required this.profile,
    required super.child,
  });

  final String screen;
  final Map<String, dynamic> profile;

  static ErpScreenLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ErpScreenLayoutScope>();

  @override
  bool updateShouldNotify(ErpScreenLayoutScope oldWidget) =>
      screen != oldWidget.screen || profile != oldWidget.profile;
}

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
        final scoped = ErpScreenLayoutScope.maybeOf(context);
        final raw = scoped?.profile ?? (profiles[title] is Map
            ? profiles[title] as Map
            : profiles['*'] is Map ? profiles['*'] as Map : const {});
        final profile = Map<String, dynamic>.from(raw);
        final showTitle = profile['showTitle'] as bool? ?? true;
        final showTabs = profile['showTabs'] as bool? ?? true;
        final showTasks = profile['showTasks'] as bool? ?? true;
        final showFooter = profile['showFooter'] as bool? ?? true;
        final tabsPosition = profile['tabsPosition'] as String? ?? 'below_title';
        final tasksPosition = profile['tasksPosition'] as String? ?? 'below_title';
        final rowHeight = ((profile['rowHeight'] as num?)?.toDouble() ?? 40).clamp(28, 80).toDouble();
        final spacing = ((profile['spacing'] as num?)?.toDouble() ?? 5).clamp(0, 30).toDouble();
        final radius = ((profile['cornerRadius'] as num?)?.toDouble() ?? 12).clamp(0, 30).toDouble();
        final contentWidth = ((profile['contentWidth'] as num?)?.toDouble() ?? 100).clamp(40, 100).toDouble();
        final themePreset = profile['themePreset'] as String? ?? 'glossy_neon_luxury';
        final headerStyle = profile['headerStyle'] as String? ?? 'glossy';
        final buttonStyle = profile['buttonStyle'] as String? ?? 'glossy';
        final tableStyle = profile['tableStyle'] as String? ?? 'glass';
        final treeStyle = profile['treeStyle'] as String? ?? 'neon';
        final primary = Color((profile['primary'] as int?) ?? _erpFramePurple.toARGB32());
        final accent = Color((profile['accent'] as int?) ?? _erpFramePink.toARGB32());
        final buttonRadius = buttonStyle == 'pill' ? 28.0 : radius;
        final buttonFill = buttonStyle == 'glass' ? primary.withValues(alpha: .10) : buttonStyle == 'outline' ? Colors.transparent : primary;
        final buttonForeground = buttonStyle == 'glass' || buttonStyle == 'outline' ? primary : Colors.white;
        final darkHeader = headerStyle == 'glossy' || headerStyle == 'neon';
        final headerGradient = switch (headerStyle) {
          'glass' => const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF2E9FC), Color(0xFFFFF5FA)]),
          'neon' => const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF16002D), Color(0xFF3E007D), Color(0xFF8B1CB8)]),
          'minimal' => const LinearGradient(colors: [Colors.white, Colors.white]),
          _ => const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF26004F), Color(0xFF3E007D), Color(0xFF6120A0)]),
        };
        final headerForeground = darkHeader ? Colors.white : primary;
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(primary: primary, secondary: accent),
          cardTheme: CardThemeData(
            color: themePreset == 'platinum' ? const Color(0xFFF8F9FC) : Colors.white,
            elevation: themePreset == 'classic' ? 1 : 5,
            shadowColor: accent.withValues(alpha: .22),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius + (themePreset == 'classic' ? 0 : 3)),
              side: BorderSide(color: accent.withValues(alpha: .20)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonStyle == 'outline' || buttonStyle == 'glass' ? 0 : buttonStyle == 'neon' ? 9 : 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              side: buttonStyle == 'neon' ? BorderSide(color: accent.withValues(alpha: .9), width: 1.2) : BorderSide.none,
              shadowColor: accent.withValues(alpha: buttonStyle == 'neon' ? .55 : .30),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonStyle == 'outline' || buttonStyle == 'glass' ? 0 : buttonStyle == 'neon' ? 8 : 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              side: buttonStyle == 'neon' ? BorderSide(color: accent.withValues(alpha: .9), width: 1.2) : BorderSide.none,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary, side: BorderSide(color: accent.withValues(alpha: .75)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius))),
          ),
          dataTableTheme: baseTheme.dataTableTheme.copyWith(
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight,
            headingRowHeight: rowHeight,
            columnSpacing: spacing,
            headingTextStyle: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
            dividerThickness: tableStyle == 'minimal' ? .4 : tableStyle == 'outlined' ? 1.6 : 1,
            decoration: BoxDecoration(
              color: tableStyle == 'glass' ? Colors.white.withValues(alpha: .94) : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: tableStyle == 'neon' ? accent.withValues(alpha: .75) : primary.withValues(alpha: tableStyle == 'outlined' ? .55 : .16), width: tableStyle == 'outlined' ? 1.5 : 1),
              boxShadow: tableStyle == 'neon' ? [BoxShadow(color: accent.withValues(alpha: .14), blurRadius: 14)] : const [],
            ),
          ),
          expansionTileTheme: baseTheme.expansionTileTheme.copyWith(
            tilePadding: EdgeInsets.symmetric(horizontal: treeStyle == 'compact' ? 6 : 12),
            childrenPadding: EdgeInsetsDirectional.only(start: treeStyle == 'nested_cards' ? 18 : 12, end: 8, bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: accent.withValues(alpha: .45))),
            iconColor: primary, collapsedIconColor: primary,
          ),
          listTileTheme: baseTheme.listTileTheme.copyWith(
            dense: treeStyle == 'compact',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: themePreset == 'classic' ? Colors.white : const Color(0xFFFCF9FF),
            constraints: BoxConstraints(minHeight: rowHeight, maxHeight: rowHeight + 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: primary.withValues(alpha: .22))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: primary.withValues(alpha: .22))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide(color: accent, width: 1.5)),
          ),
        );

        final taskBar = Container(
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
        );

        return Theme(
          data: themed,
          child: Directionality(
            textDirection: Directionality.of(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTasks && actions.isNotEmpty && tasksPosition == 'top') taskBar,
                if (showTitle || (showTabs && tabs.isNotEmpty && tabsPosition != 'hidden'))
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius + 3),
                      border: Border.all(color: darkHeader ? accent.withValues(alpha: .72) : primary.withValues(alpha: .18), width: darkHeader ? 1.2 : .8),
                      gradient: headerGradient,
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
                      final effectiveShowTabs = showTabs && tabsPosition != 'hidden';
                      final tabStrip = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (effectiveShowTabs)
                            for (var i = 0; i < tabs.length; i++)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 5),
                                child: Material(
                                  color: selectedTab == i ? primary : const Color(0xFFF9F3FF),
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
                                        border: Border.all(color: selectedTab == i ? accent : const Color(0xFFE9E1F0), width: selectedTab == i ? 1.4 : .8),
                                        gradient: selectedTab == i ? LinearGradient(colors: [primary, accent.withValues(alpha: .82)]) : null,
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
                      if (!showTitle) return effectiveShowTabs ? tabStrip : const SizedBox.shrink();
                      if (!effectiveShowTabs || tabs.isEmpty) return heading;
                      if (tabsPosition == 'top') {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          tabStrip,
                          const SizedBox(height: 8),
                          heading,
                        ]);
                      }
                      if (constraints.maxWidth >= 820 && tabsPosition != 'bottom' && tabsPosition != 'above_content') {
                        final tabsWidget = Flexible(flex: 6, child: Align(alignment: Alignment.centerLeft, child: tabStrip));
                        final titleWidget = Flexible(flex: 4, child: heading);
                        return Row(
                          textDirection: TextDirection.ltr,
                          children: tabsPosition == 'left'
                              ? [tabsWidget, const SizedBox(width: 12), titleWidget]
                              : [titleWidget, const SizedBox(width: 12), tabsWidget],
                        );
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        heading,
                        const SizedBox(height: 10),
                        tabStrip,
                      ]);
                    }),
                  ),
                if (showTasks && actions.isNotEmpty && tasksPosition != 'top' && tasksPosition != 'bottom' && tasksPosition != 'hidden') taskBar,
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: contentWidth / 100,
                      child: Padding(padding: padding, child: child),
                    ),
                  ),
                ),
                if (showTasks && actions.isNotEmpty && tasksPosition == 'bottom') taskBar,
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
