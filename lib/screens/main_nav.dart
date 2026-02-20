import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'portfolio_screen.dart';
import 'settings_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MarketScreen(),
    const PortfolioScreen(),
    const Scaffold(body: Center(child: Text('Learn'))),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111520),
        selectedItemColor: const Color(0xFF00E5A0),
        unselectedItemColor: const Color(0xFF5A6280),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Market',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Portfolio'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Learn'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
