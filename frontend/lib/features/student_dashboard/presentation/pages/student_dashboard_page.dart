import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import 'account_page.dart';
import 'belajar_bareng_page.dart';
import 'potensi_page.dart';
import 'student_home_page.dart';

/// Kerangka utama siswa: menu bawah di HP, menu samping di layar lebar.
/// Tab: Beranda (pilih subtes) · Belajar Bareng · Potensi · Akun.
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Breakpoints.compact;

    final pages = IndexedStack(
      index: _index,
      children: [
        StudentHomePage(onOpenBelajarBareng: () => _goTo(1)),
        const BelajarBarengPage(),
        PotensiPage(active: _index == 2),
        const AccountPage(),
      ],
    );

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _goTo,
                extended: width >= Breakpoints.expanded,
                labelType: width >= Breakpoints.expanded
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: Text('Beranda'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Belajar Bareng'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: Text('Potensi'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Akun'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Bareng',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Potensi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
