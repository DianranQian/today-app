import 'package:flutter/material.dart';
import '../../core/language.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'wear_data_store.dart';

/// 「今天穿什么」设置页
class WearSettingsPage extends StatelessWidget {
  const WearSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置', 'Settings')),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: SubAppSettingsPanel(
        appId: 'wear',
        appName: t('今天穿什么', 'Outfits'),
        reload: WearDataStore.load,
        onClearHistory: WearDataStore.clearHistory,
      ),
    );
  }
}
