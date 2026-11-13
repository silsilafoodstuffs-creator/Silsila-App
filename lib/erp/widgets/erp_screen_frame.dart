import 'package:flutter/material.dart';
import '../services/erp_screen_layout_profiles.dart';

const _erpFramePurple = Color(0xFF3E007D);
const _erpFrameOrange = Color(0xFFFFA015);

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
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ErpScreenLayoutProfiles.profiles,
      builder: (context, profiles, _) {
        final key = profileKey ?? title;
        final raw = profiles[key] is Map
            ? profiles[key] as Map
            : profiles['*'] is Map ? profiles['*'] as Map : const {};
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
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          colorScheme: baseTheme.colorScheme.copyWith(primary: primary, secondary: accent),
          dataTableTheme: baseTheme.dataTableTheme.copyWith(
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight + 8,
            columnSpacing: spacing <= 2 ? 6 : spacing * 2.8,
          ),
          inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
            constraints: BoxConstraints(minHeight: rowHeight, maxHeight: rowHeight + 4),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: const Color(0xFFECE7F2)),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final heading = Row(children: [
                if (showTitle) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Icon(icon, color: primary, size: 23),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: primary)),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
        final content = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
        );

        return Theme(
          data: themed,
          child: Directionality(
            textDirection: Directionality.of(context),
            child: Column(
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
