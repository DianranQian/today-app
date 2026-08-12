import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import 'go_data_store.dart';
import 'go_home_page.dart';
import 'go_manage_page.dart';
import 'go_nearby_page.dart';
import 'go_settings_page.dart';

/// 「今天去哪」子应用：首页 / 附近 / 管理 / 设置 四个 Tab
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
      // 条件切换：切 Tab 时重建页面，保证设置/导入后数据即时刷新
      body: switch (_currentIndex) {
        0 => const GoHomePage(),
        1 => const GoNearbyPage(),
        2 => const GoManagePage(),
        _ => const GoSettingsPage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: t('首页', 'Home')),
          NavigationDestination(
              icon: Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me),
              label: t('附近', 'Nearby')),
          NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: t('管理', 'Manage')),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: t('设置', 'Settings')),
        ],
      ),
      ),
    );
  }
}
