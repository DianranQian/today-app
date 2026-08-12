import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/language.dart';
import '../../core/scheme_store.dart';
import '../../core/theme.dart';
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
    SchemeStore.notifier.addListener(_onSchemeChanged);
    DataStore.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value != 'eat') return;
    DataStore.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onSchemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Theme(
      data: buildAppTheme(seed: AppSettings.seedFor(AppId.eat)),
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: t('首页')),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: t('菜单')),
          NavigationDestination(
              icon: Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me),
              label: t('附近')),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: t('设置')),
        ],
      ),
      ),
    );
  }
}
