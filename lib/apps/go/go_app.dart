import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import 'go_data_store.dart';
import 'go_home_page.dart';
import 'go_manage_page.dart';
import 'go_nearby_page.dart';

/// 「今天去哪」子应用：首页 + 管理 两个 Tab
class GoAppPage extends StatefulWidget {
  const GoAppPage({super.key});

  @override
  State<GoAppPage> createState() => _GoAppPageState();
}

class _GoAppPageState extends State<GoAppPage> {
  int _currentIndex = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    GoDataStore.load().then((_) {
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
    return Theme(
      data: buildAppTheme(seed: AppSettings.seedFor(AppId.go)),
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          GoHomePage(),
          GoNearbyPage(),
          GoManagePage(),
        ],
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
              icon: Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me),
              label: '附近'),
          NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: '管理'),
        ],
      ),
      ),
    );
  }
}
