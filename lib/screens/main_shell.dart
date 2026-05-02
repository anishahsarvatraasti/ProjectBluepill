import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'habits_page.dart';
import 'journal_page.dart';
import 'mentor_page.dart';
import 'mission_page.dart';
import 'settings_page.dart';
import 'todo_page.dart';
import '../ui/project_logo.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, DashboardPage()),
    _NavItem('Todo', Icons.check_circle_outline, TodoPage()),
    _NavItem('Calendar', Icons.calendar_month_outlined, CalendarPage()),
    _NavItem('Mission', Icons.flag_outlined, MissionPage()),
    _NavItem('Habits', Icons.repeat, HabitsPage()),
    _NavItem('Agent', Icons.support_agent_outlined, MentorPage()),
    _NavItem('Journal', Icons.edit_note_outlined, JournalPage()),
    _NavItem('Settings', Icons.settings_outlined, SettingsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                TooltipVisibility(
                  visible: false,
                  child: NavigationRail(
                    selectedIndex: _index,
                    useIndicator: true,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: ProjectLogo(size: 44),
                    ),
                    destinations: [
                      for (final item in _items)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.icon),
                          label: Text(item.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _AnimatedPage(
                    index: _index,
                    child: _items[_index].page,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: _AnimatedPage(index: _index, child: _items[_index].page),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              for (final item in _items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.icon),
                  label: item.label,
                  tooltip: '',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPage extends StatelessWidget {
  const _AnimatedPage({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Easing.emphasizedDecelerate,
      switchOutCurve: Easing.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offset,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(index),
        child: child,
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final Widget page;
}
