import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'wear_data_store.dart';
import 'wear_home_page.dart';
import 'wear_manage_page.dart';

/// 「今天穿什么」子应用：首页 + 管理 两个 Tab
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
    WearDataStore.load().then((_) {
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
      data: buildAppTheme(seed: AppSeeds.wear),
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          WearHomePage(),
          WearManagePage(),
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
              icon: Icon(Icons.checkroom_outlined),
              selectedIcon: Icon(Icons.checkroom),
              label: '管理'),
        ],
      ),
      ),
    );
  }
}
