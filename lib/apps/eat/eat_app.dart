import 'package:flutter/material.dart';
import 'data/data_store.dart';
import 'pages/home_page.dart';
import 'pages/manage_page.dart';
import 'pages/nearby_page.dart';
import 'pages/settings_page.dart';

/// 「今天吃什么」子应用：首页 / 菜单 / 附近 / 设置 四个 Tab
class EatAppPage extends StatefulWidget {
  const EatAppPage({super.key});

  @override
  State<EatAppPage> createState() => _EatAppPageState();
}

class _EatAppPageState extends State<EatAppPage> {
  int _currentIndex = 0;
  bool _ready = false;

  final _pages = const [
    HomePage(),
    ManagePage(),
    NearbyPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    DataStore.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: '菜单'),
          NavigationDestination(
              icon: Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me),
              label: '附近'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
    );
  }
}
