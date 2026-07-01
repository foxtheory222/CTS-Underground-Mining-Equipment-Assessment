import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/workspace_providers.dart';

/// Responsive tablet shell.
///
/// Layout adapts to the available width:
/// * `< 760dp`  (portrait tablets / phones) -> branded top bar + bottom
///   [NavigationBar], content uses the full width.
/// * `>= 760dp` (landscape tablets)         -> branded top bar + left
///   [NavigationRail]. The rail is icon-only until `>= 960dp`, where it
///   extends to show labels and workspace hints.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  static const double compactBreakpoint = 760;
  static const double extendedRailBreakpoint = 960;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: 'Dashboard',
      shortLabel: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
      label: 'Inspections',
      shortLabel: 'Records',
    ),
    _NavItem(
      icon: Icons.note_add_outlined,
      selectedIcon: Icons.note_add,
      label: 'New Inspection',
      shortLabel: 'New',
    ),
    _NavItem(
      icon: Icons.assignment_turned_in_outlined,
      selectedIcon: Icons.assignment_turned_in,
      label: 'Action Items',
      shortLabel: 'Actions',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
      shortLabel: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(workspaceProvider);
    final totalRecords = controller.inspections.length;
    final criticalRecords = controller.inspections
        .where((inspection) => inspection.criticalCount > 0)
        .length;

    final scheme = Theme.of(context).colorScheme;
    final safeIndex = selectedIndex.clamp(0, _items.length - 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use layout constraints (not MediaQuery) for breakpoints so the
            // shell reacts to the real available width and stays testable.
            final width = constraints.maxWidth;
            final compact = width < compactBreakpoint;
            final extendedRail = width >= extendedRailBreakpoint;

            final content = Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1480),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 6,
                    compact ? 14 : 18,
                    compact ? 16 : 22,
                    compact ? 10 : 22,
                  ),
                  child: child,
                ),
              ),
            );

            return Column(
              children: [
                _BrandTopBar(width: width, totalRecords: totalRecords),
                Expanded(
                  child: compact
                      ? content
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SidebarRail(
                              extended: extendedRail,
                              selectedIndex: safeIndex,
                              onDestinationSelected: onDestinationSelected,
                              totalRecords: totalRecords,
                              criticalRecords: criticalRecords,
                              items: _items,
                            ),
                            Expanded(child: content),
                          ],
                        ),
                ),
                if (compact)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: safeIndex,
                      onDestinationSelected: onDestinationSelected,
                      destinations: [
                        for (final item in _items)
                          NavigationDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: item.shortLabel,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shortLabel,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String shortLabel;
}

class _BrandTopBar extends StatelessWidget {
  const _BrandTopBar({required this.width, required this.totalRecords});

  final double width;
  final int totalRecords;

  @override
  Widget build(BuildContext context) {
    final compact = width < AppShell.compactBreakpoint;
    final showSubtitle = width >= 620;
    final showChips = width >= 900;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [CtsPalette.navy, CtsPalette.navyAlt, Color(0xFF122A47)],
        ),
        border: Border(bottom: BorderSide(color: CtsPalette.orange, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 22,
        12,
        compact ? 14 : 22,
        12,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/logo/cts_logo.png',
              height: compact ? 30 : 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CTS Underground Mining Equipment Assessment',
                  maxLines: showSubtitle ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 17,
                    height: 1.15,
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Offline field inspection workflow',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showChips) ...[
            const SizedBox(width: 16),
            const _HeaderChip(
              icon: Icons.cloud_off_rounded,
              label: 'Offline ready',
              color: CtsPalette.success,
            ),
            const SizedBox(width: 10),
            _HeaderChip(
              icon: Icons.folder_open_rounded,
              label: '$totalRecords records',
              color: CtsPalette.orangeSoft,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.totalRecords,
    required this.criticalRecords,
    required this.items,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int totalRecords;
  final int criticalRecords;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: extended ? 244 : 96,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 20 : 8,
              18,
              extended ? 20 : 8,
              12,
            ),
            child: extended
                ? Row(
                    children: [
                      const _BrandDot(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Inspection Suite',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  )
                : const Center(child: _BrandDot()),
          ),
          Expanded(
            child: NavigationRail(
              extended: extended,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              minWidth: 96,
              minExtendedWidth: 244,
              backgroundColor: Colors.transparent,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(extended ? item.label : item.shortLabel),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 16 : 8,
              8,
              extended ? 16 : 8,
              16,
            ),
            child: extended
                ? Column(
                    children: [
                      _RailHint(
                        icon: Icons.today_outlined,
                        title: 'Active records',
                        value: totalRecords.toString(),
                      ),
                      const SizedBox(height: 10),
                      _RailHint(
                        icon: Icons.warning_amber_rounded,
                        title: 'Critical',
                        value: criticalRecords.toString(),
                        tint: CtsPalette.danger,
                      ),
                    ],
                  )
                : _RailBadge(
                    value: criticalRecords,
                    tint: criticalRecords > 0
                        ? CtsPalette.danger
                        : CtsPalette.slate,
                  ),
          ),
        ],
      ),
    );
  }
}

class _BrandDot extends StatelessWidget {
  const _BrandDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: CtsPalette.orange,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RailHint extends StatelessWidget {
  const _RailHint({
    required this.icon,
    required this.title,
    required this.value,
    this.tint = CtsPalette.orange,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailBadge extends StatelessWidget {
  const _RailBadge({required this.value, required this.tint});

  final int value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$value critical',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: tint),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
