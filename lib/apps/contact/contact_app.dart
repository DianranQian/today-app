import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import 'contact_data_store.dart';
import 'contact_home_page.dart';
import 'contact_manage_page.dart';
import 'contact_settings_page.dart';

/// 「今天联系谁」子应用：首页 + 管理 两个 Tab
class ContactAppPage extends StatefulWidget {
  const ContactAppPage({super.key});

  @override
  State<ContactAppPage> createState() => _ContactAppPageState();
}

class _ContactAppPageState extends State<ContactAppPage> {
  int _currentIndex = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ContactDataStore.load().then((_) {
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
      data: buildAppTheme(seed: AppSettings.seedFor(AppId.contact)),
      child: Scaffold(
      // 条件切换：切 Tab 时重建页面，保证设置/导入后数据即时刷新
      body: switch (_currentIndex) {
        0 => const ContactHomePage(),
        1 => const ContactManagePage(),
        _ => const ContactSettingsPage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.contacts_outlined),
              selectedIcon: Icon(Icons.contacts),
              label: '管理'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
      ),
    );
  }
}
