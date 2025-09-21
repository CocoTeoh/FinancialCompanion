// lib/main_shell.dart
import 'package:flutter/material.dart';

// Your pages:
import 'course_page.dart';
import 'finance_page.dart';
import 'home_page.dart';
import 'pet_page.dart';
import 'profile_page.dart';

/// Persistent shell that owns the bottom nav bar.
/// Tabs: 0=Course, 1=Finance, 2=Home, 3=Pet, 4=Profile
class MainShell extends StatefulWidget {
  final int initialIndex; // default start on Home (2)
  const MainShell({super.key, this.initialIndex = 2});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _current; // selected tab index

  // Keep pages alive when switching tabs
  // (replace with your real pages if these are placeholders)
  late final List<Widget> _pages = const [
    CoursePage(),
    FinancePage(),
    HomePage(),
    PetPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex; // start on the tab you pass in
  }

  Widget _navItem({
    required String icon,
    required String iconFilled,
    required int index,
    double size = 28,
  }) {
    final selected = _current == index;
    return GestureDetector(
      onTap: () => setState(() => _current = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Image.asset(
          selected ? iconFilled : icon,
          height: size,
          width: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EBB87),

      // Page body swaps while keeping state
      body: SafeArea(
        child: IndexedStack(
          index: _current,
          children: _pages,
        ),
      ),

      // Bottom menu bar with your asset icons
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF5E8A76),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(
              icon: 'assets/course.png',
              iconFilled: 'assets/course_filled.png',
              index: 0,
            ),
            _navItem(
              icon: 'assets/dollar.png',
              iconFilled: 'assets/dollar_filled.png',
              index: 1,
            ),
            _navItem(
              icon: 'assets/home.png',
              iconFilled: 'assets/home_filled.png',
              index: 2,
            ),
            _navItem(
              icon: 'assets/paw.png',
              iconFilled: 'assets/paw_filled.png',
              index: 3,
            ),
            _navItem(
              icon: 'assets/user.png',
              iconFilled: 'assets/user_filled.png',
              index: 4,
            ),
          ],
        ),
      ),
    );
  }
}
