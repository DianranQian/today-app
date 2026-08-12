import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/language.dart';
import '../../core/scheme_store.dart';
import '../../core/theme.dart';
import 'wear_data_store.dart';
import 'wear_home_page.dart';
import 'wear_manage_page.dart';
import 'wear_settings_page.dart';

/// 「今天穿什么」子应用：首页 / 管理 / 设置 三个 Tab
class WearAppPage extends StatefulWidget {
  const WearAppPage({super.key});

  @override
  State<WearAppPage> createState() => _WearAppPageState();
}

class _WearAppPageState extends State<WearAppPage> {
  int _currentIndex = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onSchemeChanged);
    WearDataStore.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value != 'wear') return;
    WearDataStore.load().then((_) {
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
      data: buildAppTheme(seed: AppSettings.seedFor(AppId.wear)),
      child: Scaffold(
      // 条件切换：切 Tab 时重建页面，保证设置/导入后数据即时刷新
      body: switch (_currentIndex) {
        0 => const WearHomePage(),
        1 => const WearManagePage(),
        _ => const WearSettingsPage(),
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
              icon: Icon(Icons.checkroom_outlined),
              selectedIcon: Icon(Icons.checkroom),
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
