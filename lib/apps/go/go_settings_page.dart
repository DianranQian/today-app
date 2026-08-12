import 'package:flutter/material.dart';
import '../../core/language.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'go_data_store.dart';

/// 「今天去哪」设置页
class GoSettingsPage extends StatelessWidget {
  const GoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置')),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: const SubAppSettingsPanel(
        appId: 'go',
        appName: '今天去哪',
        reload: GoDataStore.load,
        onClearHistory: GoDataStore.clearHistory,
      ),
    );
  }
}
