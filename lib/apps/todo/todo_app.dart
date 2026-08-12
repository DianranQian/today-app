import 'package:flutter/material.dart';
import '../../core/app_settings.dart';
import '../../core/language.dart';
import '../../core/scheme_store.dart';
import '../../core/theme.dart';
import 'todo_data_store.dart';
import 'todo_home_page.dart';
import 'todo_settings_page.dart';

/// 「今天待办」子应用：首页 / 设置 两个 Tab
class TodoAppPage extends StatefulWidget {
  const TodoAppPage({super.key});

  @override
  State<TodoAppPage> createState() => _TodoAppPageState();
}

class _TodoAppPageState extends State<TodoAppPage> {
  int _currentIndex = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onSchemeChanged);
    TodoDataStore.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value != 'todo') return;
    TodoDataStore.load().then((_) {
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
      data: buildAppTheme(seed: AppSettings.seedFor(AppId.todo)),
      child: Scaffold(
      // 条件切换：切 Tab 时重建页面，保证设置/导入后数据即时刷新
      body: switch (_currentIndex) {
        0 => const TodoHomePage(),
        _ => const TodoSettingsPage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: t('待办', 'Tasks')),
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
