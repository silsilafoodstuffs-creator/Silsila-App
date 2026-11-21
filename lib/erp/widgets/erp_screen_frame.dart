import 'package:flutter/material.dart';
import '../services/erp_screen_layout_profiles.dart';

const _erpFramePurple = Color(0xFF3E007D);
const _erpFrameOrange = Color(0xFFFFA015);


/// Supplies a screen-specific layout profile to nested ERP screen frames.
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
      oldWidget.screen != screen || oldWidget.profile != profile;
}

/// Shared ERP page frame. Saved Studio layout profiles are applied live here.
class ErpScreenFrame extends StatelessWidget {
  const ErpScreenFrame({
    super.key,
    required this.title,
    this.profileKey,
    this.subtitle,
    this.icon = Icons.dashboard_customize_outlined,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabSelected,
    this.actions = const [],
    this.dateFilter,
    this.imagePanel,
    this.sidebar,
    this.showFrameTitle = true,
    this.applyContentWidth = true,
    this.shrinkWrap = false,
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.all(12),
  });

  final String title;
  final String? profileKey;
  final String? subtitle;
  final IconData icon;
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabSelected;
  final List<Widget> actions;
  final Widget? dateFilter;
  final Widget? imagePanel;
  final Widget? sidebar;
  final bool showFrameTitle;
  final bool applyContentWidth;
  final bool shrinkWrap;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ErpScreenLayoutProfiles.profiles,
      builder: (context, profiles, _) {
        final layoutScope = ErpScreenLayoutScope.maybeOf(context);
        final key = layoutScope?.screen ?? profileKey ?? title;
        final raw = layoutScope?.profile ?? (profiles[key] is Map
            ? profiles[key] as Map
            : profiles['*'] is Map ? profiles['*'] as Map : const {});
        final profile = Map<String, dynamic>.from(raw);
        final showTitle = (profile['showTitle'] as bool? ?? true) && showFrameTitle;
        final showTabs = profile['showTabs'] as bool? ?? true;
        final showTasks = profile['showTasks'] as bool? ?? true;
        final showFooter = profile['showFooter'] as bool? ?? true;
        final showDate = profile['showDate'] as bool? ?? true;
        final showImages = profile['showImages'] as bool? ?? true;
        final showSidebar = profile['showSidebar'] as bool? ?? false;
        final datePosition = profile['datePosition'] as String? ?? 'top';
        final imagesPosition = profile['imagesPosition'] as String? ?? 'right';
        final tabsPosition = profile['tabsPosition'] as String? ?? 'below_title';
        final tasksPosition = profile['tasksPosition'] as String? ?? 'below_title';
        final rowHeight = ((profile['rowHeight'] as num?)?.toDouble() ?? 40).clamp(28, 80).toDouble();
        final spacing = ((profile['spacing'] as num?)?.toDouble() ?? 5).clamp(0, 30).toDouble();
        final radius = ((profile['cornerRadius'] as num?)?.toDouble() ?? 12).clamp(0, 30).toDouble();
        final contentWidth = ((profile['contentWidth'] as num?)?.toDouble() ?? 100).clamp(40, 100).toDouble();
        final primary = Color((profile['primary'] as int?) ?? _erpFramePurple.value);
        final accent = Color((profile['accent'] as int?) ?? _erpFrameOrange.value);
        final themePreset = profile['themePreset'] as String? ?? 'glossy_neon_luxury';
        final headerStyle = profile['headerStyle'] as String? ?? 'glossy';
        final buttonStyle = profile['buttonStyle'] as String? ?? 'glossy';
        final tableStyle = profile['tableStyle'] as String? ?? 'glass';
        final treeStyle = profile['treeStyle'] as String? ?? 'neon';
        final isLuxury = themePreset != 'classic';
        final darkHeader = headerStyle == 'glossy' || headerStyle == 'neon';
        final buttonRadius = buttonStyle == 'pill' ? 28.0 : radius;
        final buttonElevation = buttonStyle == 'outline' || buttonStyle == 'glass' ? 0.0 : 5.0;
        final buttonFill = buttonStyle == 'glass' ? primary.withValues(alpha: .10) : primary;
        final buttonForeground = buttonStyle == 'glass' || buttonStyle == 'outline' ? primary : Colors.white;
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
            elevation: isLuxury ? 5 : 1,
            shadowColor: accent.withValues(alpha: isLuxury ? .24 : .10),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius + (isLuxury ? 3 : 0)),
              side: BorderSide(color: accent.withValues(alpha: isLuxury ? .22 : .10)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonElevation, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
              shadowColor: accent.withValues(alpha: .32),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: buttonFill, foregroundColor: buttonForeground,
              elevation: buttonElevation, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primary, side: BorderSide(color: accent.withValues(alpha: .75)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
            ),
          ),
          dataTableTheme: baseTheme.dataTableTheme.copyWith(
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight + 8,
            headingRowHeight: rowHeight,
            columnSpacing: 2,
            headingTextStyle: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
            dataTextStyle: const TextStyle(fontSize: 12),
            dividerThickness: tableStyle == 'minimal' ? .4 : 1,
            decoration: BoxDecoration(
              color: tableStyle == 'glass' ? Colors.white.withValues(alpha: .94) : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: tableStyle == 'neon' ? accent.withValues(alpha: .65) : primary.withValues(alpha: tableStyle == 'minimal' ? .08 : .18)),
              boxShadow: tableStyle == 'neon' ? [BoxShadow(color: accent.withValues(alpha: .14), blurRadius: 16)] : const [],
            ),
          ),
          expansionTileTheme: baseTheme.expansionTileTheme.copyWith(
            tilePadding: EdgeInsets.symmetric(horizontal: treeStyle == 'compact' ? 6 : 12),
            childrenPadding: EdgeInsetsDirectional.only(start: treeStyle == 'nested_cards' ? 18 : 12, end: 8, bottom: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: accent.withValues(alpha: treeStyle == 'neon' ? .55 : .18)),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: primary.withValues(alpha: .12)),
            ),
            iconColor: primary, collapsedIconColor: primary,
          ),
          listTileTheme: baseTheme.listTileTheme.copyWith(
            dense: treeStyle == 'compact',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
            iconColor: primary,
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

        final tabsVisible = showTabs && tabs.isNotEmpty && tabsPosition != 'hidden';
        final tasksVisible = showTasks && actions.isNotEmpty && tasksPosition != 'hidden';

        Widget tabStrip({bool vertical = false}) {
          final children = <Widget>[
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: vertical
                    ? const EdgeInsets.only(bottom: 5)
                    : const EdgeInsetsDirectional.only(start: 5),
                child: Material(
                  color: selectedTab == i ? primary : const Color(0xFFFAF8FC),
                  elevation: selectedTab == i ? 3 : 1,
                  shadowColor: primary.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(radius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(radius),
                    onTap: onTabSelected == null ? null : () => onTabSelected!(i),
                    child: Container(
                      width: vertical ? double.infinity : null,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: selectedTab == i ? accent : const Color(0xFFE9E1F0),
                          width: selectedTab == i ? 1.4 : .8,
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: vertical ? TextAlign.start : TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selectedTab == i ? Colors.white : primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ];
          return vertical
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(mainAxisSize: MainAxisSize.min, children: children),
                );
        }

        Widget tabsPanel({bool vertical = false}) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFECE7F2)),
          ),
          child: tabStrip(vertical: vertical),
        );

        Widget tasksPanel({bool vertical = false}) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFECE7F2)),
            boxShadow: const [
              BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: action,
                      ),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: actions),
                ),
        );

        Widget titleHeader({bool includeTabs = false}) {
          if (!showTitle && !includeTabs) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 10, 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: BorderRadius.circular(radius + (darkHeader ? 3 : 0)),
              border: Border.all(color: darkHeader ? accent.withValues(alpha: .72) : primary.withValues(alpha: .18), width: darkHeader ? 1.2 : .8),
              boxShadow: [
                BoxShadow(color: primary.withValues(alpha: darkHeader ? .26 : .10), blurRadius: darkHeader ? 20 : 10, offset: const Offset(0, 4)),
                if (darkHeader) BoxShadow(color: accent.withValues(alpha: .16), blurRadius: 18, spreadRadius: -4),
              ],
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final heading = Row(children: [
                if (showTitle) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: darkHeader ? accent.withValues(alpha: .20) : primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Icon(icon, color: darkHeader ? Colors.white : primary, size: 23),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: headerForeground, shadows: darkHeader ? [Shadow(color: accent.withValues(alpha: .45), blurRadius: 10)] : const [])),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: darkHeader ? const Color(0xFFE9DDF5) : Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ]);
              if (!includeTabs) return heading;
              if (!showTitle) return tabStrip();
              if (constraints.maxWidth >= 820) {
                return Row(children: [
                  Flexible(flex: 4, child: heading),
                  const SizedBox(width: 12),
                  Flexible(flex: 6, child: Align(alignment: Alignment.centerLeft, child: tabStrip())),
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [heading, const SizedBox(height: 10), tabStrip()],
              );
            }),
          );
        }

        Widget slotPanel(Widget? slot) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFECE7F2)),
          ),
          child: slot ?? const SizedBox.shrink(),
        );

        final dateVisible = showDate && dateFilter != null && datePosition != 'hidden';
        final imageVisible = showImages && imagePanel != null && imagesPosition != 'hidden';

        Widget sideRail({required bool left}) {
          final side = left ? 'left' : 'right';
          final tabSide = tabsVisible && tabsPosition == side;
          final taskSide = tasksVisible && tasksPosition == side;
          final dateSide = dateVisible && datePosition == side;
          final imageSide = imageVisible && imagesPosition == side;
          final sidebarSide = showSidebar && sidebar != null && left;
          if (!tabSide && !taskSide && !dateSide && !imageSide && !sidebarSide) {
            return const SizedBox.shrink();
          }
          return SizedBox(
            width: MediaQuery.of(context).size.width < 600 ? 112 : 150,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sidebarSide) slotPanel(sidebar),
                  if (tabSide) tabsPanel(vertical: true),
                  if (taskSide) tasksPanel(vertical: true),
                  if (dateSide) slotPanel(dateFilter),
                  if (imageSide) slotPanel(imagePanel),
                ],
              ),
            ),
          );
        }

        final headerTabs = tabsVisible && tabsPosition == 'below_title';
        final contentRow = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: shrinkWrap ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
          children: [
            sideRail(left: false),
            Expanded(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: applyContentWidth ? contentWidth / 100 : 1,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
            sideRail(left: true),
          ],
        );
        final Widget content = shrinkWrap ? contentRow : Expanded(child: contentRow);

        return Theme(
          data: themed,
          child: Directionality(
            textDirection: Directionality.of(context),
            child: Column(
              mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tabsVisible && tabsPosition == 'top') tabsPanel(),
                if (tasksVisible && tasksPosition == 'top') tasksPanel(),
                if (dateVisible && datePosition == 'top') slotPanel(dateFilter),
                if (imageVisible && imagesPosition == 'top') slotPanel(imagePanel),
                if (showTitle || headerTabs) titleHeader(includeTabs: headerTabs),
                if (dateVisible && datePosition == 'below_title') slotPanel(dateFilter),
                if (imageVisible && imagesPosition == 'below_title') slotPanel(imagePanel),
                if (tasksVisible && tasksPosition == 'below_title') tasksPanel(),
                if (tabsVisible && tabsPosition == 'above_content') tabsPanel(),
                if (tasksVisible && tasksPosition == 'above_content') tasksPanel(),
                if (dateVisible && datePosition == 'above_content') slotPanel(dateFilter),
                if (imageVisible && imagesPosition == 'above_content') slotPanel(imagePanel),
                content,
                if (dateVisible && datePosition == 'bottom') slotPanel(dateFilter),
                if (imageVisible && imagesPosition == 'bottom') slotPanel(imagePanel),
                if (tabsVisible && tabsPosition == 'bottom') tabsPanel(),
                if (tasksVisible && tasksPosition == 'bottom') tasksPanel(),
                if (showFooter && footer != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: const Color(0xFFECE7F2)),
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
