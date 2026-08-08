import 'package:flutter/material.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'wear_data_store.dart';

/// 「今天穿什么」设置页
class WearSettingsPage extends StatelessWidget {
  const WearSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SubAppSettingsPanel(
      appId: 'wear',
      appName: '今天穿什么',
      reload: WearDataStore.load,
      onClearHistory: WearDataStore.clearHistory,
    );
  }
}
